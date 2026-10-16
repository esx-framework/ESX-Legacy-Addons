/**
 * Draws the junction box scene onto a canvas.
 *
 * The stage is 1920 × 1080 scene units, scaled uniformly to fit the screen and centered; the
 * backdrop extends past the stage on wider or taller screens. Everything that does not move
 * (drywall, lighting, box, tray) is rendered once per resize into an offscreen layer, so a
 * frame is one blit plus the wires and whatever the player touches. Frames are only drawn
 * when something changed.
 *
 * @see WiringRenderer
 */

import { Random } from '../../../core/random';
import { vec, type Vec2 } from '../../../core/vec';
import {
  NUT_LENGTH,
  nutCenter,
  STRIP_LENGTH,
  type ConductorRuntime,
  type Held,
  type SpliceRuntime,
  type ToolKind,
  type WiringEngine,
} from '../engine';
import { BOX, CANOPY, JACKET_LIP, SCREW_POSITION, STAGE, type CableLayout } from '../layout';
import type { Move } from '../coach';
import { markerStyle } from '../markers';
import { NUT_COLORS, type Cable, type NutColor } from '../model';
import { SHADOW_PADDING, type ShadowedSprite, type WiringSprites } from './assets';
import {
  drawConductor,
  drawConductorShadow,
  drawSheath,
  drawSprite,
  drawTag,
  type ConductorStyle,
} from './painter';
import { compartment, TOOL_PLACEMENT, TRAY, type ToolPlacement } from './tray';

const NUT_SPRITE: Readonly<Record<NutColor, ShadowedSprite>> = {
  orange: 'nutOrange',
  yellow: 'nutYellow',
  red: 'nutRed',
};

const TOOL_SPRITE: Readonly<Record<ToolKind, ShadowedSprite>> = {
  tester: 'tester',
  stripper: 'stripper',
  tape: 'tapeRoll',
};

/** Angle tools are held at: tip toward the top left, handle toward the bottom right. */
const HOLD_ANGLE = 0.62;
const BRAND = '#fb9b04';
const HOVER_GLOW = 'rgba(251, 155, 4, 0.55)';
const ISSUE_GLOW = 'rgba(229, 72, 77, 0.7)';
const FOCUS_GLOW = 'rgba(255, 214, 120, 0.95)';

/** Short-lived spark particle. */
interface Spark {
  x: number;
  y: number;
  vx: number;
  vy: number;
  life: number;
  max: number;
}

/** Mapping between screen pixels and scene units. */
export interface StageTransform {
  /** Scene units to CSS pixels */
  scale: number;
  /** Stage left edge in CSS pixels */
  offsetX: number;
  /** Stage top edge in CSS pixels */
  offsetY: number;
}

/** What the guidance layer shows. */
export interface GuideOverlay {
  /** Bundle number per conductor, null to hide the markers */
  numbers: ReadonlyMap<string, number> | null;
  /** Hint to draw, null for none */
  move: Move | null;
}

/** Point at an arc length along a sampled conductor. */
function pointAlong(runtime: ConductorRuntime, at: number): Vec2 {
  const { points, distances } = runtime.line;
  for (let i = 1; i < distances.length; i++) {
    const d1 = distances[i] as number;
    if (d1 < at) continue;
    const d0 = distances[i - 1] as number;
    const t = d1 === d0 ? 0 : (at - d0) / (d1 - d0);
    const x0 = points[(i - 1) * 2] as number;
    const y0 = points[(i - 1) * 2 + 1] as number;
    return vec(
      x0 + ((points[i * 2] as number) - x0) * t,
      y0 + ((points[i * 2 + 1] as number) - y0) * t,
    );
  }
  return runtime.end;
}

