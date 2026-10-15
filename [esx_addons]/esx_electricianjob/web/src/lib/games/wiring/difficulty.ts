/**
 * Per-tier rules of the junction box round. Timers are generous on purpose: difficulty comes
 * from the wiring rules, not from rushing the player.
 */

import type { Difficulty } from '../../nui/messages';

/** Round settings for one difficulty tier. */
export interface WiringTier {
  /** Time limit in seconds */
  timeLimit: number;
  /** Mistakes (shocks, shorts, failed inspections, nicked wires) before the round is lost */
  maxMistakes: number;
  /** Whether a failed inspection highlights the conductors involved */
  highlightIssues: boolean;
}

/** Settings per tier. */
export const WIRING_TIERS: Readonly<Record<Difficulty, WiringTier>> = {
  1: { timeLimit: 180, maxMistakes: 4, highlightIssues: true },
  2: { timeLimit: 210, maxMistakes: 3, highlightIssues: true },
  3: { timeLimit: 240, maxMistakes: 3, highlightIssues: false },
};
