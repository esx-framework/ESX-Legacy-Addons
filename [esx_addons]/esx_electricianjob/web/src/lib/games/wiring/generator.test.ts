/**
 * Tests for the junction box generator: determinism, structure and solvability.
 */

import { describe, expect, it } from 'vitest';
import type { Difficulty } from '../../nui/messages';
import { evaluateWiring } from './electrical';
import { generateWiringPuzzle } from './generator';
import type { Cable, Conductor } from './model';
import { solveWiring } from './test-solver';

const DIFFICULTIES: readonly Difficulty[] = [1, 2, 3];
const SEEDS = Array.from(
  { length: 1500 },
  (_: unknown, i: number): number => (i * 2654435761) >>> 0,
);

describe('generateWiringPuzzle', () => {
  it('should return the same round for the same seed and difficulty', () => {
    expect(generateWiringPuzzle(777, 2)).toEqual(generateWiringPuzzle(777, 2));
  });

  it('should vary the round between seeds', () => {
    const shapes = new Set(
      SEEDS.slice(0, 200).map((seed: number): string => {
        const puzzle = generateWiringPuzzle(seed, 2);
        return JSON.stringify(
          puzzle.cables.map((c: Cable): [string, string | null] => [c.role, c.tag]),
        );
      }),
    );
    expect(shapes.size).toBeGreaterThan(40);
  });

  it.each(DIFFICULTIES)(
    'should only produce solvable rounds on difficulty %i',
    (difficulty: Difficulty) => {
      for (const seed of SEEDS) {
        const puzzle = generateWiringPuzzle(seed, difficulty);
        expect(evaluateWiring(puzzle, solveWiring(puzzle)), `seed ${seed}`).toEqual([]);
      }
    },
  );

  it.each(DIFFICULTIES)(
    'should keep ids unique and consistent on difficulty %i',
    (difficulty: Difficulty) => {
      for (const seed of SEEDS.slice(0, 300)) {
        const puzzle = generateWiringPuzzle(seed, difficulty);
        const ids = puzzle.conductors.map((c: Conductor): string => c.id);
        expect(new Set(ids).size).toBe(ids.length);
        for (const cable of puzzle.cables) {
          for (const id of cable.conductorIds) expect(ids).toContain(id);
        }
      }
    },
  );

  it('should keep the first tier free of damaged ends and missing tags', () => {
    for (const seed of SEEDS) {
      const puzzle = generateWiringPuzzle(seed, 1);
      expect(puzzle.conductors.some((c: Conductor): boolean => c.needsStrip)).toBe(false);
      const untagged = puzzle.cables.filter(
        (c: Cable): boolean => c.tag === null && c.role !== 'fixture' && c.role !== 'pigtail',
      );
      expect(untagged).toEqual([]);
    }
  });

  it('should never leave two indistinguishable cables without tags', () => {
    for (const difficulty of DIFFICULTIES) {
      for (const seed of SEEDS) {
        const puzzle = generateWiringPuzzle(seed, difficulty);
        const byId = new Map(
          puzzle.conductors.map((c: Conductor): [string, Conductor] => [c.id, c]),
        );
        const plainUntagged = puzzle.cables.filter((cable: Cable): boolean => {
          if (
            cable.tag !== null ||
            cable.role === 'line' ||
            cable.role === 'fixture' ||
            cable.role === 'pigtail'
          ) {
            return false;
          }
          return !cable.conductorIds.some((id: string): boolean => {
            const conductor = byId.get(id);
            return conductor?.insulation === 'red' || conductor?.marked === true;
          });
        });
        expect(plainUntagged.length, `seed ${seed} difficulty ${difficulty}`).toBeLessThanOrEqual(
          1,
        );
      }
    }
  });

  it('should use every scenario on the middle tier', () => {
    const templates = new Set(
      SEEDS.map((seed: number): string => generateWiringPuzzle(seed, 2).template),
    );
    expect([...templates].sort()).toEqual([
      'splice-through',
      'switched-light',
      'switched-light-feed-through',
    ]);
  });

  it('should match sheath color to wire gauge', () => {
    for (const seed of SEEDS.slice(0, 300)) {
      for (const cable of generateWiringPuzzle(seed, 3).cables) {
        if (cable.role === 'fixture' || cable.role === 'pigtail') continue;
        expect(cable.sheath).toBe(cable.awg === 14 ? 'white' : 'yellow');
      }
    }
  });
});