/** Canvas renderer of the junction box scene. */
export class WiringRenderer {
  private readonly ctx: CanvasRenderingContext2D;
  private readonly layer = document.createElement('canvas');
  /** Tape flags, transparent, drawn over the wires so labels stay readable. */
  private readonly flags = document.createElement('canvas');
  private dpr = 1;
  private transform: StageTransform = { scale: 1, offsetX: 0, offsetY: 0 };
  private sparks: Spark[] = [];
  private focus: ReadonlySet<string> = new Set();
  private guide: GuideOverlay = { numbers: null, move: null };
  private readonly sparkRandom = new Random(0x5eed);
  private readonly cableById: ReadonlyMap<string, Cable>;
  private readonly nmCables: readonly CableLayout[];

  constructor(
    private readonly canvas: HTMLCanvasElement,
    private readonly sprites: WiringSprites,
    private readonly engine: WiringEngine,
  ) {
    const ctx = canvas.getContext('2d', { alpha: false });
    if (!ctx) throw new Error('2D canvas unavailable');
    this.ctx = ctx;
    this.cableById = new Map(engine.puzzle.cables.map((c: Cable): [string, Cable] => [c.id, c]));
    this.nmCables = engine.layout.cables.filter((c: CableLayout): boolean => c.entry !== null);
  }

  /**
   * Sets the numbered markers and the hint arrow.
   *
   * @param guide - What to show; pass empty values to hide everything
   */
  setGuide(guide: GuideOverlay): void {
    this.guide = guide;
  }

  /**
   * Highlights conductors, e.g. while the player hovers a bundle in the wiring plan.
   *
   * @param ids - Conductors to highlight, null to clear
   */
  setFocus(ids: readonly string[] | null): void {
    this.focus = new Set(ids ?? []);
  }

  /** Current stage transform, used to map pointer events and to place the HUD. */
  get stage(): StageTransform {
    return this.transform;
  }

  /** Whether sparks are still flying, i.e. the caller should keep requesting frames. */
  get animating(): boolean {
    return this.sparks.length > 0;
  }

  /**
   * Adapts canvas resolution to the element size and rebuilds the static layer.
   *
   * @param width - CSS width of the canvas
   * @param height - CSS height of the canvas
   * @param dpr - Device pixel ratio
   */
  resize(width: number, height: number, dpr: number): void {
    this.dpr = dpr;
    this.canvas.width = Math.round(width * dpr);
    this.canvas.height = Math.round(height * dpr);
    const scale = Math.min(width / STAGE.width, height / STAGE.height);
    this.transform = {
      scale,
      offsetX: (width - STAGE.width * scale) / 2,
      offsetY: (height - STAGE.height * scale) / 2,
    };
    this.layer.width = this.canvas.width;
    this.layer.height = this.canvas.height;
    this.flags.width = this.canvas.width;
    this.flags.height = this.canvas.height;
    this.paintStatic();
  }

  /**
   * Converts a pointer position to scene units.
   *
   * @param clientX - Pointer x relative to the canvas, CSS pixels
   * @param clientY - Pointer y relative to the canvas, CSS pixels
   * @returns Stage position
   */
  toStage(clientX: number, clientY: number): Vec2 {
    const { scale, offsetX, offsetY } = this.transform;
    return vec((clientX - offsetX) / scale, (clientY - offsetY) / scale);
  }

  /**
   * Starts a burst of sparks.
   *
   * @param at - Stage position
   * @param count - Number of particles
   */
  spark(at: Vec2, count = 26): void {
    const random = this.sparkRandom;
    for (let i = 0; i < count; i++) {
      const angle = random.float(0, Math.PI * 2);
      const speed = random.float(4, 15);
      const max = random.float(14, 30);
      this.sparks.push({
        x: at.x,
        y: at.y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed - 3,
        life: max,
        max,
      });
    }
  }

  /** Draws one frame. */
  render(): void {
    const { ctx } = this;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.drawImage(this.layer, 0, 0);

    const { scale, offsetX, offsetY } = this.transform;
    const s = scale * this.dpr;
    ctx.setTransform(s, 0, 0, s, offsetX * this.dpr, offsetY * this.dpr);

    this.paintConductors();
    this.paintJacketLips();
    ctx.save();
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.drawImage(this.flags, 0, 0);
    ctx.restore();
    this.paintTools();
    this.paintGuide();
    this.paintLampLight();
    this.paintHeld();
    this.paintSparks();
  }

