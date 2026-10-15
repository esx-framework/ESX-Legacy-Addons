/**
 * Player-facing texts of the junction box game. English by default; the Lua side can later
 * hand over translations from the resource locales.
 */

import type { IssueCode } from './electrical';
import type { NutColor, WiringTemplate } from './model';

/** Job description per scenario. */
export const BRIEFING: Readonly<Record<WiringTemplate, string>> = {
  'splice-through': 'Remake the splices so the outlets downstream get power back.',
  'switched-light': 'Hook up the ceiling light so the wall switch controls it.',
  'switched-light-feed-through':
    'Hook up the ceiling light on its switch and keep the outlets downstream live.',
};

/** Inspection findings. */
export const ISSUE_TEXT: Readonly<Record<IssueCode, string>> = {
  'short-circuit': 'Dead short: hot is touching neutral or ground.',
  'loose-conductor': 'Conductors are still loose in the box.',
  unstripped: 'A damaged end was spliced without stripping it first.',
  'missing-nut': 'A splice is not twisted tight under a wire nut.',
  'nut-overfilled': 'A wire nut is too small for its splice.',
  'fixture-dead': 'The light does not come on.',
  'fixture-always-on': 'The light ignores the wall switch.',
  'switched-neutral': 'The switch breaks the neutral instead of the hot.',
  'receptacle-dead': 'The outlets downstream have no power.',
  'reverse-polarity': 'Hot and neutral are swapped at a load.',
  'ground-open': 'The grounding path is incomplete.',
  'ground-misused': 'A ground is spliced together with current-carrying wires.',
  'unmarked-white-hot': 'A white wire is used as hot without re-marking it.',
};

/** Rating card under each tray compartment. */
export const NUT_CARD: Readonly<Record<NutColor, readonly [string, string]>> = {
  orange: ['ORANGE', 'max 2 × 14'],
  yellow: ['YELLOW', 'max 3 × 12 · 4 × 14'],
  red: ['RED', 'max 4 × 12 · 5 × 14'],
};

/** Short feedback toasts. */
export const TOAST = {
  shock: 'Zap! That conductor is live.',
  short: 'Breaker tripped: short circuit.',
  nutTooSmall: 'That wire nut is too small for this bundle.',
  nutOccupied: 'Take the old wire nut off first.',
  nutSingle: 'A wire nut needs at least two conductors.',
  nicked: 'Notch too small: the blades nicked the copper.',
  slipped: 'Notch too large: the insulation did not come off.',
  stripped: 'Clean strip.',
  notDamaged: 'That end is already stripped.',
  taped: 'Re-marked as hot.',
  twist: 'Twist the wire nut clockwise until it bites.',
  passed: 'Inspection passed.',
  failed: 'Inspection failed.',
  timeout: 'Out of time.',
} as const;

/** HUD labels. */
export const LABEL = {
  workOrder: 'Work order',
  title: 'Junction box',
  mistakes: 'Mistakes',
  panel: 'Panel',
  breaker: 'Breaker',
  wallSwitch: 'Wall switch',
  loads: 'Loads',
  fixture: 'Ceiling light',
  outlet: 'Outlet',
  on: 'ON',
  off: 'OFF',
  live: 'live',
  dead: 'dead',
  inspect: 'Inspect',
  abort: 'Abort',
  stripperNotch: 'Stripper notch',
  awg: 'AWG',
} as const;
