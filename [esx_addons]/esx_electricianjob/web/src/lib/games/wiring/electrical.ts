/**
 * Electrical rules of the junction box: connector ratings, circuit simulation and the final
 * inspection that decides whether a job passes.
 *
 * The panel bonds neutral and ground, so any path from hot to either one is a bolted fault.
 * Loads are treated as open circuits for connectivity; a load works when its hot terminal
 * shares a node with the source hot and its neutral terminal with the source neutral.
 *
 * @see simulateWiring
 * @see evaluateWiring
 */

import type {
  Awg,
  Conductor,
  Controls,
  Load,
  NutColor,
  Splice,
  TerminalId,
  WiringPuzzle,
  WiringState,
} from './model';

/** Source terminals in the panel. */
export const PANEL_HOT: TerminalId = 'panel.hot';
export const PANEL_NEUTRAL: TerminalId = 'panel.neutral';
export const PANEL_GROUND: TerminalId = 'panel.ground';
/** The green screw in the back of the metal box. */
export const BOX_GROUND: TerminalId = 'box.ground';

/** Cross-section in mm², used for connector fill. */
export const AWG_AREA_MM2: Readonly<Record<Awg, number>> = {
  18: 0.823,
  14: 2.08,
  12: 3.31,
  10: 5.26,
};

/** Rating of a twist-on connector, after the common orange/yellow/red sizes. */
export interface NutRating {
  /** Most conductors the connector holds */
  maxConductors: number;
  /** Largest total copper cross-section in mm² */
  maxAreaMm2: number;
  /** Rating printed on the tray card */
  label: string;
}

/** Connector ratings, smallest first. */
export const NUT_RATINGS: Readonly<Record<NutColor, NutRating>> = {
  orange: { maxConductors: 3, maxAreaMm2: 2 * AWG_AREA_MM2[14], label: 'max 2 × 14 AWG' },
  yellow: { maxConductors: 4, maxAreaMm2: 3 * AWG_AREA_MM2[12], label: 'max 3 × 12 / 4 × 14 AWG' },
  red: { maxConductors: 5, maxAreaMm2: 4 * AWG_AREA_MM2[12], label: 'max 4 × 12 / 5 × 14 AWG' },
};

/** Result of one simulation run. */
export interface Simulation {
  /** Hot touches neutral or ground; the breaker trips */
  shorted: boolean;
  /** Conductor ids carrying line voltage, empty when the breaker is off or tripped */
  energized: ReadonlySet<string>;
  /** Per load: working, working with swapped hot and neutral, or dead */
  loads: ReadonlyMap<string, LoadState>;
}

/** State of a load in a simulation run. */
export type LoadState = 'on' | 'reversed' | 'off';

/** Reasons a job fails inspection. */
export type IssueCode =
  | 'short-circuit'
  | 'loose-conductor'
  | 'unstripped'
  | 'missing-nut'
  | 'nut-overfilled'
  | 'fixture-dead'
  | 'fixture-always-on'
  | 'switched-neutral'
  | 'receptacle-dead'
  | 'reverse-polarity'
  | 'ground-open'
  | 'ground-misused'
  | 'unmarked-white-hot';

/** One inspection finding. */
export interface Issue {
  /** What is wrong */
  code: IssueCode;
  /** Conductors, splices or loads involved, for highlighting */
  refs: readonly string[];
}

/** Union-find over string keys. */
class Nodes {
  private readonly parent = new Map<string, string>();

  find(key: string): string {
    let root = this.parent.get(key) ?? key;
    if (root === key) return key;
    root = this.find(root);
    this.parent.set(key, root);
    return root;
  }

  join(a: string, b: string): void {
    const rootA = this.find(a);
    const rootB = this.find(b);
    if (rootA !== rootB) this.parent.set(rootA, rootB);
  }

  same(a: string, b: string): boolean {
    return this.find(a) === this.find(b);
  }
}

function boxEnd(conductorId: string): string {
  return `box:${conductorId}`;
}