  private paintStatic(): void {
    const ctx = this.layer.getContext('2d');
    if (!ctx) return;
    const { images } = this.sprites;
    const { width, height } = this.layer;

    // Drywall covers the whole screen, cropped like background-size: cover.
    const wall = images.drywall;
    const cover = Math.max(width / wall.naturalWidth, height / wall.naturalHeight);
    const wallWidth = wall.naturalWidth * cover;
    const wallHeight = wall.naturalHeight * cover;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.drawImage(wall, (width - wallWidth) / 2, (height - wallHeight) / 2, wallWidth, wallHeight);

    const { scale, offsetX, offsetY } = this.transform;
    const s = scale * this.dpr;
    ctx.setTransform(s, 0, 0, s, offsetX * this.dpr, offsetY * this.dpr);

    // Work light: a warm pool on the box, falling off into a darker room.
    const cx = BOX.x + BOX.size / 2;
    const cy = BOX.y + BOX.size / 2;
    const light = ctx.createRadialGradient(cx - 120, cy - 160, 120, cx, cy, 1250);
    light.addColorStop(0, 'rgba(255, 236, 205, 0.05)');
    light.addColorStop(0.45, 'rgba(18, 16, 14, 0.18)');
    light.addColorStop(1, 'rgba(8, 8, 8, 0.72)');
    ctx.fillStyle = light;
    ctx.fillRect(-STAGE.width, -STAGE.height, STAGE.width * 3, STAGE.height * 3);

    // The box sits in a drywall cutout: a soft dark gap where the cut edge meets the steel.
    ctx.save();
    ctx.filter = `blur(${Math.max(2, Math.round(6 * s))}px)`;
    ctx.strokeStyle = 'rgba(24, 19, 14, 0.75)';
    ctx.lineWidth = 14;
    ctx.strokeRect(BOX.x + 10, BOX.y + 10, BOX.size - 20, BOX.size - 26);
    ctx.restore();
    ctx.drawImage(images.box, BOX.x, BOX.y, BOX.size, BOX.size);
    drawSprite(ctx, images.groundScrew, SCREW_POSITION.x, SCREW_POSITION.y, 44);

    this.paintCables(ctx);
    this.paintCanopy(ctx);

    this.paintShadowed(
      ctx,
      'tray',
      TRAY.x + TRAY.width / 2,
      TRAY.y + TRAY.height / 2,
      TRAY.width,
      0,
      8,
      14,
      0.6,
    );
    ctx.drawImage(images.tray, TRAY.x, TRAY.y, TRAY.width, TRAY.height);
    this.paintNutPiles(ctx);
  }

  private paintCanopy(ctx: CanvasRenderingContext2D): void {
    const leads = this.engine.layout.cables.find(
      (cable: CableLayout): boolean => this.cableById.get(cable.cableId)?.role === 'fixture',
    );
    if (!leads) return;
    const image = this.sprites.images.canopy;
    const height = (CANOPY.width * image.naturalHeight) / image.naturalWidth;
    const x = leads.sheathEnd.x - (CANOPY.hole.x - 0.5) * CANOPY.width;
    const y = leads.sheathEnd.y - (CANOPY.hole.y - 0.5) * height;
    // Hangs closer to the camera than the box, so its shadow lands farther away.
    this.paintShadowed(ctx, 'canopy', x, y, CANOPY.width, 0, 16, 26, 0.5);
    drawSprite(ctx, image, x, y, CANOPY.width);
  }

