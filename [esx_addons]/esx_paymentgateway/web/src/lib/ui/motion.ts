/**
 * Motion of the dialog: shared durations and easing, and the transitions that use them. Timings
 * follow common checkout feedback: about 250 ms to come in, under 200 ms to leave, around 400 ms
 * for the success mark. Players who ask the system for less motion get fades only.
 *
 * @see rise
 */

import { cubicOut } from 'svelte/easing';
import type { TransitionConfig } from 'svelte/transition';

/** Durations in milliseconds. */
export const DURATION = {
  /** Dialog and receipt coming in */
  enter: 260,
  /** Dialog leaving */
  leave: 170,
  /** Gap between staggered rows */
  stagger: 45,
} as const;

/**
 * @returns Whether the player asked the system for reduced motion
 */
export function prefersReducedMotion(): boolean {
  return typeof matchMedia === 'function' && matchMedia('(prefers-reduced-motion: reduce)').matches;
}

/** Options of {@link rise}. */
export interface RiseOptions {
  /** Start delay in milliseconds */
  delay?: number;
  /** Duration in milliseconds */
  duration?: number;
  /** Distance travelled upwards, in pixels */
  distance?: number;
  /** Scale the element starts at */
  from?: number;
}

/**
 * Fades an element in while it rises and grows into place.
 *
 * @param _node - Element the transition runs on
 * @param options - Timing and travel
 * @returns The transition
 */
export function rise(_node: Element, options: RiseOptions = {}): TransitionConfig {
  const { delay = 0, duration = DURATION.enter, distance = 10, from = 0.98 } = options;
  const still = prefersReducedMotion();
  return {
    delay,
    duration,
    easing: cubicOut,
    css: (t: number, u: number): string =>
      still
        ? `opacity: ${t}`
        : `opacity: ${t}; transform: translateY(${u * distance}px) scale(${from + (1 - from) * t})`,
  };
}
