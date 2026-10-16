/**
 * The hint system has to lead any player to a passed inspection: a player who does nothing
 * but follow the hint arrow, starting from a fresh box or from one wired wrong.
 */

import { describe, expect, it } from 'vitest';
import type { Difficulty } from '../../nui/messages';
import { vec, type Vec2 } from '../../core/vec';
import { bundleNumbers, coachInputFrom, meetingPoints, nextMove, type Move } from './coach';
import { WiringEngine, nutCenter, type ConductorRuntime, type SpliceRuntime } from './engine';
import { generateWiringPuzzle } from './generator';
import { connectionPlan } from './guide';
import { computeWiringLayout } from './layout';
import { TRAY_AREAS } from './scene/tray';

function center(area: { x: number; y: number; width: number; height: number }): Vec2 {
  return vec(area.x + area.width / 2, area.y + area.height / 2);
}

function drag(engine: WiringEngine, from: Vec2, to: Vec2): void {
  engine.pointerDown(from, 0);
  for (let i = 1; i <= 8; i++) {
    engine.pointerMove(vec(from.x + ((to.x - from.x) * i) / 8, from.y + ((to.y - from.y) * i) / 8));
  }
  engine.pointerUp(to);
}

function splice(engine: WiringEngine, id: string): SpliceRuntime {
  const found = engine.splices.get(id);
  if (!found) throw new Error(`no splice ${id}`);
  return found;
}

function perform(engine: WiringEngine, move: Move): void {
  switch (move.kind) {
    case 'test': {
      const cable = engine.layout.cables.find((c): boolean => c.cableId === move.cableId);
      if (!cable?.entry) throw new Error(`no jacket for ${move.cableId}`);
      const mid = vec(
        (cable.entry.x + cable.sheathEnd.x) / 2,
        (cable.entry.y + cable.sheathEnd.y) / 2,
      );
      drag(engine, center(TRAY_AREAS.tools.tester), mid);
      break;
    }
    case 'breaker':
      if (engine.breakerOn !== move.on) engine.toggleBreaker();
      break;
    case 'switch':
      engine.toggleSwitch();
      break;
    case 'strip': {
      drag(engine, center(TRAY_AREAS.tools.stripper), engine.conductor(move.conductorId).end);
      engine.strip(move.conductorId, engine.conductor(move.conductorId).conductor.awg);
      break;
    }
    case 'tape':
      drag(engine, center(TRAY_AREAS.tools.tape), engine.conductor(move.conductorId).end);
      break;
    case 'unnut':
      engine.pointerDown(nutCenter(splice(engine, move.spliceId)), 2);
      break;
    case 'separate':
    case 'place':
      drag(engine, engine.conductor(move.conductorId).end, move.to);
      break;
    case 'join':
      drag(engine, engine.conductor(move.conductorId).end, vec(move.to.x + 2, move.to.y + 2));
      break;
    case 'nut':
      drag(engine, center(TRAY_AREAS.nuts[move.color]), splice(engine, move.spliceId).point);
      break;
    case 'twist': {
      const point = splice(engine, move.spliceId).point;
      engine.pointerDown(point, 0);
      for (let step = 0; step <= 64; step++) {
        const angle = (step / 28) * Math.PI * 2;
        engine.pointerMove(vec(point.x + Math.cos(angle) * 54, point.y + Math.sin(angle) * 54));
      }
      engine.pointerUp(point);
      break;
    }
    case 'inspect':
    default:
      break;
  }
}

function followHints(engine: WiringEngine): number {
  const meeting = meetingPoints(engine.puzzle, engine.layout);
  const trail: string[] = [];
  for (let count = 0; count < 120; count++) {
    const move = nextMove(coachInputFrom(engine, meeting));
    if (move.kind === 'inspect') return count;
    trail.push(JSON.stringify(move));
    perform(engine, move);
  }
  throw new Error(
    `hints did not lead to a finished box (seed ${engine.puzzle.seed}): ${trail.slice(-4).join(' | ')}`,
  );
}

function newEngine(seed: number, difficulty: Difficulty): WiringEngine {
  const puzzle = generateWiringPuzzle(seed, difficulty);
  return new WiringEngine(puzzle, computeWiringLayout(puzzle), TRAY_AREAS, (): void => undefined);
}

const SEEDS = Array.from({ length: 150 }, (_: unknown, i: number): number => (i * 7919 + 31) >>> 0);

describe('nextMove', () => {
  it.each([1, 2, 3] as const)(
    'should lead a fresh box to a pass on difficulty %i',
    (difficulty: Difficulty) => {
      for (const seed of SEEDS) {
        const engine = newEngine(seed, difficulty);
        followHints(engine);
        expect(engine.inspect(), `seed ${seed}`).toEqual([]);
        expect(engine.mistakes, `seed ${seed}`).toBe(0);
      }
    },
  );

  it('should repair a box that was bundled at random first', () => {
    for (const seed of SEEDS.slice(0, 60)) {
      const engine = newEngine(seed, 2);
      engine.toggleBreaker();
      // Wrong on purpose: neighbours in conductor order end up in the same bundle.
      const [a, b, c] = engine.conductors as [ConductorRuntime, ConductorRuntime, ConductorRuntime];
      drag(engine, b.end, vec(a.end.x + 3, a.end.y + 2));
      const wrong = [...engine.splices.values()][0];
      if (wrong) {
        drag(engine, c.end, vec(wrong.point.x + 2, wrong.point.y + 2));
        drag(engine, center(TRAY_AREAS.nuts.red), wrong.point);
      }
      followHints(engine);
      expect(engine.inspect(), `seed ${seed}`).toEqual([]);
    }
  });

  it('should send the player to the tester, then to the breaker, before any work', () => {
    const engine = newEngine(1056, 1);
    const meeting = meetingPoints(engine.puzzle, engine.layout);
    const first = nextMove(coachInputFrom(engine, meeting));
    expect(first.kind).toBe('test');
    perform(engine, first);
    expect(engine.testedLive).toBe(true);
    expect(nextMove(coachInputFrom(engine, meeting))).toEqual({ kind: 'breaker', on: false });
  });

  it('should prefer dragging a wire onto another wire over an empty spot', () => {
    let joins = 0;
    let places = 0;
    for (const seed of SEEDS.slice(0, 60)) {
      const engine = newEngine(seed, 1);
      const meeting = meetingPoints(engine.puzzle, engine.layout);
      for (let i = 0; i < 80; i++) {
        const move = nextMove(coachInputFrom(engine, meeting));
        if (move.kind === 'inspect') break;
        if (move.kind === 'join') joins += 1;
        if (move.kind === 'place') places += 1;
        perform(engine, move);
      }
    }
    expect(places / (joins + places)).toBeLessThan(0.15);
  });
});

describe('bundleNumbers', () => {
  it('should give every conductor of a bundle the same number', () => {
    const puzzle = generateWiringPuzzle(1056, 3);
    const numbers = bundleNumbers(puzzle);
    connectionPlan(puzzle).forEach((bundle, index: number): void => {
      for (const id of bundle.conductorIds) expect(numbers.get(id)).toBe(index + 1);
    });
  });
});
