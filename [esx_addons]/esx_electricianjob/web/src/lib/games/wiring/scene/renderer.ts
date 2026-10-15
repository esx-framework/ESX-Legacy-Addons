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
import { BOX, CANOPY, SCREW_POSITION, STAGE, type CableLayout } from '../layout';
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

/** Canvas renderer of the junction box scene. */
export class WiringRenderer {
  private readonly ctx: CanvasRenderingContext2D;
  private readonly layer = document.createElement('canvas');
  private dpr = 1;
  private transform: StageTransform = { scale: 1, offsetX: 0, offsetY: 0 };
  private sparks: Spark[] = [];
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
    this.paintTools();
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

  /** Jackets and tape flags never move, so they live in the static layer. */
  private paintCables(ctx: CanvasRenderingContext2D): void {
    for (const cable of this.nmCables) {
      const model = this.cableById.get(cable.cableId);
      if (!model || model.sheath === 'none' || !cable.entry) continue;
      drawSheath(ctx, cable.entry, cable.sheathEnd, cable.width, model.sheath);
    }
    for (const cable of this.nmCables) {
      const model = this.cableById.get(cable.cableId);
      if (!model?.tag || !cable.entry) continue;
      const x = cable.entry.x + (cable.sheathEnd.x - cable.entry.x) * 0.45;
      const y = cable.entry.y + (cable.sheathEnd.y - cable.entry.y) * 0.45;
      const along = Math.atan2(cable.inward.y, cable.inward.x);
      // Flags read left to right; vertical cables get the flag across them.
      const angle = (Math.abs(cable.inward.x) > 0.5 ? along + Math.PI / 2 : 0) + cable.tagTilt;
      drawTag(ctx, this.sprites.images.maskingTape, model.tag, x, y, angle);
    }
  }

  private styleOf(runtime: ConductorRuntime): ConductorStyle {
    const { conductor, layout } = runtime;
    const id = conductor.id;
    const exposed = this.engine.isExposed(id);
    const taped = conductor.marked || this.engine.taped.has(id);
    const tapeEnd = runtime.total - STRIP_LENGTH - 22;
    let glow: string | null = null;
    if (this.engine.highlighted.has(id)) glow = ISSUE_GLOW;
    else if (
      this.engine.hover === id ||
      (runtime.spliceId !== null && this.engine.hover === runtime.spliceId)
    )
      glow = HOVER_GLOW;

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