  private paintNutPiles(ctx: CanvasRenderingContext2D): void {
    const random = new Random(0x7a11);
    for (const color of NUT_COLORS) {
      const area = compartment(color);
      const length = NUT_LENGTH[color] * 0.5;
      for (let i = 0; i < 3; i++) {
        const x = area.x + area.width * (0.5 + random.float(-0.1, 0.1));
        const y = area.y + area.height * (0.24 + i * 0.26);
        const angle = random.float(-0.35, 0.35) + (i % 2 === 0 ? 0 : Math.PI);
        this.paintShadowed(ctx, NUT_SPRITE[color], x, y, length, angle, 3, 5, 0.5);
        drawSprite(ctx, this.sprites.images[NUT_SPRITE[color]], x, y, length, angle);
      }
    }
  }

  private paintShadowed(
    ctx: CanvasRenderingContext2D,
    name: ShadowedSprite,
    x: number,
    y: number,
    width: number,
    angle: number,
    dx: number,
    dy: number,
    alpha: number,
  ): void {
    const shadow = this.sprites.shadows[name];
    const drawWidth = width * (1 + SHADOW_PADDING * 2);
    ctx.globalAlpha = alpha;
    ctx.save();
    ctx.translate(x + dx, y + dy);
    if (angle !== 0) ctx.rotate(angle);
    const drawHeight = (drawWidth * shadow.height) / shadow.width;
    ctx.drawImage(shadow, -drawWidth / 2, -drawHeight / 2, drawWidth, drawHeight);
    ctx.restore();
    ctx.globalAlpha = 1;
  }

  /** Jackets and tape flags never move, so they are painted once per resize. */
  private paintCables(ctx: CanvasRenderingContext2D): void {
    for (const cable of this.nmCables) {
      const model = this.cableById.get(cable.cableId);
      if (!model || model.sheath === 'none' || !cable.entry) continue;
      drawSheath(ctx, cable.entry, cable.sheathEnd, cable.width, model.sheath);
    }
    const flags = this.flags.getContext('2d');
    if (!flags) return;
    flags.setTransform(1, 0, 0, 1, 0, 0);
    flags.clearRect(0, 0, this.flags.width, this.flags.height);
    flags.setTransform(ctx.getTransform());
    for (const cable of this.nmCables) {
      const model = this.cableById.get(cable.cableId);
      if (!model?.tag || !cable.entry) continue;
      const x = cable.entry.x + (cable.sheathEnd.x - cable.entry.x) * 0.45;
      const y = cable.entry.y + (cable.sheathEnd.y - cable.entry.y) * 0.45;
      // Flags always read left to right: wrapped across a vertical cable, sticking out above
      // a horizontal one.
      const horizontal = Math.abs(cable.inward.x) > 0.5;
      drawTag(
        flags,
        this.sprites.images.maskingTape,
        model.tag,
        horizontal ? x + cable.inward.x * 8 : x,
        horizontal ? y - cable.width / 2 - 8 : y,
        cable.tagTilt,
      );
    }
  }

  private styleOf(runtime: ConductorRuntime): ConductorStyle {
    const { conductor, layout } = runtime;
    const id = conductor.id;
    const exposed = this.engine.isExposed(id);
    const taped = conductor.marked || this.engine.taped.has(id);
    const tapeEnd = runtime.total - STRIP_LENGTH - 22;
    const aim = this.engine.aim;
    let glow: string | null = null;
    if (this.engine.highlighted.has(id)) glow = ISSUE_GLOW;
    else if (aim?.conductors.includes(id)) glow = aim.valid ? HOVER_GLOW : ISSUE_GLOW;
    else if (this.focus.has(id) || this.guideTarget() === id) glow = FOCUS_GLOW;

    return {
      insulation: conductor.insulation,
      width: layout.width,
      copperWidth: layout.copperWidth,
      stripAt: exposed ? runtime.total - STRIP_LENGTH : runtime.total,
      stranded: conductor.stranded,
      tape: taped && conductor.insulation === 'white' ? [Math.max(0, tapeEnd - 70), tapeEnd] : null,
      glow,
    };
  }

