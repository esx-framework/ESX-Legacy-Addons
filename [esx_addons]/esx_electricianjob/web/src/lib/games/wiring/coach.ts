/**
 * The next move in a junction box round, for the hint arrow and the numbered wire markers.
 *
 * Works from any state, including a box the player has wired wrong: mixed bundles are taken
 * apart first, then every bundle of the plan is built at a fixed meeting point that all of
 * its conductors can reach, capped with the smallest wire nut that fits and twisted tight.
 * Safety comes first: while there is work left in the box, the first hint is always to switch
 * the breaker off.
 *
 * @see nextMove
 * @see meetingPoints
 */

import { distance, vec, type Vec2 } from '../../core/vec';
import { nutFits } from './electrical';
import type { SpliceRuntime, WiringEngine } from './engine';
import {
  bundleRoleOf,
  connectionPlan,
  whitesToMark,
  type BundleRole,
  type PlanBundle,
} from './guide';
import { SCREW_POSITION, WORK_AREA, type ConductorLayout, type WiringLayout } from './layout';
import { NUT_COLORS, type Conductor, type NutColor, type WiringPuzzle } from './model';

/** A single thing the player should do next. */
export type Move =
  | { kind: 'test'; cableId: string }
  | { kind: 'breaker'; on: boolean }
  | { kind: 'switch' }
  | { kind: 'inspect' }
  | { kind: 'strip'; conductorId: string }
  | { kind: 'tape'; conductorId: string }
  | { kind: 'unnut'; spliceId: string }
  | { kind: 'separate'; conductorId: string; to: Vec2 }
  | { kind: 'place'; conductorId: string; to: Vec2 }
  | { kind: 'join'; conductorId: string; to: Vec2 }
  | { kind: 'nut'; spliceId: string; color: NutColor }
  | { kind: 'twist'; spliceId: string };

/** A splice as the coach sees it. */
export interface CoachSplice {
  /** Splice id */
  id: string;
  /** Joined conductors */
  members: readonly string[];
  /** Where the ends meet */
  point: Vec2;
  /** Wire nut on the bundle */
  nut: NutColor | null;
  /** Whether the nut is twisted tight */
  tight: boolean;
}

/** Everything the coach looks at. */
export interface CoachInput {
  /** The round */
  puzzle: WiringPuzzle;
  /** Static geometry of the round */
  layout: WiringLayout;
  /** Bundle meeting points from {@link meetingPoints} */
  meeting: ReadonlyMap<BundleRole, Vec2>;
  /** Current end position per conductor */
  ends: ReadonlyMap<string, Vec2>;
  /** Breaker position */
  breakerOn: boolean;
  /** The breaker has been switched off at least once */
  everOff: boolean;
  /** The tester has picked up a live conductor at least once */
  testedLive: boolean;
  /** Wall switch position */
  switchOn: boolean;
  /** Conductors the player stripped */
  stripped: ReadonlySet<string>;
  /** Conductors the player re-marked */
  taped: ReadonlySet<string>;
  /** Current splices */
  splices: readonly CoachSplice[];
}

/** How close an end has to be to a meeting point to count as placed there. */
const PLACED_RADIUS = 24;
/** Fraction of a conductor's free length the coach plans new meeting spots with. */
const REACH = 0.82;
/**
 * Fraction it accepts for spots that already exist. Looser than {@link REACH} on purpose:
 * a planned spot must never fail the check for building on it, or the coach would undo its
 * own bundles.
 */
const ACCEPT = 0.87;
const PREFERRED_ANGLE: Readonly<Record<BundleRole, number>> = {
  hot: Math.PI * 1.15,
  switched: Math.PI * 0.32,
  neutral: Math.PI * 0.68,
  ground: Math.PI * 1.7,
};

function layoutsById(layout: WiringLayout): Map<string, ConductorLayout> {
  return new Map(
    layout.conductors.map((c: ConductorLayout): [string, ConductorLayout] => [c.conductorId, c]),
  );
}

function reachable(member: ConductorLayout, point: Vec2, factor = REACH): boolean {
  return distance(member.anchor, point) <= member.length * factor;
}

