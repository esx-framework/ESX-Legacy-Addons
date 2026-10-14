/**
 * Tests for connector ratings, circuit simulation and inspection rules.
 */

import { describe, expect, it } from 'vitest';
import { evaluateWiring, nutFits, simulateWiring, type IssueCode } from './electrical';
import { generateWiringPuzzle } from './generator';
import type { Conductor, Splice, WiringPuzzle, WiringState } from './model';
import { solveWiring } from './test-solver';

function findPuzzle(predicate: (puzzle: WiringPuzzle) => boolean): WiringPuzzle {
  for (let seed = 0; seed < 5000; seed++) {
    for (const difficulty of [1, 2, 3] as const) {
      const puzzle = generateWiringPuzzle(seed, difficulty);
      if (predicate(puzzle)) return puzzle;
    }
  }
  throw new Error('no matching puzzle in the first 5000 seeds');
}

function conductor(awg: Conductor['awg'], id = `w${awg}`): Conductor {
  return {
    id,
    cableId: 'c',
    insulation: 'black',
    awg,
    stranded: false,
    terminal: 'x',
    marked: false,
    needsStrip: false,
  };
}

function codes(puzzle: WiringPuzzle, state: WiringState): IssueCode[] {
  return evaluateWiring(puzzle, state).map((issue): IssueCode => issue.code);
}

/** Moves conductors between splices of a correct solution to break it on purpose. */
function rewire(state: WiringState, moves: Record<string, string>): WiringState {
  const splices: Splice[] = state.splices.map((splice: Splice): Splice => ({
    ...splice,
    conductorIds: splice.conductorIds.filter((id: string): boolean => !(id in moves)),
  }));
  for (const [id, target] of Object.entries(moves)) {
    const splice = splices.find((s: Splice): boolean => s.id === target);
    if (!splice) throw new Error(`no splice ${target}`);
    splices[splices.indexOf(splice)] = {
      ...splice,
      conductorIds: [...splice.conductorIds, id],
      nut: 'red',
    };
  }
  return { ...state, splices };
}

const threeWireLight = findPuzzle(
  (p: WiringPuzzle): boolean =>
    p.template === 'switched-light' && p.switchLoop === 'three-wire' && p.breakerAmps === 15,
);
const unmarkedLoop = findPuzzle((p: WiringPuzzle): boolean => p.switchLoop === 'two-wire-unmarked');

function idOf(puzzle: WiringPuzzle, terminal: string): string {
  const match = puzzle.conductors.find((c: Conductor): boolean => c.terminal === terminal);
  if (!match) throw new Error(`no conductor lands on ${terminal}`);
  return match.id;
}

describe('nutFits', () => {
  it('should follow the tray card ratings', () => {
    expect(nutFits('orange', [conductor(14, 'a'), conductor(14, 'b')])).toBe(true);
    expect(nutFits('orange', [conductor(14, 'a'), conductor(14, 'b'), conductor(14, 'c')])).toBe(
      false,
    );
    expect(nutFits('yellow', [conductor(12, 'a'), conductor(12, 'b'), conductor(12, 'c')])).toBe(
      true,
    );
    expect(
      nutFits('yellow', [
        conductor(14, 'a'),
        conductor(14, 'b'),
        conductor(14, 'c'),
        conductor(14, 'd'),
      ]),
    ).toBe(true);
    expect(
      nutFits('yellow', [
        conductor(12, 'a'),
        conductor(12, 'b'),
        conductor(12, 'c'),
        conductor(12, 'd'),
      ]),
    ).toBe(false);
    expect(
      nutFits('red', [
        conductor(12, 'a'),
        conductor(12, 'b'),
        conductor(12, 'c'),
        conductor(12, 'd'),
      ]),
    ).toBe(true);
    expect(
      nutFits(
        'red',
        Array.from({ length: 6 }, (_: unknown, i: number): Conductor => conductor(14, `n${i}`)),
      ),
    ).toBe(false);
  });

  it('should reject a single conductor', () => {
    expect(nutFits('orange', [conductor(14)])).toBe(false);
  });
});

