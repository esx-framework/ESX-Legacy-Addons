/**
 * Tests for the connection plan and the job checklist.
 */

import { describe, expect, it } from 'vitest';
import { generateWiringPuzzle } from './generator';
import { cableLabel, checklist, connectionPlan, type ChecklistInput, type StepId } from './guide';
import type { Cable, WiringPuzzle } from './model';

function findPuzzle(predicate: (puzzle: WiringPuzzle) => boolean): WiringPuzzle {
  for (let seed = 0; seed < 5000; seed++) {
    for (const difficulty of [1, 2, 3] as const) {
      const puzzle = generateWiringPuzzle(seed, difficulty);
      if (predicate(puzzle)) return puzzle;
    }
  }
  throw new Error('no matching puzzle');
}

function input(puzzle: WiringPuzzle, overrides: Partial<ChecklistInput> = {}): ChecklistInput {
  return {
    puzzle,
    testedLive: false,
    everOff: false,
    breakerOn: true,
    lightSeen: false,
    stripped: new Set(),
    taped: new Set(),
    splices: [],
    ...overrides,
  };
}

function ids(steps: ReturnType<typeof checklist>): StepId[] {
  return steps.map((step): StepId => step.id);
}

describe('connectionPlan', () => {
  it('should put every conductor into exactly one bundle', () => {
    for (let seed = 0; seed < 300; seed++) {
      const puzzle = generateWiringPuzzle(seed, 3);
      const planned = connectionPlan(puzzle).flatMap((bundle) => bundle.conductorIds);
      expect([...planned].sort()).toEqual(puzzle.conductors.map((c) => c.id).sort());
    }
  });

  it('should route the switch return to the light on a 3-wire loop', () => {
    const puzzle = findPuzzle((p: WiringPuzzle): boolean => p.switchLoop === 'three-wire');
    const switched = connectionPlan(puzzle).find((bundle) => bundle.role === 'switched');
    const terminals = switched?.conductorIds.map(
      (id: string): string => puzzle.conductors.find((c) => c.id === id)?.terminal ?? '',
    );
    expect(terminals?.sort()).toEqual(['fixture.hot', 'switch.b']);
  });
});

describe('cableLabel', () => {
  it('should name fixture leads and the bonding jumper', () => {
    const puzzle = findPuzzle((p: WiringPuzzle): boolean => p.wallSwitch !== null);
    const labels = puzzle.cables.map((cable: Cable): string | null => cableLabel(cable));
    expect(labels).toContain('LIGHT');
    expect(labels).toContain('SCREW');
  });
});

describe('checklist', () => {
  it('should only list strip and mark steps when the round needs them', () => {
    const plain = findPuzzle(
      (p: WiringPuzzle): boolean => p.difficulty === 1 && p.template === 'splice-through',
    );
    expect(ids(checklist(input(plain)))).toEqual([
      'test',
      'power-off',
      'bundle',
      'cap',
      'power-on',
      'inspect',
    ]);

    const hard = findPuzzle(
      (p: WiringPuzzle): boolean =>
        p.switchLoop === 'two-wire-unmarked' && p.conductors.some((c) => c.needsStrip),
    );
    expect(ids(checklist(input(hard)))).toEqual([
      'test',
      'power-off',
      'strip',
      'mark',
      'bundle',
      'cap',
      'power-on',
      'switch',
      'inspect',
    ]);
  });

  it('should count bundled conductors and tight nuts', () => {
    const puzzle = findPuzzle((p: WiringPuzzle): boolean => p.template === 'splice-through');
    const [first, second] = puzzle.conductors;
    const steps = checklist(
      input(puzzle, { splices: [{ members: [first?.id ?? '', second?.id ?? ''], tight: true }] }),
    );
    expect(steps.find((step) => step.id === 'bundle')?.progress).toEqual([
      2,
      puzzle.conductors.length,
    ]);
    const cap = steps.find((step) => step.id === 'cap');
    expect(cap?.done).toBe(false);
    expect(cap?.progress).toEqual([1, connectionPlan(puzzle).length]);
  });

  it('should only tick power-on after every bundle is capped', () => {
    const puzzle = findPuzzle((p: WiringPuzzle): boolean => p.template === 'splice-through');
    const all = puzzle.conductors.map((c) => c.id);
    const open = checklist(input(puzzle, { splices: [{ members: all, tight: false }] }));
    expect(open.find((step) => step.id === 'power-on')?.done).toBe(false);
    const capped = checklist(input(puzzle, { splices: [{ members: all, tight: true }] }));
    expect(capped.find((step) => step.id === 'power-on')?.done).toBe(true);
  });
});