  private paintConductors(): void {
    const { ctx, engine } = this;
    const dragged = engine.dragged;
    const lifted = (runtime: ConductorRuntime): boolean =>
      runtime.conductor.id === dragged ||
      (runtime.spliceId !== null && runtime.spliceId === dragged);

    const resting = engine.conductors.filter((r: ConductorRuntime): boolean => !lifted(r));
    const carried = engine.conductors.filter(lifted);

    for (const runtime of resting)
      drawConductorShadow(ctx, runtime.line, runtime.total, runtime.layout.width);
    for (const runtime of resting)
      if (runtime.spliceId === null)
        drawConductor(ctx, runtime.line, runtime.total, this.styleOf(runtime));
    for (const runtime of resting)
      if (runtime.spliceId !== null)
        drawConductor(ctx, runtime.line, runtime.total, this.styleOf(runtime));
    for (const splice of engine.splices.values())
      if (splice.id !== dragged) this.paintNut(splice, false);

    if (carried.length === 0) return;
    // Lifted wires cast a longer, softer shadow.
    ctx.save();
    ctx.translate(4, 8);
    ctx.globalAlpha = 0.7;
    for (const runtime of carried)
      drawConductorShadow(ctx, runtime.line, runtime.total, runtime.layout.width + 2);
    ctx.restore();
    for (const runtime of carried)
      drawConductor(ctx, runtime.line, runtime.total, this.styleOf(runtime));
    const splice = dragged ? engine.splices.get(dragged) : undefined;
    if (splice) this.paintNut(splice, true);
  }

  /**
   * Conductors start a little inside their jacket. Copying the jacket's cut end back from the
   * static layer puts it on top of them, so they come out from under the edge.
   */
  private paintJacketLips(): void {
    const { ctx, dpr } = this;
    const { scale, offsetX, offsetY } = this.transform;
    ctx.save();
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    for (const cable of this.nmCables) {
      // Deep enough to cover the round start caps and their shadows.
      const depth = JACKET_LIP + 20;
      const inner = {
        x: cable.sheathEnd.x - cable.inward.x * depth,
        y: cable.sheathEnd.y - cable.inward.y * depth,
      };
      const half = cable.width / 2;
      const across = { x: -cable.inward.y * half, y: cable.inward.x * half };
      const xs = [
        cable.sheathEnd.x + across.x,
        cable.sheathEnd.x - across.x,
        inner.x + across.x,
        inner.x - across.x,
      ];
      const ys = [
        cable.sheathEnd.y + across.y,
        cable.sheathEnd.y - across.y,
        inner.y + across.y,
        inner.y - across.y,
      ];
      const left = Math.floor((offsetX + Math.min(...xs) * scale) * dpr);
      const top = Math.floor((offsetY + Math.min(...ys) * scale) * dpr);
      const right = Math.ceil((offsetX + Math.max(...xs) * scale) * dpr);
      const bottom = Math.ceil((offsetY + Math.max(...ys) * scale) * dpr);
      const width = right - left;
      const height = bottom - top;
      if (width > 0 && height > 0)
        ctx.drawImage(this.layer, left, top, width, height, left, top, width, height);
    }
    ctx.restore();
  }

  /** Conductor the current hint is about, if any. */
  private guideTarget(): string | null {
    const move = this.guide.move;
    if (!move) return null;
    switch (move.kind) {
      case 'strip':
      case 'tape':
      case 'separate':
      case 'place':
      case 'join':
        return move.conductorId;
      default:
        return null;
    }
  }

