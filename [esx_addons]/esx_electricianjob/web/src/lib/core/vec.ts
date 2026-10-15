/**
 * Minimal 2D vector helpers for scene geometry. Vectors are plain immutable objects so they
 * can live in Svelte state and be serialised.
 */

/** Point or direction in scene units. */
export interface Vec2 {
  /** Horizontal component, growing to the right */
  readonly x: number;
  /** Vertical component, growing downwards */
  readonly y: number;
}

/**
 * @param x - Horizontal component
 * @param y - Vertical component
 * @returns New vector
 */
export function vec(x: number, y: number): Vec2 {
  return { x, y };
}

/** @returns a + b */
export function add(a: Vec2, b: Vec2): Vec2 {
  return { x: a.x + b.x, y: a.y + b.y };
}

/** @returns a - b */
export function sub(a: Vec2, b: Vec2): Vec2 {
  return { x: a.x - b.x, y: a.y - b.y };
}

/** @returns v scaled by s */
export function scale(v: Vec2, s: number): Vec2 {
  return { x: v.x * s, y: v.y * s };
}

/** @returns Euclidean length of v */
export function length(v: Vec2): number {
  return Math.hypot(v.x, v.y);
}

/** @returns Distance between a and b */
export function distance(a: Vec2, b: Vec2): number {
  return Math.hypot(a.x - b.x, a.y - b.y);
}

/** @returns v with length 1, or the zero vector for a zero input */
export function normalize(v: Vec2): Vec2 {
  const len = Math.hypot(v.x, v.y);
  return len === 0 ? { x: 0, y: 0 } : { x: v.x / len, y: v.y / len };
}

/** @returns v rotated 90° clockwise in screen space */
export function perpendicular(v: Vec2): Vec2 {
  return { x: -v.y, y: v.x };
}

/** @returns Dot product */
export function dot(a: Vec2, b: Vec2): number {
  return a.x * b.x + a.y * b.y;
}

/** @returns Linear interpolation between a and b */
export function lerp(a: Vec2, b: Vec2, t: number): Vec2 {
  return { x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t };
}

/** @returns v rotated by angle radians */
export function rotate(v: Vec2, angle: number): Vec2 {
  const cos = Math.cos(angle);
  const sin = Math.sin(angle);
  return { x: v.x * cos - v.y * sin, y: v.x * sin + v.y * cos };
}

/** @returns Angle of v in radians, 0 pointing right */
export function angleOf(v: Vec2): number {
  return Math.atan2(v.y, v.x);
}

/**
 * Distance from a point to a line segment.
 *
 * @param p - Query point
 * @param a - Segment start
 * @param b - Segment end
 * @returns Shortest distance
 */
export function distanceToSegment(p: Vec2, a: Vec2, b: Vec2): number {
  const abx = b.x - a.x;
  const aby = b.y - a.y;
  const lengthSq = abx * abx + aby * aby;
  const t =
    lengthSq === 0
      ? 0
      : Math.max(0, Math.min(1, ((p.x - a.x) * abx + (p.y - a.y) * aby) / lengthSq));
  return Math.hypot(p.x - (a.x + abx * t), p.y - (a.y + aby * t));
}
