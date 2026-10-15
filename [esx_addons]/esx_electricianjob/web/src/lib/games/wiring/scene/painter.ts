/**
 * Canvas drawing for the junction box: conductors, jackets, sprites and tape flags.
 *
 * A conductor is a stack of strokes along its sampled polyline, from a wide dark core to a
 * thin specular streak, each one shifted a little further toward the lit side (see
 * wire-path.ts). Six steps read as a smooth round cylinder lit from the top left, matching
 * the photographed sprites. Per-frame code avoids canvas filters and shadowBlur, which are
 * slow in CEF's jitless mode; jackets and tags never move and are painted once into the
 * static layer, where softer effects are affordable.
 *
 * @see drawConductor
 */

import type { Insulation, Sheath } from '../model';
import { traceRange, type WirePolyline } from './wire-path';

/** Three tones of a material: shadowed rim, body, highlight. */
export interface Tones {
  /** Rim and core-shadow tone */
  dark: string;
  /** Main body tone */
  base: string;
  /** Specular highlight tone */
  light: string;
}

/** PVC insulation colors. */
export const INSULATION_TONES: Readonly<Record<Exclude<Insulation, 'bare'>, Tones>> = {
  black: { dark: '#050506', base: '#1c1d20', light: '#9a9ea8' },
  white: { dark: '#8f897b', base: '#e4e0d4', light: '#ffffff' },
  red: { dark: '#4f0b09', base: '#ad201b', light: '#ff9d90' },
  green: { dark: '#0f3416', base: '#2a7535', light: '#a4e2ae' },
};

/** Bright annealed copper. */
export const COPPER_TONES: Tones = { dark: '#3f1b09', base: '#ad6136', light: '#ffe3c6' };

/** Black vinyl tape used to re-mark a white conductor. */
const TAPE_TONES: Tones = { dark: '#000000', base: '#141416', light: '#6d7079' };

/** NM-B jacket colors. */
export const SHEATH_TONES: Readonly<Record<Exclude<Sheath, 'none'>, Tones>> = {
  white: { dark: '#9e9783', base: '#e8e3d3', light: '#fffdf5' },
  yellow: { dark: '#8a6c0a', base: '#ddb52a', light: '#fff1b0' },
  orange: { dark: '#86390a', base: '#dc701f', light: '#ffc79a' },
};

/** Light comes from the top left, so shadows fall to the bottom right. */
const SHADOW_NEAR = { x: 3, y: 6, alpha: 0.34 } as const;
const SHADOW_FAR = { x: 7, y: 13, alpha: 0.14 } as const;

/** Shading steps: width fraction, ramp color, shift toward the light (× width), opacity. */
const SHADING: readonly (readonly [number, number, number, number])[] = [
  [1, 0, 0, 1],
  [0.84, 1, 0.05, 1],
  [0.66, 2, 0.1, 1],
  [0.44, 3, 0.17, 1],
  [0.24, 4, 0.24, 0.9],
  [0.09, 5, 0.29, 0.85],
];

/** Visual options of one conductor. */
export interface ConductorStyle {
  /** Insulation color, or bare copper */
  insulation: Insulation;
  /** Outer width */
  width: number;
  /** Copper width */
  copperWidth: number;
  /** Arc length where the insulation stops; equal to the total length when not stripped */
  stripAt: number;
  /** Stranded copper instead of a solid wire */
  stranded: boolean;
  /** Black tape band, as arc lengths, or null */
  tape: readonly [number, number] | null;
  /** Hover or selection glow color, or null */
  glow: string | null;
}