/**
 * Whether a splice is mechanically sound, i.e. every conductor is stripped and held by a nut.
 * Ends that are only held together do not conduct reliably and count as open.
 */
function isMadeUp(
  splice: Splice,
  state: WiringState,
  byId: ReadonlyMap<string, Conductor>,
): boolean {
  if (splice.nut === null || splice.conductorIds.length < 2) return false;
  return splice.conductorIds.every((id: string): boolean => {
    const conductor: Conductor | undefined = byId.get(id);
    return conductor !== undefined && (!conductor.needsStrip || state.stripped.has(id));
  });
}

function buildNodes(puzzle: WiringPuzzle, state: WiringState, switchOn: boolean): Nodes {
  const nodes = new Nodes();
  const byId = new Map(puzzle.conductors.map((c: Conductor): [string, Conductor] => [c.id, c]));

  for (const conductor of puzzle.conductors) nodes.join(boxEnd(conductor.id), conductor.terminal);
  for (const splice of state.splices) {
    if (!isMadeUp(splice, state, byId)) continue;
    const [first, ...rest] = splice.conductorIds;
    if (first === undefined) continue;
    for (const id of rest) nodes.join(boxEnd(first), boxEnd(id));
  }
  if (switchOn && puzzle.wallSwitch) nodes.join(...puzzle.wallSwitch.poles);
  return nodes;
}

function loadState(load: Load, nodes: Nodes): LoadState {
  if (nodes.same(load.hot, PANEL_HOT) && nodes.same(load.neutral, PANEL_NEUTRAL)) return 'on';
  if (nodes.same(load.hot, PANEL_NEUTRAL) && nodes.same(load.neutral, PANEL_HOT)) return 'reversed';
  return 'off';
}

/**
 * Runs the circuit with the given breaker and switch positions.
 *
 * @param puzzle - Generated round
 * @param state - Splices and markings made by the player
 * @param controls - Breaker and switch positions
 * @returns What the player would observe: short, energized conductors and load states
 */
export function simulateWiring(
  puzzle: WiringPuzzle,
  state: WiringState,
  controls: Controls,
): Simulation {
  const nodes = buildNodes(puzzle, state, controls.switchOn);
  const shorted = nodes.same(PANEL_HOT, PANEL_NEUTRAL) || nodes.same(PANEL_HOT, PANEL_GROUND);
  const live = controls.breakerOn && !shorted;

  const energized = new Set<string>();
  if (live) {
    for (const conductor of puzzle.conductors) {
      if (nodes.same(boxEnd(conductor.id), PANEL_HOT)) energized.add(conductor.id);
    }
  }

  const loads = new Map<string, LoadState>();
  for (const load of puzzle.loads) loads.set(load.id, live ? loadState(load, nodes) : 'off');

  return { shorted: controls.breakerOn && shorted, energized, loads };
}

/**
 * Total copper cross-section of a set of conductors.
 *
 * @param conductors - Conductors in one splice
 * @returns Area in mm²
 */
export function spliceArea(conductors: readonly Conductor[]): number {
  return conductors.reduce((sum: number, c: Conductor): number => sum + AWG_AREA_MM2[c.awg], 0);
}

/**
 * Whether a connector is rated for a group of conductors.
 *
 * @param nut - Connector size
 * @param conductors - Conductors to be joined
 * @returns True when count and fill are within the rating
 */
export function nutFits(nut: NutColor, conductors: readonly Conductor[]): boolean {
  const rating: NutRating = NUT_RATINGS[nut];
  return (
    conductors.length >= 2 &&
    conductors.length <= rating.maxConductors &&
    spliceArea(conductors) <= rating.maxAreaMm2 + 1e-9
  );
}

function isGroundConductor(conductor: Conductor): boolean {
  return conductor.insulation === 'bare' || conductor.insulation === 'green';
}

/**
 * Inspects a finished box the way an inspector would: workmanship first, then the circuit in
 * both switch positions with the breaker on.
 *
 * @param puzzle - Generated round
 * @param state - Splices and markings made by the player
 * @returns Every finding; an empty list means the job passes
 */