  private paintGuide(): void {
    const { numbers, move } = this.guide;
    if (numbers) this.paintMarkers(numbers);
    if (!move) return;

    const { engine } = this;
    switch (move.kind) {
      case 'test': {
        const cable = engine.layout.cables.find(
          (c: CableLayout): boolean => c.cableId === move.cableId,
        );
        if (cable?.entry) {
          this.paintArrow(
            TOOL_PLACEMENT.tester,
            vec((cable.entry.x + cable.sheathEnd.x) / 2, (cable.entry.y + cable.sheathEnd.y) / 2),
          );
        }
        break;
      }
      case 'strip':
        this.paintArrow(TOOL_PLACEMENT.stripper, engine.conductor(move.conductorId).end);
        break;
      case 'tape':
        this.paintArrow(TOOL_PLACEMENT.tape, engine.conductor(move.conductorId).end);
        break;
      case 'separate':
      case 'place':
      case 'join':
        this.paintArrow(engine.conductor(move.conductorId).end, move.to);
        break;
      case 'nut': {
        const splice = engine.splices.get(move.spliceId);
        const area = compartment(move.color);
        if (splice) {
          this.paintArrow(vec(area.x + area.width / 2, area.y + area.height / 2), splice.point);
        }
        break;
      }
      case 'twist': {
        const splice = engine.splices.get(move.spliceId);
        if (splice) this.paintTwistHint(nutCenter(splice));
        break;
      }
      case 'unnut': {
        const splice = engine.splices.get(move.spliceId);
        if (splice) this.paintRing(nutCenter(splice), 48);
        break;
      }
      default:
        break;
    }
  }

