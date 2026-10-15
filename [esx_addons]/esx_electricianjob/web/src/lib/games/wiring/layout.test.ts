/**
 * Tests for the junction box layout: determinism and, above all, that the conductors of every
 * splice a correct solution needs can actually be brought together.
 */

import { describe, expect, it } from 'vitest';
import type { Difficulty } from '../../nui/messages';
import { distance, vec, type Vec2 } from '../../core/vec';
import { generateWiringPuzzle } from './generator';
import { BOX_INNER, computeWiringLayout, WORK_AREA, type ConductorLayout } from './layout';
import { solveWiring } from './test-solver';

const DIFFICULTIES: readonly Difficulty[] = [1, 2, 3];
const SEEDS = Array.from(
  { length: 800 },
  (_: unknown, i: number): number => (i * 40503 + 17) >>> 0,
);

/** Pulls a point toward every anchor until all conductors could reach it with some slack. */
function meetingPoint(members: readonly ConductorLayout[]): Vec2 {
  let x = 0;
  let y = 0;
  for (const member of members) {
    x += member.anchor.x;
    y += member.anchor.y;
  }
  let point = vec(x / members.length, y / members.length);
  for (let pass = 0; pass < 40; pass++) {
    for (const member of members) {
      const span = distance(point, member.anchor);
      const max = member.length * 0.8;
      if (span > max) {
        const t = max / span;
        point = vec(
          member.anchor.x + (point.x - member.anchor.x) * t,
          member.anchor.y + (point.y - member.anchor.y) * t,
        );
      }
    }
  }
  return point;
}

describe('computeWiringLayout', () => {
  it('should lay out a seed identically every time', () => {
    const puzzle = generateWiringPuzzle(4242, 3);
    expect(computeWiringLayout(puzzle)).toEqual(computeWiringLayout(puzzle));
  });

  it.each(DIFFICULTIES)(
    'should let every required splice come together on difficulty %i',
    (difficulty: Difficulty) => {
      for (const seed of SEEDS) {
        const puzzle = generateWiringPuzzle(seed, difficulty);
        const layout = computeWiringLayout(puzzle);
        const byId = new Map(
          layout.conductors.map((c): [string, ConductorLayout] => [c.conductorId, c]),
        );

        for (const splice of solveWiring(puzzle).splices) {
          const members = splice.conductorIds.map(
            (id: string): ConductorLayout => byId.get(id) as ConductorLayout,
          );
          const point = meetingPoint(members);
          for (const member of members) {
            expect(
              distance(point, member.anchor),
              `seed ${seed} splice ${splice.id} ${member.conductorId}`,
            ).toBeLessThanOrEqual(member.length * 0.85);
          }
          expect(point.x).toBeGreaterThanOrEqual(WORK_AREA.left);
          expect(point.x).toBeLessThanOrEqual(WORK_AREA.right);
          expect(point.y).toBeGreaterThanOrEqual(WORK_AREA.top);
          expect(point.y).toBeLessThanOrEqual(WORK_AREA.bottom);
        }
      }
    },
  );

  it('should start every conductor end on the back plate of the box', () => {
    for (const seed of SEEDS.slice(0, 200)) {
      for (const conductor of computeWiringLayout(generateWiringPuzzle(seed, 2)).conductors) {
        expect(conductor.initialEnd.x).toBeGreaterThanOrEqual(BOX_INNER.left);
        expect(conductor.initialEnd.x).toBeLessThanOrEqual(BOX_INNER.right);
        expect(conductor.initialEnd.y).toBeGreaterThanOrEqual(BOX_INNER.top);
        expect(conductor.initialEnd.y).toBeLessThanOrEqual(BOX_INNER.bottom);
      }
    }
  });

  it('should keep every initial end within reach of its anchor', () => {
    for (const seed of SEEDS.slice(0, 200)) {
      for (const conductor of computeWiringLayout(generateWiringPuzzle(seed, 3)).conductors) {
        expect(distance(conductor.initialEnd, conductor.anchor)).toBeLessThanOrEqual(
          conductor.length * 0.92,
        );
      }
    }
  });
});