/** Pulls a point toward every anchor until all members can reach it. */
function pullIntoReach(point: Vec2, members: readonly ConductorLayout[]): Vec2 {
  let result = point;
  for (let pass = 0; pass < 10; pass++) {
    for (const member of members) {
      const span = distance(result, member.anchor);
      const max = member.length * REACH;
      if (span > max) {
        const t = max / span;
        result = vec(
          member.anchor.x + (result.x - member.anchor.x) * t,
          member.anchor.y + (result.y - member.anchor.y) * t,
        );
      }
    }
  }
  return vec(
    Math.min(WORK_AREA.right, Math.max(WORK_AREA.left, result.x)),
    Math.min(WORK_AREA.bottom, Math.max(WORK_AREA.top, result.y)),
  );
}

/**
 * One fixed meeting point per bundle: reachable by all its conductors and as far as possible
 * from the other bundles' points.
 *
 * @param puzzle - The round
 * @param layout - Its geometry
 * @returns Meeting point per bundle role
 */
export function meetingPoints(puzzle: WiringPuzzle, layout: WiringLayout): Map<BundleRole, Vec2> {
  const byId = layoutsById(layout);
  const chosen = new Map<BundleRole, Vec2>();
  for (const bundle of connectionPlan(puzzle)) {
    const members = bundle.conductorIds.map(
      (id: string): ConductorLayout => byId.get(id) as ConductorLayout,
    );
    let best = pullIntoReach(SCREW_POSITION, members);
    let bestScore = -Infinity;
    for (const radius of [80, 120, 160, 200]) {
      for (let k = 0; k < 16; k++) {
        const angle =
          PREFERRED_ANGLE[bundle.role] + (k % 2 === 0 ? 1 : -1) * Math.ceil(k / 2) * 0.4;
        const candidate = pullIntoReach(
          vec(
            SCREW_POSITION.x + Math.cos(angle) * radius,
            SCREW_POSITION.y + Math.sin(angle) * radius,
          ),
          members,
        );
        if (!members.every((member: ConductorLayout): boolean => reachable(member, candidate))) {
          continue;
        }
        let clearance = 260;
        for (const other of chosen.values()) {
          clearance = Math.min(clearance, distance(other, candidate));
        }
        for (const other of layout.conductors) {
          if (bundle.conductorIds.includes(other.conductorId)) continue;
          clearance = Math.min(clearance, distance(other.initialEnd, candidate) * 1.5);
        }
        // Prefer clear spots, then spots close to the preferred direction.
        const score = clearance - k * 3;
        if (score > bestScore) {
          best = candidate;
          bestScore = score;
        }
      }
    }
    chosen.set(bundle.role, best);
  }
  return chosen;
}

/**
 * Number shown on each conductor's marker: conductors with the same number go together.
 *
 * @param puzzle - The round
 * @returns Marker number per conductor, starting at 1 in plan order
 */
export function bundleNumbers(puzzle: WiringPuzzle): Map<string, number> {
  const numbers = new Map<string, number>();
  connectionPlan(puzzle).forEach((bundle: PlanBundle, index: number): void => {
    for (const id of bundle.conductorIds) numbers.set(id, index + 1);
  });
  return numbers;
}

function smallestNut(conductors: readonly Conductor[]): NutColor {
  return NUT_COLORS.find((color: NutColor): boolean => nutFits(color, conductors)) ?? 'red';
}

/** Spot clear of the bundles and of every other wire end where a wrong end can be parked. */
function parkingSpot(member: ConductorLayout, input: CoachInput): Vec2 {
  const obstacles = [
    ...input.meeting.values(),
    ...[...input.ends.entries()]
      .filter(([id]: [string, Vec2]): boolean => id !== member.conductorId)
      .map(([, end]: [string, Vec2]): Vec2 => end),
  ];
  let best = member.anchor;
  let bestClearance = -Infinity;
  for (const t of [0.3, 0.42, 0.54, 0.66, 0.78]) {
    for (const angle of [-1.2, -0.8, -0.4, 0, 0.4, 0.8, 1.2]) {
      const dir = member.direction;
      const cos = Math.cos(angle);
      const sin = Math.sin(angle);
      const reach = member.length * t;
      const spot = vec(
        Math.min(
          WORK_AREA.right,
          Math.max(WORK_AREA.left, member.anchor.x + (dir.x * cos - dir.y * sin) * reach),
        ),
        Math.min(
          WORK_AREA.bottom,
          Math.max(WORK_AREA.top, member.anchor.y + (dir.x * sin + dir.y * cos) * reach),
        ),
      );
      const clearance = Math.min(...obstacles.map((point: Vec2): number => distance(point, spot)));
      if (clearance > bestClearance) {
        best = spot;
        bestClearance = clearance;
      }
    }
  }
  return best;
}

