/**
 * Shape of a solid conductor between its fixed anchor and its free end.
 *
 * Solid copper building wire is stiff: it leaves the jacket in a straight line and bends in
 * wide arcs, it never hooks back on itself. A cubic Bézier with handles proportional to the
 * span and capped in length gives that look. The free length of the conductor only limits
 * how far the end can travel (see the engine), it does not stretch the curve. The curve is
 * sampled into a fixed-size polyline that drawing and hit testing share.
 *
 * Each sample also stores where the light-facing side of the wire is: the light direction
 * minus its component along the wire. Shading layers are shifted along that vector, so the
 * highlight sits on the lit flank whatever way the wire runs, and centered when the wire
 * points straight at the light.
 *
 * @see sampleWire
 */

import type { Vec2 } from '../../../core/vec';

/** Number of points per sampled wire. */
export const WIRE_SAMPLES = 32;

/** Key light of the scene, pointing from the scene toward the light (top left). */
const LIGHT_X = -0.55;
const LIGHT_Y = -0.835;

/** Inputs for one wire. */
export interface WirePose {
  /** Fixed start */
  anchor: Vec2;
  /** Unit direction at the anchor */
  direction: Vec2;
  /** Free end */
  end: Vec2;
  /** Unit direction the end points to */
  endDirection: Vec2;
}

/** Sampled wire, reused between frames to avoid allocations. */
export interface WirePolyline {
  /** Interleaved x, y coordinates */
  readonly points: Float32Array;
  /** Arc length from the anchor to each point */
  readonly distances: Float32Array;
  /** Interleaved per-point offset toward the lit side, length up to 1 */
  readonly lit: Float32Array;
}

/**
 * Length of the Bézier handle at the anchor.
 *
 * @param span - Straight distance from anchor to end
 * @returns Handle length in scene units
 */
export function startHandleFor(span: number): number {
  return Math.min(170, Math.max(24, span * 0.42));
}

/**
 * @returns Empty polyline buffers for {@link sampleWire}
 */
export function createPolyline(): WirePolyline {
  return {
    points: new Float32Array(WIRE_SAMPLES * 2),
    distances: new Float32Array(WIRE_SAMPLES),
    lit: new Float32Array(WIRE_SAMPLES * 2),
  };
}

/**
 * Samples the wire curve into a polyline.
 *
 * @param pose - Anchor, end and length of the wire
 * @param out - Buffers to write into
 * @returns Total arc length of the sampled curve
 */
export function sampleWire(pose: WirePose, out: WirePolyline): number {
  const { anchor, direction, end, endDirection } = pose;
  const span = Math.hypot(end.x - anchor.x, end.y - anchor.y);
  const startHandle = startHandleFor(span);
  const endHandle = Math.min(120, Math.max(16, span * 0.3));

  const p1x = anchor.x + direction.x * startHandle;
  const p1y = anchor.y + direction.y * startHandle;
  const p2x = end.x - endDirection.x * endHandle;
  const p2y = end.y - endDirection.y * endHandle;

  const { points, distances } = out;
  let total = 0;
  let prevX = anchor.x;
  let prevY = anchor.y;
  for (let i = 0; i < WIRE_SAMPLES; i++) {
    const t = i / (WIRE_SAMPLES - 1);
    const u = 1 - t;
    const a = u * u * u;
    const b = 3 * u * u * t;
    const c = 3 * u * t * t;
    const d = t * t * t;
    const x = a * anchor.x + b * p1x + c * p2x + d * end.x;
    const y = a * anchor.y + b * p1y + c * p2y + d * end.y;
    if (i > 0) total += Math.hypot(x - prevX, y - prevY);
    points[i * 2] = x;
    points[i * 2 + 1] = y;
    distances[i] = total;
    prevX = x;
    prevY = y;
  }
  computeLighting(out);
  return total;
}

function computeLighting(line: WirePolyline): void {
  const { points, lit } = line;
  const last = WIRE_SAMPLES - 1;
  for (let i = 0; i <= last; i++) {
    const a = Math.max(0, i - 1) * 2;
    const b = Math.min(last, i + 1) * 2;
    let tx = (points[b] as number) - (points[a] as number);
    let ty = (points[b + 1] as number) - (points[a + 1] as number);
    const len = Math.hypot(tx, ty) || 1;
    tx /= len;
    ty /= len;
    const along = LIGHT_X * tx + LIGHT_Y * ty;
    lit[i * 2] = LIGHT_X - along * tx;
    lit[i * 2 + 1] = LIGHT_Y - along * ty;
  }
}

/**
 * Traces the part of a polyline between two arc lengths as the current canvas path.
 *
 * @param ctx - Canvas context; a new path is begun
 * @param line - Sampled wire
 * @param from - Start arc length
 * @param to - End arc length
 * @param shift - Distance to move every point toward the lit side of the wire
 * @param dx - Horizontal offset applied to every point
 * @param dy - Vertical offset applied to every point
 */
export function traceRange(
  ctx: CanvasRenderingContext2D,
  line: WirePolyline,
  from: number,
  to: number,
  shift = 0,
  dx = 0,
  dy = 0,
): void {
  const { points, distances, lit } = line;
  ctx.beginPath();
  let started = false;
  for (let i = 1; i < WIRE_SAMPLES; i++) {
    const d0 = distances[i - 1] as number;
    const d1 = distances[i] as number;
    if (d1 < from || d0 > to) continue;
    const x0 = points[(i - 1) * 2] as number;
    const y0 = points[(i - 1) * 2 + 1] as number;
    const x1 = points[i * 2] as number;
    const y1 = points[i * 2 + 1] as number;
    const ox0 = dx + (lit[(i - 1) * 2] as number) * shift;
    const oy0 = dy + (lit[(i - 1) * 2 + 1] as number) * shift;
    const ox1 = dx + (lit[i * 2] as number) * shift;
    const oy1 = dy + (lit[i * 2 + 1] as number) * shift;
    const segment = d1 - d0 || 1;
    if (!started) {
      const t = Math.max(0, (from - d0) / segment);
      ctx.moveTo(
        x0 + (x1 - x0) * t + ox0 + (ox1 - ox0) * t,
        y0 + (y1 - y0) * t + oy0 + (oy1 - oy0) * t,
      );
      started = true;
    }
    const t = Math.min(1, (to - d0) / segment);
    ctx.lineTo(
      x0 + (x1 - x0) * t + ox0 + (ox1 - ox0) * t,
      y0 + (y1 - y0) * t + oy0 + (oy1 - oy0) * t,
    );
  }
}

/**
 * Shortest distance from a point to a polyline.
 *
 * @param line - Sampled wire
 * @param x - Query x
 * @param y - Query y
 * @returns Distance in scene units
 */
export function distanceToPolyline(line: WirePolyline, x: number, y: number): number {
  const { points } = line;
  let best = Infinity;
  for (let i = 1; i < WIRE_SAMPLES; i++) {
    const ax = points[(i - 1) * 2] as number;
    const ay = points[(i - 1) * 2 + 1] as number;
    const bx = points[i * 2] as number;
    const by = points[i * 2 + 1] as number;
    const abx = bx - ax;
    const aby = by - ay;
    const lengthSq = abx * abx + aby * aby;
    const t =
      lengthSq === 0 ? 0 : Math.max(0, Math.min(1, ((x - ax) * abx + (y - ay) * aby) / lengthSq));
    const d = Math.hypot(x - (ax + abx * t), y - (ay + aby * t));
    if (d < best) best = d;
  }
  return best;
}
