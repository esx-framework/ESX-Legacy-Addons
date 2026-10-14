/**
 * Data model of the junction box minigame.
 *
 * A {@link WiringPuzzle} describes the box as the generator built it: which cables enter,
 * where their far ends land (panel, switch, fixture, receptacles) and what the player can see
 * on them. {@link WiringState} is what the player did inside the box. Neither contains a
 * "solution"; correctness is decided by simulating the circuit.
 *
 * Pure data, no DOM or Svelte dependencies, so the server can use the same module.
 *
 * @see evaluateWiring
 * @see generateWiringPuzzle
 */

import type { Difficulty } from '../../nui/messages';

/** American Wire Gauge of a conductor. 18 AWG only appears as stranded fixture leads. */
export type Awg = 18 | 14 | 12 | 10;

/** Insulation color; bare means an uninsulated grounding conductor. */
export type Insulation = 'black' | 'red' | 'white' | 'bare' | 'green';

/** What a cable connects the box to. */
export type CableRole = 'line' | 'switch' | 'fixture' | 'receptacle';

/** Outer sheath of a cable. NM-B jackets are colored by gauge; fixture leads have none. */
export type Sheath = 'white' | 'yellow' | 'orange' | 'none';

/** Twist-on wire connector sizes in the tray. */
export type NutColor = 'orange' | 'yellow' | 'red';

/** All nut colors, smallest first. */
export const NUT_COLORS: readonly NutColor[] = ['orange', 'yellow', 'red'];

/** Circuit breaker rating feeding the box. */
export type BreakerAmps = 15 | 20;

/** How the switch is fed. */
export type SwitchLoopStyle =
  /** 3-conductor cable: black always hot, red switched return, white neutral capped at switch */
  | 'three-wire'
  /** Legacy 2-conductor loop whose white is already re-marked with black tape */
  | 'two-wire-marked'
  /** Legacy 2-conductor loop; the player has to re-mark the white before using it as hot */
  | 'two-wire-unmarked';

/** Junction box scenario the generator started from. */
export type WiringTemplate = 'splice-through' | 'switched-light' | 'switched-light-feed-through';

/**
 * Electrical node at the far end of a conductor or inside a device. Formatted as
 * `<device>.<terminal>`, e.g. `panel.hot`, `switch.a`, `rec1.neutral`, `box.ground`.
 */
export type TerminalId = string;

/** One insulated or bare wire inside a cable. */
export interface Conductor {
  /** Stable id, `<cableId>.<insulation>`, used in the action log */
  id: string;
  /** Cable the conductor belongs to */
  cableId: string;
  /** Insulation color */
  insulation: Insulation;
  /** Wire size */
  awg: Awg;
  /** Stranded fixture lead instead of solid building wire */
  stranded: boolean;
  /** Where the far end of the conductor is landed */
  terminal: TerminalId;
  /** Re-identified as hot with black tape when the round starts */
  marked: boolean;
  /** The box end is cut back or nicked and has to be stripped before splicing */
  needsStrip: boolean;
}

/** Cable entering the box. */
export interface Cable {
  /** Stable id, e.g. `c1`; fixture leads use `fx`, the bonding jumper `pg` */
  id: string;
  /** What the cable connects to */
  role: CableRole | 'pigtail';
  /** Gauge of the circuit conductors */
  awg: Awg;
  /** Jacket color */
  sheath: Sheath;
  /** Text on the masking tape flag a previous electrician left, null if there is none */
  tag: string | null;
  /** Conductors in the order they leave the jacket */
  conductorIds: readonly string[];
}

/** Something that draws current between a hot and a neutral terminal. */
export interface Load {
  /** Device id, e.g. `fixture` or `rec1` */
  id: string;
  /** Lamp or downstream receptacle */
  kind: 'fixture' | 'receptacle';
  /** Terminal that has to be hot */
  hot: TerminalId;
  /** Terminal that has to be neutral */
  neutral: TerminalId;
  /** Equipment ground terminal */
  ground: TerminalId;
  /** Whether the load is supposed to follow the wall switch */
  switched: boolean;
}

/** Wall switch at the far end of the switch loop. */
export interface WallSwitch {
  /** Terminals bridged when the switch is on */
  poles: readonly [TerminalId, TerminalId];
}

/** A generated round. */
export interface WiringPuzzle {
  /** Seed the round was generated from */
  seed: number;
  /** Difficulty tier */
  difficulty: Difficulty;
  /** Scenario the generator picked */
  template: WiringTemplate;
  /** Breaker feeding the box */
  breakerAmps: BreakerAmps;
  /** Cables in the box, including fixture leads and the bonding jumper */
  cables: readonly Cable[];
  /** Every conductor of every cable */
  conductors: readonly Conductor[];
  /** Loads that have to work when the job is done */
  loads: readonly Load[];
  /** Wall switch, null when the box has no switch loop */
  wallSwitch: WallSwitch | null;
  /** Switch loop wiring, null when the box has no switch loop */
  switchLoop: SwitchLoopStyle | null;
}

/** A group of conductor ends joined inside the box. */
export interface Splice {
  /** Id assigned by the UI */
  id: string;
  /** Joined conductors */
  conductorIds: readonly string[];
  /** Twist-on connector holding them, null while the ends are only held together */
  nut: NutColor | null;
}

/** Everything the player changed in the box. */
export interface WiringState {
  /** Splices made so far */
  splices: readonly Splice[];
  /** Conductors the player stripped */
  stripped: ReadonlySet<string>;
  /** Conductors the player re-marked with tape */
  taped: ReadonlySet<string>;
}

/** Breaker and wall switch positions for a simulation run. */
export interface Controls {
  /** Breaker in the panel */
  breakerOn: boolean;
  /** Wall switch at the end of the switch loop */
  switchOn: boolean;
}