describe('simulateWiring', () => {
  const solved = solveWiring(threeWireLight);

  it('should light the fixture only with the switch on', () => {
    expect(
      simulateWiring(threeWireLight, solved, { breakerOn: true, switchOn: true }).loads.get(
        'fixture',
      ),
    ).toBe('on');
    expect(
      simulateWiring(threeWireLight, solved, { breakerOn: true, switchOn: false }).loads.get(
        'fixture',
      ),
    ).toBe('off');
  });

  it('should leave everything dead with the breaker off', () => {
    const run = simulateWiring(threeWireLight, solved, { breakerOn: false, switchOn: true });
    expect(run.energized.size).toBe(0);
    expect(run.loads.get('fixture')).toBe('off');
  });

  it('should energize the feed even before anything is spliced', () => {
    const run = simulateWiring(
      threeWireLight,
      { splices: [], stripped: new Set(), taped: new Set() },
      {
        breakerOn: true,
        switchOn: false,
      },
    );
    expect([...run.energized]).toEqual([idOf(threeWireLight, 'panel.hot')]);
  });

  it('should report a short when hot meets neutral', () => {
    const shorted = rewire(solved, { [idOf(threeWireLight, 'panel.hot')]: 'neutral' });
    expect(
      simulateWiring(threeWireLight, shorted, { breakerOn: true, switchOn: false }).shorted,
    ).toBe(true);
  });
});

describe('evaluateWiring', () => {
  it('should pass a correct box', () => {
    expect(codes(threeWireLight, solveWiring(threeWireLight))).toEqual([]);
  });

  it('should flag a fixture that ignores the switch', () => {
    const state = rewire(solveWiring(threeWireLight), {
      [idOf(threeWireLight, 'fixture.hot')]: 'hot',
    });
    expect(codes(threeWireLight, state)).toContain('fixture-always-on');
  });

  it('should flag a switched neutral', () => {
    // Lamp hot straight to the feed, the switch sits between lamp neutral and the neutrals.
    const state = rewire(solveWiring(threeWireLight), {
      [idOf(threeWireLight, 'fixture.hot')]: 'hot',
      [idOf(threeWireLight, 'fixture.neutral')]: 'switched',
      [idOf(threeWireLight, 'switch.a')]: 'neutral',
    });
    expect(codes(threeWireLight, state)).toContain('switched-neutral');
  });

  it('should flag reversed polarity at the lamp', () => {
    const state = rewire(solveWiring(threeWireLight), {
      [idOf(threeWireLight, 'fixture.hot')]: 'neutral',
      [idOf(threeWireLight, 'fixture.neutral')]: 'switched',
    });
    expect(codes(threeWireLight, state)).toContain('reverse-polarity');
  });

  it('should flag a short circuit', () => {
    const state = rewire(solveWiring(threeWireLight), {
      [idOf(threeWireLight, 'panel.hot')]: 'neutral',
    });
    expect(codes(threeWireLight, state)).toContain('short-circuit');
  });

  it('should flag splices without a connector and leave them open', () => {
    const solved = solveWiring(threeWireLight);
    const state: WiringState = {
      ...solved,
      splices: solved.splices.map((s: Splice): Splice =>
        s.id === 'switched' ? { ...s, nut: null } : s,
      ),
    };
    expect(codes(threeWireLight, state)).toEqual(
      expect.arrayContaining(['missing-nut', 'fixture-dead']),
    );
  });

  it('should flag an overfilled connector', () => {
    const solved = solveWiring(threeWireLight);
    const state: WiringState = {
      ...solved,
      splices: solved.splices.map((s: Splice): Splice =>
        s.id === 'ground' ? { ...s, nut: 'orange' } : s,
      ),
    };
    expect(codes(threeWireLight, state)).toContain('nut-overfilled');
  });

  it('should flag a loose conductor', () => {
    const solved = solveWiring(threeWireLight);
    const state: WiringState = {
      ...solved,
      splices: solved.splices.filter((s: Splice): boolean => s.id !== 'ground'),
    };
    expect(codes(threeWireLight, state)).toEqual(
      expect.arrayContaining(['loose-conductor', 'ground-open']),
    );
  });

  it('should flag ground conductors spliced with neutrals', () => {
    const state = rewire(solveWiring(threeWireLight), {
      [idOf(threeWireLight, 'panel.ground')]: 'neutral',
    });
    expect(codes(threeWireLight, state)).toContain('ground-misused');
  });

  it('should require the white of a 2-wire loop to be re-marked', () => {
    const solved = solveWiring(unmarkedLoop);
    expect(codes(unmarkedLoop, solved)).toEqual([]);
    expect(codes(unmarkedLoop, { ...solved, taped: new Set() })).toContain('unmarked-white-hot');
  });

  it('should require damaged ends to be stripped', () => {
    const damaged = findPuzzle((p: WiringPuzzle): boolean =>
      p.conductors.some((c: Conductor): boolean => c.needsStrip),
    );
    const solved = solveWiring(damaged);
    expect(codes(damaged, { ...solved, stripped: new Set() })).toContain('unstripped');
  });
});
