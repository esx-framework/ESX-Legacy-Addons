/**
 * Reference solution for tests: wires a generated box by its connection plan. Not used by
 * the game itself.
 */

import { nutFits } from './electrical';
import { connectionPlan, whitesToMark, type PlanBundle } from './guide';
import {
  NUT_COLORS,
  type Conductor,
  type NutColor,
  type Splice,
  type WiringPuzzle,
  type WiringState,
} from './model';

function smallestNut(conductors: readonly Conductor[]): NutColor {
  const nut = NUT_COLORS.find((color: NutColor): boolean => nutFits(color, conductors));
  if (!nut) {
    throw new Error(
      `no connector fits ${conductors.map((c: Conductor): string => c.id).join(', ')}`,
    );
  }
  return nut;
}

/**
 * @param puzzle - Generated round
 * @returns A state that passes inspection
 */
export function solveWiring(puzzle: WiringPuzzle): WiringState {
  const byId = new Map(puzzle.conductors.map((c: Conductor): [string, Conductor] => [c.id, c]));
  const splices: Splice[] = connectionPlan(puzzle).map((bundle: PlanBundle): Splice => ({
    id: bundle.role,
    conductorIds: bundle.conductorIds,
    nut: smallestNut(bundle.conductorIds.map((id: string): Conductor => byId.get(id) as Conductor)),
  }));
  const stripped = new Set(
    puzzle.conductors
      .filter((c: Conductor): boolean => c.needsStrip)
      .map((c: Conductor): string => c.id),
  );
  return { splices, stripped, taped: new Set(whitesToMark(puzzle)) };
}