  /** Numbered discs on every conductor that is not capped yet. */
  private paintMarkers(numbers: ReadonlyMap<string, number>): void {
    const { ctx, engine } = this;
    ctx.save();
    ctx.font = '700 15px Poppins, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    for (const runtime of engine.conductors) {
      const number = numbers.get(runtime.conductor.id);
      if (number === undefined) continue;
      const splice = runtime.spliceId ? engine.splices.get(runtime.spliceId) : undefined;
      if (splice && splice.nut !== null && splice.twist >= 1) continue;

      // Sit on the insulation just behind the bare copper, where the hand grabs the wire.
      const back = runtime.conductor.insulation === 'bare' ? 30 : STRIP_LENGTH + 26;
      const point = pointAlong(runtime, Math.max(0, runtime.total - back));
      const style = markerStyle(number);
      ctx.fillStyle = 'rgba(0, 0, 0, 0.45)';
      ctx.beginPath();
      ctx.arc(point.x + 2, point.y + 3, 13, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = style.fill;
      ctx.strokeStyle = 'rgba(22, 22, 22, 0.9)';
      ctx.lineWidth = 2.5;
      ctx.beginPath();
      ctx.arc(point.x, point.y, 13, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
      ctx.fillStyle = style.text;
      ctx.fillText(String(number), point.x, point.y + 1);
    }
    ctx.restore();
  }

  private paintRing(at: { x: number; y: number }, radius: number): void {
    const { ctx } = this;
    ctx.save();
    ctx.lineWidth = 9;
    ctx.strokeStyle = 'rgba(0, 0, 0, 0.5)';
    ctx.beginPath();
    ctx.arc(at.x, at.y, radius, 0, Math.PI * 2);
    ctx.stroke();
    ctx.lineWidth = 4;
    ctx.setLineDash([10, 8]);
    ctx.strokeStyle = BRAND;
    ctx.beginPath();
    ctx.arc(at.x, at.y, radius, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }

  /** Dashed, slightly curved arrow from where to grab to where to drop. */
  private paintArrow(from: { x: number; y: number }, to: { x: number; y: number }): void {
    const { ctx } = this;
    const dx = to.x - from.x;
    const dy = to.y - from.y;
    const length = Math.hypot(dx, dy);
    if (length < 8) {
      this.paintRing(to, 30);
      return;
    }
    const bend = Math.min(80, length * 0.18);
    const cx = (from.x + to.x) / 2 - (dy / length) * bend;
    const cy = (from.y + to.y) / 2 + (dx / length) * bend;
    // Stop short of the target so the head does not cover it.
    const t = Math.max(0, 1 - 30 / length);
    const ex = (1 - t) * (1 - t) * from.x + 2 * (1 - t) * t * cx + t * t * to.x;
    const ey = (1 - t) * (1 - t) * from.y + 2 * (1 - t) * t * cy + t * t * to.y;
    const angle = Math.atan2(ey - (cy + (ey - cy) * 0.5), ex - (cx + (ex - cx) * 0.5));

    ctx.save();
    ctx.lineCap = 'round';
    ctx.lineWidth = 10;
    ctx.strokeStyle = 'rgba(0, 0, 0, 0.5)';
    ctx.beginPath();
    ctx.moveTo(from.x, from.y);
    ctx.quadraticCurveTo(cx, cy, ex, ey);
    ctx.stroke();
    ctx.lineWidth = 5;
    ctx.setLineDash([14, 10]);
    ctx.strokeStyle = BRAND;
    ctx.beginPath();
    ctx.moveTo(from.x, from.y);
    ctx.quadraticCurveTo(cx, cy, ex, ey);
    ctx.stroke();
    ctx.setLineDash([]);

    ctx.translate(ex, ey);
    ctx.rotate(angle);
    ctx.fillStyle = BRAND;
    ctx.strokeStyle = 'rgba(22, 22, 22, 0.85)';
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.moveTo(14, 0);
    ctx.lineTo(-10, -11);
    ctx.lineTo(-6, 0);
    ctx.lineTo(-10, 11);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();

    this.paintRing(to, 26);
  }

  /** Clockwise arc around a wire nut that shows which way to turn it. */
  private paintTwistHint(at: { x: number; y: number }): void {
    const { ctx } = this;
    const radius = 76;
    const start = -Math.PI / 2;
    const end = start + Math.PI * 1.6;
    ctx.save();
    ctx.lineCap = 'round';
    for (const [width, color] of [
      [10, 'rgba(0, 0, 0, 0.5)'],
      [5, BRAND],
    ] as const) {
      ctx.lineWidth = width;
      ctx.strokeStyle = color;
      ctx.beginPath();
      ctx.arc(at.x, at.y, radius, start, end);
      ctx.stroke();
    }
    ctx.translate(at.x + Math.cos(end) * radius, at.y + Math.sin(end) * radius);
    ctx.rotate(end + Math.PI / 2);
    ctx.fillStyle = BRAND;
    ctx.strokeStyle = 'rgba(22, 22, 22, 0.85)';
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.moveTo(14, 0);
    ctx.lineTo(-10, -11);
    ctx.lineTo(-6, 0);
    ctx.lineTo(-10, 11);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
  }

  private paintNut(splice: SpliceRuntime, lifted: boolean): void {
    if (splice.nut === null) return;
    const { ctx } = this;
    const length = NUT_LENGTH[splice.nut];
    const angle = Math.atan2(splice.direction.y, splice.direction.x);
    const { x, y } = nutCenter(splice);
    const sprite = NUT_SPRITE[splice.nut];
    this.paintShadowed(ctx, sprite, x, y, length, angle, lifted ? 8 : 4, lifted ? 14 : 7, 0.55);
    drawSprite(ctx, this.sprites.images[sprite], x, y, length, angle);

    if (splice.twist < 1) {
      // Twist gauge: how far the connector still has to be turned on.
      ctx.strokeStyle = 'rgba(22, 22, 22, 0.55)';
      ctx.lineWidth = 7;
      ctx.beginPath();
      ctx.arc(x, y, length * 0.62, 0, Math.PI * 2);
      ctx.stroke();
      ctx.strokeStyle = BRAND;
      ctx.lineWidth = 4;
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.arc(
        x,
        y,
        length * 0.62,
        -Math.PI / 2,
        -Math.PI / 2 + Math.PI * 2 * Math.max(0.02, splice.twist),
      );
      ctx.stroke();
    }
  }

  private paintTools(): void {
    const held = this.engine.held;
    for (const tool of Object.keys(TOOL_PLACEMENT) as ToolKind[]) {
      if (held?.kind === 'tool' && held.tool === tool) continue;
      const placement: ToolPlacement = TOOL_PLACEMENT[tool];
      this.paintShadowed(
        this.ctx,
        TOOL_SPRITE[tool],
        placement.x,
        placement.y,
        placement.width,
        placement.angle,
        5,
        9,
        0.55,
      );
      drawSprite(
        this.ctx,
        this.sprites.images[TOOL_SPRITE[tool]],
        placement.x,
        placement.y,
        placement.width,
        placement.angle,
      );
    }
  }

  private paintHeld(): void {
    const held: Held | null = this.engine.held;
    if (!held) return;
    const { ctx } = this;
    const p = this.engine.pointer;

    if (held.kind === 'nut') {
      const length = NUT_LENGTH[held.color];
      this.paintShadowed(ctx, NUT_SPRITE[held.color], p.x, p.y, length, -0.5, 10, 18, 0.5);
      drawSprite(ctx, this.sprites.images[NUT_SPRITE[held.color]], p.x, p.y, length, -0.5);
      return;
    }

    const placement = TOOL_PLACEMENT[held.tool];
    const sprite = TOOL_SPRITE[held.tool];
    if (held.tool === 'tape') {
      this.paintShadowed(ctx, sprite, p.x, p.y, placement.width, 0, 10, 18, 0.5);
      drawSprite(ctx, this.sprites.images[sprite], p.x, p.y, placement.width);
      return;
    }

    // Tester and stripper are held by the handle with the working end at the pointer.
    const half = placement.width / 2 - 6;
    const x = p.x + Math.cos(HOLD_ANGLE) * half;
    const y = p.y + Math.sin(HOLD_ANGLE) * half;
    this.paintShadowed(ctx, sprite, x, y, placement.width, HOLD_ANGLE, 12, 22, 0.45);
    drawSprite(ctx, this.sprites.images[sprite], x, y, placement.width, HOLD_ANGLE);

    if (held.tool === 'tester' && this.engine.testerLevel > 0) {
      const level = this.engine.testerLevel;
      const glow = ctx.createRadialGradient(p.x, p.y, 2, p.x, p.y, 34 + level * 30);
      glow.addColorStop(0, `rgba(255, 70, 50, ${0.55 + level * 0.4})`);
      glow.addColorStop(1, 'rgba(255, 40, 30, 0)');
      ctx.fillStyle = glow;
      ctx.beginPath();
      ctx.arc(p.x, p.y, 64, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  private paintLampLight(): void {
    if (this.engine.live.loads.get('fixture') !== 'on') return;
    const { ctx } = this;
    const cx = BOX.x + BOX.size / 2;
    const glow = ctx.createRadialGradient(cx, STAGE.height + 80, 60, cx, STAGE.height, 1100);
    glow.addColorStop(0, 'rgba(255, 214, 150, 0.42)');
    glow.addColorStop(0.5, 'rgba(255, 196, 120, 0.12)');
    glow.addColorStop(1, 'rgba(255, 190, 110, 0)');
    ctx.fillStyle = glow;
    ctx.fillRect(-STAGE.width, -STAGE.height, STAGE.width * 3, STAGE.height * 3);
  }

  private paintSparks(): void {
    if (this.sparks.length === 0) return;
    const { ctx } = this;
    ctx.lineCap = 'round';
    for (const spark of this.sparks) {
      const t = spark.life / spark.max;
      ctx.strokeStyle = `rgba(255, ${Math.round(170 + 85 * t)}, ${Math.round(90 * t)}, ${t})`;
      ctx.lineWidth = 1.5 + 2.5 * t;
      ctx.beginPath();
      ctx.moveTo(spark.x, spark.y);
      ctx.lineTo(spark.x - spark.vx * 1.6, spark.y - spark.vy * 1.6);
      ctx.stroke();
      spark.x += spark.vx;
      spark.y += spark.vy;
      spark.vx *= 0.92;
      spark.vy = spark.vy * 0.92 + 0.9;
      spark.life -= 1;
    }
    this.sparks = this.sparks.filter((spark: Spark): boolean => spark.life > 0);
  }
}
