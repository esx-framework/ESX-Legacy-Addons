/**
 * Per-tier rules of the junction box round. Timers are generous on purpose: difficulty comes
 * from the wiring rules, not from rushing the player.
 */

import type { Difficulty } from '../../nui/messages';

/** How much the game helps on a tier. */
export type Guidance =
  /** Numbered wire markers and a permanent next-move arrow; no electrical knowledge needed */
  | 'full'
  /** A few next-move hints on request */
  | 'hints'
  /** Rules card only */
  | 'none';

/** Round settings for one difficulty tier. */
export interface WiringTier {
  /** Job grade shown in the HUD */
  name: string;
  /** Time limit in seconds */
  timeLimit: number;
  /** Mistakes (shocks, shorts, failed inspections, nicked wires) before the round is lost */
  maxMistakes: number;
  /** Whether a failed inspection highlights the conductors involved */
  highlightIssues: boolean;
  /** How much the game helps */
  guidance: Guidance;
  /** Hints the player can ask for, used with `hints` guidance */
  hints: number;
}

/** Settings per tier. */
export const WIRING_TIERS: Readonly<Record<Difficulty, WiringTier>> = {
  1: {
    name: 'Apprentice',
    timeLimit: 240,
    maxMistakes: 5,
    highlightIssues: true,
    guidance: 'full',
    hints: 0,
  },
  2: {
    name: 'Journeyman',
    timeLimit: 210,
    maxMistakes: 3,
    highlightIssues: true,
    guidance: 'hints',
    hints: 3,
  },
  3: {
    name: 'Master',
    timeLimit: 240,
    maxMistakes: 3,
    highlightIssues: false,
    guidance: 'none',
    hints: 0,
  },
};