/** How close a foreign wire end may lie to a drop spot before it could get joined by mistake. */
const CROWD_RADIUS = 52;

/**
 * Two loose ends of a bundle where dragging one onto the other starts the bundle at a spot
 * every member can reach and no foreign end lies close by.
 */
function closestPair(
  bundle: PlanBundle,
  input: CoachInput,
  fits: (point: Vec2) => boolean,
): { from: string; onto: Vec2 } | null {
  let best: { from: string; onto: Vec2; length: number } | null = null;
  for (const onto of bundle.conductorIds) {
    const target = input.ends.get(onto);
    if (!target || !fits(target)) continue;
    for (const from of bundle.conductorIds) {
      const start = input.ends.get(from);
      if (from === onto || !start) continue;
      // The drop has to be unambiguous: no other end, of any bundle, near the target.
      const crowded = [...input.ends.entries()].some(
        ([id, end]: [string, Vec2]): boolean =>
          id !== onto && id !== from && distance(end, target) < CROWD_RADIUS,
      );
      if (crowded) continue;
      const length = distance(start, target);
      if (!best || length < best.length) best = { from, onto: target, length };
    }
  }
  return best ? { from: best.from, onto: best.onto } : null;
}

/**
 * The move a helpful foreman would point at next.
 *
 * @param input - Current state of the round
 * @returns Next move; `inspect` once everything is done
 */
export function nextMove(input: CoachInput): Move {
  const work = nextWork(input);
  if (work) {
    if (!input.breakerOn) return work;
    // Like on site: find the live cable first, then kill the power.
    const feed = input.puzzle.cables.find((cable): boolean => cable.role === 'line');
    if (feed && !input.testedLive && !input.everOff) return { kind: 'test', cableId: feed.id };
    return { kind: 'breaker', on: false };
  }
  if (!input.breakerOn) return { kind: 'breaker', on: true };
  if (input.puzzle.wallSwitch && !input.switchOn) return { kind: 'switch' };
  return { kind: 'inspect' };
}