function parseHex(hex: string): [number, number, number] {
  const value = Number.parseInt(hex.slice(1), 16);
  return [(value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff];
}

function mix(a: string, b: string, t: number): string {
  const [ar, ag, ab] = parseHex(a);
  const [br, bg, bb] = parseHex(b);
  const r = Math.round(ar + (br - ar) * t);
  const g = Math.round(ag + (bg - ag) * t);
  const bl = Math.round(ab + (bb - ab) * t);
  return `#${((1 << 24) | (r << 16) | (g << 8) | bl).toString(16).slice(1)}`;
}

const ramps = new WeakMap<Tones, readonly string[]>();

/** Six colors from core shadow to specular, cached per material. */
function rampOf(tones: Tones): readonly string[] {
  let ramp = ramps.get(tones);
  if (!ramp) {
    ramp = [
      tones.dark,
      mix(tones.dark, tones.base, 0.55),
      tones.base,
      mix(tones.base, tones.light, 0.3),
      mix(tones.base, tones.light, 0.7),
      tones.light,
    ];
    ramps.set(tones, ramp);
  }
  return ramp;
}

function strokeCylinder(
  ctx: CanvasRenderingContext2D,
  line: WirePolyline,
  from: number,
  to: number,
  width: number,
  tones: Tones,
): void {
  const ramp = rampOf(tones);
  for (const [fraction, color, shift, alpha] of SHADING) {
    ctx.globalAlpha = alpha;
    ctx.strokeStyle = ramp[color] as string;
    ctx.lineWidth = Math.max(1, width * fraction);
    traceRange(ctx, line, from, to, width * shift);
    ctx.stroke();
  }
  ctx.globalAlpha = 1;
}

/**
 * Draws the drop shadow of a wire. Called for all wires before any body so that shadows
 * never fall on top of other conductors' bodies drawn earlier.
 *
 * @param ctx - Scene context
 * @param line - Sampled wire
 * @param total - Arc length of the wire
 * @param width - Outer width
 */
export function drawConductorShadow(
  ctx: CanvasRenderingContext2D,
  line: WirePolyline,
  total: number,
  width: number,
): void {
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  ctx.strokeStyle = `rgba(0, 0, 0, ${SHADOW_FAR.alpha})`;
  ctx.lineWidth = width + 8;
  traceRange(ctx, line, 0, total, 0, SHADOW_FAR.x, SHADOW_FAR.y);
  ctx.stroke();

  ctx.strokeStyle = `rgba(0, 0, 0, ${SHADOW_NEAR.alpha})`;
  ctx.lineWidth = width + 1;
  traceRange(ctx, line, 0, total, 0, SHADOW_NEAR.x, SHADOW_NEAR.y);
  ctx.stroke();
}

function drawStrands(
  ctx: CanvasRenderingContext2D,
  line: WirePolyline,
  from: number,
  to: number,
  width: number,
): void {
  ctx.save();
  ctx.setLineDash([2, 3]);
  ctx.strokeStyle = 'rgba(70, 30, 8, 0.55)';
  ctx.lineWidth = width * 0.9;
  traceRange(ctx, line, from, to);
  ctx.stroke();
  ctx.restore();
}

function drawCutFace(
  ctx: CanvasRenderingContext2D,
  line: WirePolyline,
  style: ConductorStyle,
): void {
  const last = line.points.length - 2;
  const x = line.points[last] as number;
  const y = line.points[last + 1] as number;
  ctx.fillStyle = COPPER_TONES.dark;
  ctx.beginPath();
  ctx.arc(x, y, style.copperWidth * 0.55, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = COPPER_TONES.base;
  ctx.beginPath();
  ctx.arc(x - 0.6, y - 0.6, style.copperWidth * 0.36, 0, Math.PI * 2);
  ctx.fill();
}

/**
 * Draws one conductor: glow, bare copper end, insulation, tape band.
 *
 * @param ctx - Scene context
 * @param line - Sampled wire
 * @param total - Arc length of the wire
 * @param style - Colors and widths
 */
export function drawConductor(
  ctx: CanvasRenderingContext2D,
  line: WirePolyline,
  total: number,
  style: ConductorStyle,
): void {
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';

  if (style.glow) {
    ctx.globalAlpha = 0.55;
    ctx.strokeStyle = style.glow;
    ctx.lineWidth = style.width + 10;
    traceRange(ctx, line, 0, total);
    ctx.stroke();
    ctx.globalAlpha = 1;
  }

  if (style.insulation === 'bare') {
    strokeCylinder(ctx, line, 0, total, style.width, COPPER_TONES);
    return;
  }

  const stripped = style.stripAt < total - 0.5;
  if (stripped) {
    // Copper first so the round cap of the insulation sits on top like a real cut edge.
    strokeCylinder(
      ctx,
      line,
      Math.max(0, style.stripAt - 4),
      total,
      style.copperWidth,
      COPPER_TONES,
    );
    if (style.stranded) drawStrands(ctx, line, style.stripAt, total, style.copperWidth);
  }

  strokeCylinder(
    ctx,
    line,
    0,
    Math.min(total, style.stripAt),
    style.width,
    INSULATION_TONES[style.insulation],
  );

  if (style.tape) {
    strokeCylinder(ctx, line, style.tape[0], style.tape[1], style.width * 1.14, TAPE_TONES);
  }
  if (!stripped) drawCutFace(ctx, line, style);
}

let noise: HTMLCanvasElement | null = null;

/** Fine grain texture for plastic surfaces, generated once. */
function noiseTile(): HTMLCanvasElement {
  if (noise) return noise;
  const size = 96;
  const tile = document.createElement('canvas');
  tile.width = size;
  tile.height = size;
  const ctx = tile.getContext('2d');
  if (ctx) {
    const image = ctx.createImageData(size, size);
    let seed = 0x2f6b1a3d;
    for (let i = 0; i < image.data.length; i += 4) {
      seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
      const value = seed >>> 24;
      image.data[i] = value;
      image.data[i + 1] = value;
      image.data[i + 2] = value;
      image.data[i + 3] = 255;
    }
    ctx.putImageData(image, 0, 0);
  }
  noise = tile;
  return tile;
}

/**
 * Draws the flat NM-B jacket from the knockout to where it was cut back. Meant for the
 * static layer: it uses a blurred shadow and a texture overlay.
 *
 * @param ctx - Static layer context
 * @param from - Point at the knockout
 * @param to - Cut end of the jacket
 * @param width - Jacket width
 * @param sheath - Jacket color
 */
export function drawSheath(
  ctx: CanvasRenderingContext2D,
  from: { x: number; y: number },
  to: { x: number; y: number },
  width: number,
  sheath: Exclude<Sheath, 'none'>,
): void {
  const tones = SHEATH_TONES[sheath];
  const length = Math.hypot(to.x - from.x, to.y - from.y);
  const angle = Math.atan2(to.y - from.y, to.x - from.x);
  const cos = Math.cos(angle);
  const sin = Math.sin(angle);
  // Local +y points along the world normal (-sin, cos); it is lit when that faces up-left.
  const litBelow = -sin * -0.55 + cos * -0.835 > 0;

  ctx.save();
  ctx.translate(from.x, from.y);
  ctx.rotate(angle);

  // World-space shadow offset expressed in the rotated frame.
  const shadowX = SHADOW_NEAR.x * cos + SHADOW_NEAR.y * sin;
  const shadowY = -SHADOW_NEAR.x * sin + SHADOW_NEAR.y * cos;
  ctx.save();
  ctx.filter = 'blur(3px)';
  ctx.fillStyle = 'rgba(0, 0, 0, 0.42)';
  ctx.fillRect(shadowX, -width / 2 + shadowY, length, width);
  ctx.restore();

  ctx.save();
  ctx.beginPath();
  ctx.rect(0, -width / 2, length, width);
  ctx.clip();

  const gradient = ctx.createLinearGradient(0, -width / 2, 0, width / 2);
  const top = litBelow ? tones.dark : tones.light;
  const bottom = litBelow ? tones.light : tones.dark;
  gradient.addColorStop(0, mix(top, tones.base, 0.35));
  gradient.addColorStop(0.16, tones.base);
  gradient.addColorStop(0.5, mix(tones.base, tones.dark, 0.08));
  gradient.addColorStop(0.84, tones.base);
  gradient.addColorStop(1, mix(bottom, tones.base, 0.35));
  ctx.fillStyle = gradient;
  ctx.fillRect(0, -width / 2, length, width);

  // The insulated conductors show through the soft jacket as a faint ridge.
  ctx.strokeStyle = 'rgba(0, 0, 0, 0.06)';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(0, 0);
  ctx.lineTo(length, 0);
  ctx.stroke();

  const pattern = ctx.createPattern(noiseTile(), 'repeat');
  if (pattern) {
    ctx.globalCompositeOperation = 'overlay';
    ctx.globalAlpha = 0.09;
    ctx.fillStyle = pattern;
    ctx.fillRect(0, -width / 2, length, width);
    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = 'source-over';
  }

  // Slightly darker, compressed cut edge.
  const edge = ctx.createLinearGradient(length - 6, 0, length, 0);
  edge.addColorStop(0, 'rgba(0, 0, 0, 0)');
  edge.addColorStop(1, 'rgba(60, 50, 30, 0.35)');
  ctx.fillStyle = edge;
  ctx.fillRect(length - 6, -width / 2, 6, width);
  ctx.restore();

  // Paper filler fibers sticking out of the cut.
  ctx.strokeStyle = 'rgba(205, 186, 148, 0.85)';
  ctx.lineWidth = 1.4;
  ctx.lineCap = 'round';
  for (let i = 0; i < 7; i++) {
    const y = -width * 0.38 + (width * 0.76 * i) / 6;
    const reach = 4 + ((i * 7) % 5);
    ctx.beginPath();
    ctx.moveTo(length - 1, y);
    ctx.lineTo(length + reach, y + (i % 2 === 0 ? 1.5 : -1.5));
    ctx.stroke();
  }
  ctx.restore();
}

/**
 * Draws an image centered on a point, rotated, at a given width.
 *
 * @param ctx - Scene context
 * @param image - Decoded sprite
 * @param x - Center x
 * @param y - Center y
 * @param width - Drawn width; height follows the image aspect ratio
 * @param angle - Rotation in radians
 */
export function drawSprite(
  ctx: CanvasRenderingContext2D,
  image: HTMLImageElement,
  x: number,
  y: number,
  width: number,
  angle = 0,
): void {
  const height = (width * image.naturalHeight) / image.naturalWidth;
  ctx.save();
  ctx.translate(x, y);
  if (angle !== 0) ctx.rotate(angle);
  ctx.drawImage(image, -width / 2, -height / 2, width, height);
  ctx.restore();
}

/**
 * Draws a masking tape flag with handwritten marker text. Meant for the static layer.
 *
 * @param ctx - Static layer context
 * @param tape - Masking tape sprite
 * @param text - Label text
 * @param x - Center x
 * @param y - Center y
 * @param angle - Rotation in radians
 */
export function drawTag(
  ctx: CanvasRenderingContext2D,
  tape: HTMLImageElement,
  text: string,
  x: number,
  y: number,
  angle: number,
): void {
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(angle);
  ctx.save();
  ctx.filter = 'blur(2px)';
  ctx.globalAlpha = 0.4;
  ctx.drawImage(tape, -58 + 3, -14 + 5, 116, 30);
  ctx.restore();
  ctx.drawImage(tape, -58, -14, 116, 28);
  ctx.fillStyle = 'rgba(20, 22, 30, 0.9)';
  ctx.font = '19px "Permanent Marker", "Segoe Print", cursive';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(text, 0, 1, 104);
  ctx.restore();
}
