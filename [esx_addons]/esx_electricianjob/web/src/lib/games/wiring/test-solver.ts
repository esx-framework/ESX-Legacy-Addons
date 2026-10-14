/**
 * Reference solution for tests: wires a generated box the way an electrician would, reading
 * where each conductor lands. Not used by the game itself.
 */

import { nutFits } from './electrical';
import {
  NUT_COLORS,
  type Conductor,
  type NutColor,
  type Splice,
  type WiringPuzzle,
  type WiringState,
} from './model';

type Group = 'hot' | 'switched' | 'neutral' | 'ground';

function groupOf(conductor: Conductor): Group {
  if (conductor.insulation === 'bare' || conductor.insulation === 'green') return 'ground';
  const terminal = conductor.terminal;
  if (terminal === 'switch.b' || terminal === 'fixture.hot') return 'switched';
  if (terminal === 'panel.hot' || terminal === 'switch.a' || terminal.endsWith('.hot'))
    return 'hot';
  return 'neutral';
}

function smallestNut(conductors: readonly Conductor[]): NutColor {
  const nut = NUT_COLORS.find((color: NutColor): boolean => nutFits(color, conductors));
  if (!nut)
    throw new Error(
      `no connector fits ${conductors.map((c: Conductor): string => c.id).join(', ')}`,
    );
  return nut;
}

/**
 * @param puzzle - Generated round
 * @returns A state that passes inspection
 */
export function solveWiring(puzzle: WiringPuzzle): WiringState {
  const groups = new Map<Group, Conductor[]>();
  for (const conductor of puzzle.conductors) {
    const group = groupOf(conductor);
    groups.set(group, [...(groups.get(group) ?? []), conductor]);
  }

  const splices: Splice[] = [];
  const taped = new Set<string>();
  for (const [group, members] of groups) {
    splices.push({
      id: group,
      conductorIds: members.map((c: Conductor): string => c.id),
      nut: smallestNut(members),
    });
    if (group === 'hot' || group === 'switched') {
      for (const member of members) {
        if (member.insulation === 'white' && !member.marked) taped.add(member.id);
      }
    }
  }

  const stripped = new Set(
    puzzle.conductors
      .filter((c: Conductor): boolean => c.needsStrip)
      .map((c: Conductor): string => c.id),
  );
  return { splices, stripped, taped };
}