export function evaluateWiring(puzzle: WiringPuzzle, state: WiringState): Issue[] {
  const issues: Issue[] = [];
  const byId = new Map(puzzle.conductors.map((c: Conductor): [string, Conductor] => [c.id, c]));
  const spliced = new Set<string>();

  for (const splice of state.splices) {
    const members = splice.conductorIds
      .map((id: string): Conductor | undefined => byId.get(id))
      .filter((c: Conductor | undefined): c is Conductor => c !== undefined);
    for (const member of members) spliced.add(member.id);

    const unstripped = members.filter(
      (c: Conductor): boolean => c.needsStrip && !state.stripped.has(c.id),
    );
    if (unstripped.length > 0) {
      issues.push({ code: 'unstripped', refs: unstripped.map((c: Conductor): string => c.id) });
    }
    if (splice.nut === null) {
      issues.push({ code: 'missing-nut', refs: [splice.id] });
    } else if (!nutFits(splice.nut, members)) {
      issues.push({ code: 'nut-overfilled', refs: [splice.id] });
    }

    const grounds = members.filter(isGroundConductor);
    if (grounds.length > 0 && grounds.length < members.length) {
      issues.push({ code: 'ground-misused', refs: [splice.id] });
    }
  }

  const loose = puzzle.conductors.filter((c: Conductor): boolean => !spliced.has(c.id));
  if (loose.length > 0) {
    issues.push({ code: 'loose-conductor', refs: loose.map((c: Conductor): string => c.id) });
  }

  const off = simulateWiring(puzzle, state, { breakerOn: true, switchOn: false });
  const on = simulateWiring(puzzle, state, { breakerOn: true, switchOn: true });
  if (off.shorted || on.shorted) {
    issues.push({ code: 'short-circuit', refs: [] });
    return issues;
  }

  const nodesOff = buildNodes(puzzle, state, false);
  for (const load of puzzle.loads) {
    const stateOn: LoadState = on.loads.get(load.id) ?? 'off';
    const stateOff: LoadState = off.loads.get(load.id) ?? 'off';

    if (stateOn === 'reversed' || stateOff === 'reversed') {
      issues.push({ code: 'reverse-polarity', refs: [load.id] });
      continue;
    }
    if (load.kind === 'receptacle') {
      if (stateOn !== 'on' || stateOff !== 'on')
        issues.push({ code: 'receptacle-dead', refs: [load.id] });
      continue;
    }
    if (stateOn !== 'on') {
      issues.push({ code: 'fixture-dead', refs: [load.id] });
    } else if (load.switched && stateOff === 'on') {
      issues.push({ code: 'fixture-always-on', refs: [load.id] });
    } else if (nodesOff.same(load.hot, PANEL_HOT)) {
      // Lamp goes dark, but its hot lead stays live: the switch is in the neutral.
      issues.push({ code: 'switched-neutral', refs: [load.id] });
    }
  }

  const groundRefs = puzzle.loads
    .filter((load: Load): boolean => !nodesOff.same(load.ground, PANEL_GROUND))
    .map((load: Load): string => load.id);
  if (!nodesOff.same(BOX_GROUND, PANEL_GROUND)) groundRefs.push('box');
  if (puzzle.wallSwitch && !nodesOff.same('switch.ground', PANEL_GROUND)) groundRefs.push('switch');
  if (groundRefs.length > 0) issues.push({ code: 'ground-open', refs: groundRefs });

  const unmarked = puzzle.conductors.filter(
    (c: Conductor): boolean =>
      c.insulation === 'white' &&
      !c.marked &&
      !state.taped.has(c.id) &&
      (on.energized.has(c.id) || off.energized.has(c.id)),
  );
  if (unmarked.length > 0) {
    issues.push({ code: 'unmarked-white-hot', refs: unmarked.map((c: Conductor): string => c.id) });
  }

  return issues;
}