function nextWork(input: CoachInput): Move | null {
  const { puzzle } = input;
  const byId = new Map(puzzle.conductors.map((c: Conductor): [string, Conductor] => [c.id, c]));
  const geometry = layoutsById(input.layout);

  for (const conductor of puzzle.conductors) {
    if (conductor.needsStrip && !input.stripped.has(conductor.id)) {
      return { kind: 'strip', conductorId: conductor.id };
    }
  }
  for (const id of whitesToMark(puzzle)) {
    if (!input.taped.has(id)) return { kind: 'tape', conductorId: id };
  }

  // Take wrong bundles apart before building anything.
  for (const splice of input.splices) {
    const roles = splice.members.map((id: string): BundleRole =>
      bundleRoleOf(byId.get(id) as Conductor),
    );
    const counts = new Map<BundleRole, number>();
    for (const role of roles) counts.set(role, (counts.get(role) ?? 0) + 1);
    if (counts.size <= 1) continue;
    if (splice.nut) return { kind: 'unnut', spliceId: splice.id };
    const majority = [...counts.entries()].sort((a, b): number => b[1] - a[1])[0]?.[0];
    const odd = splice.members.find(
      (id: string): boolean => bundleRoleOf(byId.get(id) as Conductor) !== majority,
    ) as string;
    return {
      kind: 'separate',
      conductorId: odd,
      to: parkingSpot(geometry.get(odd) as ConductorLayout, input),
    };
  }

  const spliceOf = new Map<string, CoachSplice>();
  for (const splice of input.splices) for (const id of splice.members) spliceOf.set(id, splice);

  for (const bundle of connectionPlan(puzzle)) {
    const meeting = input.meeting.get(bundle.role) as Vec2;
    const own = input.splices.filter((splice: CoachSplice): boolean =>
      splice.members.every((id: string): boolean => bundle.conductorIds.includes(id)),
    );
    const complete = own.find(
      (splice: CoachSplice): boolean => splice.members.length === bundle.conductorIds.length,
    );
    if (complete) {
      if (!complete.nut) {
        const members = complete.members.map((id: string): Conductor => byId.get(id) as Conductor);
        return { kind: 'nut', spliceId: complete.id, color: smallestNut(members) };
      }
      if (!complete.tight) return { kind: 'twist', spliceId: complete.id };
      continue;
    }

    // Build where every conductor of the bundle can reach: on an existing bundle if possible,
    // otherwise on one of its own wire ends, and only as a last resort at the meeting point.
    const fits = (point: Vec2): boolean =>
      bundle.conductorIds.every((id: string): boolean =>
        reachable(geometry.get(id) as ConductorLayout, point, ACCEPT),
      );
    // A bundle right next to a foreign one would swallow the next wire dropped on it.
    const foreign = [
      ...input.splices
        .filter((splice: CoachSplice): boolean => !own.includes(splice))
        .map((splice: CoachSplice): Vec2 => splice.point),
      ...[...input.ends.entries()]
        .filter(
          ([id]: [string, Vec2]): boolean => !bundle.conductorIds.includes(id) && !spliceOf.has(id),
        )
        .map(([, end]: [string, Vec2]): Vec2 => end),
    ];
    const clear = (point: Vec2): boolean =>
      foreign.every((other: Vec2): boolean => distance(other, point) >= CROWD_RADIUS);
    const home = [...own]
      .sort((a: CoachSplice, b: CoachSplice): number => b.members.length - a.members.length)
      .find((splice: CoachSplice): boolean => fits(splice.point) && clear(splice.point));
    if (home?.nut) return { kind: 'unnut', spliceId: home.id };
    for (const splice of own) {
      if (splice !== home && splice.nut) return { kind: 'unnut', spliceId: splice.id };
    }
    if (home) {
      const next = bundle.conductorIds.find((id: string): boolean => spliceOf.get(id) !== home);
      return { kind: 'join', conductorId: next as string, to: home.point };
    }
    const stuck = own[0];
    if (stuck) {
      const member = stuck.members[0] as string;
      return {
        kind: 'separate',
        conductorId: member,
        to: parkingSpot(geometry.get(member) as ConductorLayout, input),
      };
    }

    const pair = closestPair(bundle, input, fits);
    if (pair) return { kind: 'join', conductorId: pair.from, to: pair.onto };

    const placed = bundle.conductorIds.find((id: string): boolean => {
      const end = input.ends.get(id);
      return end !== undefined && distance(end, meeting) <= PLACED_RADIUS;
    });
    if (placed) {
      const next = bundle.conductorIds.find((id: string): boolean => id !== placed) as string;
      return { kind: 'join', conductorId: next, to: input.ends.get(placed) as Vec2 };
    }
    return { kind: 'place', conductorId: bundle.conductorIds[0] as string, to: meeting };
  }
  return null;
}

/**
 * Reads the coach input off a running engine.
 *
 * @param engine - Running round
 * @param meeting - Bundle meeting points from {@link meetingPoints}
 * @returns Snapshot for {@link nextMove}
 */
export function coachInputFrom(
  engine: WiringEngine,
  meeting: ReadonlyMap<BundleRole, Vec2>,
): CoachInput {
  const ends = new Map<string, Vec2>();
  for (const runtime of engine.conductors) ends.set(runtime.conductor.id, runtime.end);
  return {
    puzzle: engine.puzzle,
    layout: engine.layout,
    meeting,
    ends,
    breakerOn: engine.breakerOn,
    everOff: engine.everOff,
    testedLive: engine.testedLive,
    switchOn: engine.switchOn,
    stripped: engine.stripped,
    taped: engine.taped,
    splices: [...engine.splices.values()].map((splice: SpliceRuntime): CoachSplice => ({
      id: splice.id,
      members: splice.members,
      point: splice.point,
      nut: splice.nut,
      tight: splice.nut !== null && splice.twist >= 1,
    })),
  };
}
