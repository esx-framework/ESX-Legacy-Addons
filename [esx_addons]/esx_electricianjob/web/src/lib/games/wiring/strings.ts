/**
 * Player-facing texts of the junction box game. English by default; the Lua side can later
 * hand over translations from the resource locales.
 */

import type { IssueCode } from './electrical';
import type { Move } from './coach';
import type { AimReason, ToolKind } from './engine';
import type { BundleRole, StepId } from './guide';
import type { NutColor, WiringTemplate } from './model';

/** Job description per scenario. */
export const BRIEFING: Readonly<Record<WiringTemplate, string>> = {
  'splice-through': 'Remake the splices so the outlets downstream get power back.',
  'switched-light': 'Hook up the ceiling light so the wall switch controls it.',
  'switched-light-feed-through':
    'Hook up the ceiling light on its switch and keep the outlets downstream live.',
};

/** Customer-facing texts of one scenario on the work order. */
export interface OrderScenarioText {
  /** Rooms the job can be in, lower case */
  rooms: readonly string[];
  /** Where the box is, from the room and a utility spot from {@link BOX_PLACES} */
  location: (room: string, place: string) => string;
  /** What the customer reported, given the room */
  complaints: readonly ((room: string) => string)[];
}

/** Utility spots where a splice box sits out of sight. */
export const BOX_PLACES: readonly string[] = [
  'Basement ceiling',
  'Garage wall',
  'Laundry room',
  'Utility closet',
  'Crawl space',
  'Attic hatch',
];

function capitalize(text: string): string {
  return text.charAt(0).toUpperCase() + text.slice(1);
}

/** Work order texts per scenario. */
export const ORDER_SCENARIOS: Readonly<Record<WiringTemplate, OrderScenarioText>> = {
  'splice-through': {
    rooms: ['kitchen', 'living room', 'bedroom', 'office', 'dining room', 'den'],
    location: (_room: string, place: string): string => place,
    complaints: [
      (room: string): string => `Outlets in the ${room} went dead after the remodel.`,
      (room: string): string => `Half the ${room} outlets quit. Breaker looks fine.`,
      (room: string): string => `${capitalize(room)} outlets keep cutting out, now nothing.`,
    ],
  },
  'switched-light': {
    rooms: ['living room', 'bedroom', 'hallway', 'kitchen', 'office', 'dining room'],
    location: (room: string): string => `${capitalize(room)} ceiling`,
    complaints: [
      (room: string): string => `New ceiling light for the ${room}, should run off the switch.`,
      (room: string): string => `Old ${room} light is gone. Put the new one on the switch.`,
      (room: string): string => `Bought a ${room} light, needs hooking up to the wall switch.`,
    ],
  },
  'switched-light-feed-through': {
    rooms: ['living room', 'bedroom', 'kitchen', 'office', 'den'],
    location: (room: string): string => `${capitalize(room)} ceiling`,
    complaints: [
      (room: string): string => `Swap the ${room} light. Outlets fed from that box stay live.`,
      (room: string): string =>
        `${capitalize(room)} light on the switch, and keep the outlets working.`,
    ],
  },
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
  help: 'Help',
  next: 'Next',
  start: 'Got it',
  checklist: 'Job steps',
  plan: 'Wiring plan',
  cables: 'Cables in the box',
  rules: 'Wire colors',
  hint: 'Hint',
  unlabeled: 'no label',
  unlabeledHint: 'find it with the tester',
} as const;

/** Checklist lines. */
export const STEP_TEXT: Readonly<Record<StepId, string>> = {
  test: 'Find the live cable with the tester',
  'power-off': 'Switch the breaker off',
  strip: 'Strip the damaged wire ends',
  mark: 'Tape the white switch wire black',
  bundle: 'Bundle the wires that belong together',
  cap: 'Twist a wire nut onto every bundle',
  'power-on': 'Switch the breaker back on',
  switch: 'Flip the wall switch, the light must come on',
  inspect: 'Press Inspect',
};

/** Names and one-line explanations of the bundles in the plan. */
export const BUNDLE_TEXT: Readonly<Record<BundleRole, readonly [string, string]>> = {
  hot: ['Always hot', 'power in, passed on'],
  switched: ['Switched hot', 'from the switch to the light'],
  neutral: ['Neutral', 'the return path'],
  ground: ['Ground', 'all bare copper'],
};

