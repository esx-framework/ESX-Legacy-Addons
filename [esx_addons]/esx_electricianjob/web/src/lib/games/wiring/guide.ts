/**
 * Player guidance for the junction box: which conductors belong together, how to describe
 * cables to someone who is not an electrician, and the step checklist shown in the HUD.
 *
 * The connection plan is derived from where conductors land, the same way an electrician
 * reads a box. Lower tiers show it to the player; higher tiers only show the rules.
 *
 * @see connectionPlan
 * @see checklist
 */

import type { Cable, CableRole, Conductor, WiringPuzzle } from './model';

/** Electrical job of a bundle in a correctly wired box. */
export type BundleRole = 'hot' | 'switched' | 'neutral' | 'ground';

/** Bundles in the order the plan lists them. */
export const BUNDLE_ORDER: readonly BundleRole[] = ['hot', 'switched', 'neutral', 'ground'];

/** One bundle a correct solution needs. */
export interface PlanBundle {
  /** What the bundle does */
  role: BundleRole;
  /** Conductors that go into it */
  conductorIds: readonly string[];
}

/** Checklist entry ids, in the order a job is done. */
export type StepId =
  'test' | 'power-off' | 'strip' | 'mark' | 'bundle' | 'cap' | 'power-on' | 'switch' | 'inspect';

/** One line of the checklist. */
export interface ChecklistStep {
  /** Step id, also the key of its text */
  id: StepId;
  /** Whether the step is done */
  done: boolean;
  /** Done and total count for countable steps */
  progress: readonly [number, number] | null;
}

/** Everything the checklist looks at. */
export interface ChecklistInput {
  /** The round */
  puzzle: WiringPuzzle;
  /** The tester has picked up a live conductor at least once */
  testedLive: boolean;
  /** The breaker has been switched off at least once */
  everOff: boolean;
  /** Breaker position now */
  breakerOn: boolean;
  /** The ceiling light has been seen burning since the last change */
  lightSeen: boolean;
  /** Conductors the player stripped */
  stripped: ReadonlySet<string>;
  /** Conductors the player re-marked */
  taped: ReadonlySet<string>;
  /** Splices with their members and whether the nut is tight */
  splices: readonly { members: readonly string[]; tight: boolean }[];
}

/**
 * Bundle a conductor belongs to, read from where its far end lands.
 *
 * @param conductor - Conductor of the round
 * @returns Its bundle role
 */
export function bundleRoleOf(conductor: Conductor): BundleRole {
  if (conductor.insulation === 'bare' || conductor.insulation === 'green') return 'ground';
  const terminal = conductor.terminal;
  if (terminal === 'switch.b' || terminal === 'fixture.hot') return 'switched';
  if (terminal === 'switch.a' || terminal.endsWith('.hot')) return 'hot';
  return 'neutral';
}

/**
 * The bundles a correct box has.
 *
 * @param puzzle - The round
 * @returns Non-empty bundles in {@link BUNDLE_ORDER}
 */
export function connectionPlan(puzzle: WiringPuzzle): PlanBundle[] {
  const groups = new Map<BundleRole, string[]>();
  for (const conductor of puzzle.conductors) {
    const role = bundleRoleOf(conductor);
    groups.set(role, [...(groups.get(role) ?? []), conductor.id]);
  }
  return BUNDLE_ORDER.filter((role: BundleRole): boolean => groups.has(role)).map(
    (role: BundleRole): PlanBundle => ({ role, conductorIds: groups.get(role) ?? [] }),
  );
}

/**
 * Whites that have to be re-marked with tape before the job passes.
 *
 * @param puzzle - The round
 * @returns Conductor ids
 */
export function whitesToMark(puzzle: WiringPuzzle): string[] {
  return puzzle.conductors
    .filter((c: Conductor): boolean => {
      const role = bundleRoleOf(c);
      return c.insulation === 'white' && !c.marked && (role === 'hot' || role === 'switched');
    })
    .map((c: Conductor): string => c.id);
}

/**
 * Short label of a cable as the player sees it in the box.
 *
 * @param cable - Cable of the round
 * @returns Tape flag text, `LIGHT` for fixture leads, `SCREW` for the bonding jumper, or null
 *   for a cable without a flag
 */
export function cableLabel(cable: Cable): string | null {
  if (cable.role === 'fixture') return 'LIGHT';
  if (cable.role === 'pigtail') return 'SCREW';
  return cable.tag;
}

/** Plain-language description of where each kind of cable goes. */
export const CABLE_ROLE_TEXT: Readonly<Record<CableRole, string>> = {
  line: 'power from the panel',
  switch: 'goes to the wall switch',
  fixture: 'leads of the ceiling light',
  receptacle: 'feeds the outlets downstream',
};

/**
 * Checklist of the job with what is already done.
 *
 * @param input - Current state of the round
 * @returns Steps in order; steps that do not apply to this round are left out
 */
export function checklist(input: ChecklistInput): ChecklistStep[] {
  const { puzzle } = input;
  const steps: ChecklistStep[] = [];
  const step = (
    id: StepId,
    done: boolean,
    progress: readonly [number, number] | null = null,
  ): void => {
    steps.push({ id, done, progress });
  };

  // Once the power is off there is nothing left to find with the tester.
  step('test', input.testedLive || input.everOff);
  step('power-off', input.everOff);

  const damaged = puzzle.conductors.filter((c: Conductor): boolean => c.needsStrip);
  if (damaged.length > 0) {
    const fixed = damaged.filter((c: Conductor): boolean => input.stripped.has(c.id)).length;
    step('strip', fixed === damaged.length, [fixed, damaged.length]);
  }

  const marks = whitesToMark(puzzle);
  if (marks.length > 0) {
    const done = marks.filter((id: string): boolean => input.taped.has(id)).length;
    step('mark', done === marks.length, [done, marks.length]);
  }

  const total = puzzle.conductors.length;
  const bundled = input.splices.reduce((sum: number, s): number => sum + s.members.length, 0);
  step('bundle', bundled === total, [bundled, total]);

  const tight = input.splices.filter((s): boolean => s.tight).length;
  const capped = input.splices.length > 0 && tight === input.splices.length && bundled === total;
  // Count against the bundles the job needs, so the line never starts at 0/0.
  const needed = Math.max(connectionPlan(puzzle).length, input.splices.length);
  step('cap', capped, [tight, needed]);

  step('power-on', capped && input.breakerOn);
  if (puzzle.wallSwitch) step('switch', capped && input.breakerOn && input.lightSeen);
  step('inspect', false);
  return steps;
}