/** Color rules on the reference card. */
export const RULES: readonly (readonly [string, string])[] = [
  ['Black, red', 'hot, carries power'],
  ['White', 'neutral, the return path'],
  ['White taped black', 'used as hot'],
  ['Bare copper', 'ground'],
];

/** Extra line under the color rules. */
export const RULES_NOTE =
  'Never mix hot, neutral and ground in one bundle. Switch cable: black takes power to the switch, red or the taped white brings it back to the light.';

/** Names and usage hints of things in the tray. */
export const ITEM_TEXT: Readonly<Record<ToolKind | NutColor, readonly [string, string]>> = {
  tester: ['Voltage tester', 'drag it over a cable: it beeps when live'],
  stripper: ['Wire stripper', 'drop it on a damaged wire end'],
  tape: ['Electrical tape', 'drop it on a white wire to mark it hot'],
  orange: ['Wire nut, orange', 'max 2 wires 14 AWG'],
  yellow: ['Wire nut, yellow', 'max 3 × 12 or 4 × 14 AWG'],
  red: ['Wire nut, red', 'max 4 × 12 or 5 × 14 AWG'],
};

/** Cursor badge texts. */
export const AIM_TEXT = {
  grab: 'Drag',
  move: 'Move bundle',
  twist: 'Circle clockwise to tighten',
  join: 'Join',
  strip: 'Strip',
  tape: 'Mark as hot',
  cap: 'Put on wire nut',
  live: 'LIVE',
} as const;

/** Cursor badge texts for blocked actions and warnings. */
export const AIM_REASON: Readonly<Record<AimReason, string>> = {
  'not-damaged': 'Already stripped',
  'already-marked': 'Already marked',
  'too-small': 'Too small for this bundle',
  occupied: 'Has a wire nut already',
  'breaker-on': 'Breaker is on: bare copper may be live',
  'no-voltage': 'No voltage',
};

/** One page of the tutorial. */
export interface TutorialPage {
  /** Heading */
  title: string;
  /** Body text */
  body: string;
}

/** Tutorial shown on first play and from the Help button. */
export const TUTORIAL: readonly TutorialPage[] = [
  {
    title: 'Power off first',
    body: 'Bare copper can be live. Sweep the voltage tester over the cables: it beeps at the live one. Then switch the breaker off in the panel on the left.',
  },
  {
    title: 'Bundle what belongs together',
    body: 'Drag a wire end onto another one to bundle them. Black goes with black, white with white, bare copper with bare copper. On easier jobs the wiring plan on the left shows every bundle.',
  },
  {
    title: 'Cap and twist',
    body: 'Drag a wire nut from the tray onto the bundle and circle the mouse clockwise until it is tight. The card under the tray tells you which size fits. Right-click takes a nut off again.',
  },
  {
    title: 'Test, then inspect',
    body: 'Switch the breaker back on and flip the wall switch: the light has to come on. When everything works, press Inspect. The checklist on the left always shows the next step.',
  },
];

/** Plain-language text of the next move, shown under the hint arrow. */
export const MOVE_TEXT: Readonly<Record<Move['kind'], string>> = {
  test: 'Sweep the voltage tester over the marked cable: it beeps when the cable is live',
  breaker: 'Switch the breaker off before you touch anything (panel, top left)',
  switch: 'Flip the wall switch: the light should come on',
  inspect: 'All done. Press Inspect',
  strip: 'Drop the wire stripper on the glowing wire end',
  tape: 'Drop the black tape on the glowing white wire',
  unnut: 'Wrong wires in this bundle: right-click the wire nut to take it off',
  separate: 'This wire does not belong here: drag it out of the bundle',
  place: 'Drag the glowing wire to the marked spot',
  join: 'Drag the glowing wire onto the marked bundle',
  nut: 'Drag the marked wire nut onto the bundle',
  twist: 'Hold the wire nut and circle the mouse clockwise until it is tight',
};

/** Hint texts that name the numbered markers, used on the first tier. */
export const NUMBERED_MOVE_TEXT = {
  place: (n: number): string => `Drag wire ${n} to the marked spot`,
  join: (n: number): string => `Drag wire ${n} onto the marked wire ${n}`,
  nut: (n: number, color: string): string => `Drag a ${color} wire nut onto bundle ${n}`,
} as const;

/** Breaker hint once the box is finished. */
export const MOVE_POWER_ON = 'Everything is capped: switch the breaker back on';
