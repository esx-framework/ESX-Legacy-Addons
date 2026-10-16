/**
 * Scene geometry of the junction box: where each cable enters, where its conductors leave
 * the jacket and where their ends lie when the round starts.
 *
 * All values are scene units on a 1920 × 1080 stage; the renderer scales the stage to the
 * screen. Positions on the box are fractions of the box sprite, measured on the artwork.
 * Everything that varies is drawn from the puzzle seed, so a seed always looks the same.
 *
 * @see computeWiringLayout
 */

import { Random } from '../../core/random';
import {
  add,
  distance,
  normalize,
  perpendicular,
  rotate,
  scale,
  sub,
  vec,
  type Vec2,
} from '../../core/vec';
import type { Awg, Cable, Conductor, Insulation, WiringPuzzle } from './model';

/** Stage size in scene units. */
export const STAGE = { width: 1920, height: 1080 } as const;

/** Junction box placement on the stage. */
export const BOX = { x: 610, y: 225, size: 640 } as const;

/** Scene units per millimetre, from the 4" box outline in the artwork. */
export const PX_PER_MM = (BOX.size * 0.962) / 101.6;

/** Back plate of the box, the area conductors can rest on. */
export const BOX_INNER = {
  left: BOX.x + BOX.size * 0.111,
  top: BOX.y + BOX.size * 0.113,
  right: BOX.x + BOX.size * 0.894,
  bottom: BOX.y + BOX.size * 0.87,
} as const;

/**
 * Ceiling fixture canopy below the box, mostly off stage. `hole` is the lead grommet as a
 * fraction of the sprite, measured on the artwork.
 */
export const CANOPY = { width: 380, holeY: 1040, hole: { x: 0.5125, y: 0.4916 } } as const;

/** Where conductor ends may be pulled to: around the box, clear of the HUD and the tray. */
export const WORK_AREA = { left: 440, top: 60, right: 1410, bottom: 1060 } as const;

/** Threaded hole for the grounding screw in the middle of the back plate. */
export const SCREW_POSITION: Vec2 = vec(BOX.x + BOX.size * 0.5, BOX.y + BOX.size * 0.486);

/** Side wall knockout a cable can come through. */
interface EntrySlot {
  /** Knockout center */
  position: Vec2;
  /** Direction into the box */
  inward: Vec2;
}

const ENTRY_SLOTS: readonly EntrySlot[] = [
  { position: vec(0.492, 0.065), inward: vec(0, 1) },
  { position: vec(0.071, 0.329), inward: vec(1, 0) },
  { position: vec(0.071, 0.642), inward: vec(1, 0) },
  { position: vec(0.934, 0.338), inward: vec(-1, 0) },
  { position: vec(0.934, 0.648), inward: vec(-1, 0) },
  { position: vec(0.486, 0.918), inward: vec(0, -1) },
].map((slot: EntrySlot): EntrySlot => ({
  position: vec(BOX.x + BOX.size * slot.position.x, BOX.y + BOX.size * slot.position.y),
  inward: slot.inward,
}));

/** Insulated outer diameter per gauge in mm (THHN-style building wire, TFFN fixture leads). */
const INSULATED_MM: Readonly<Record<Awg, number>> = { 18: 2.3, 14: 2.9, 12: 3.4, 10: 4.2 };
/** Copper diameter per gauge in mm; 18 AWG is a stranded bundle. */
const COPPER_MM: Readonly<Record<Awg, number>> = { 18: 1.16, 14: 1.63, 12: 2.05, 10: 2.59 };
/** Width of a flat NM-B jacket in mm, by gauge and conductor count (without ground). */
const SHEATH_MM: Readonly<Record<string, number>> = {
  '14/2': 9.5,
  '14/3': 11.4,
  '12/2': 10.4,
  '12/3': 12.4,
  '10/2': 11.6,
};

/** How far conductors start inside the jacket, hidden under its cut edge. */
export const JACKET_LIP = 14;

/** Order of the conductors inside a flat NM-B jacket, across its width. */
const JACKET_ORDER: Readonly<Record<Insulation, number>> = {
  black: 0,
  red: 1,
  bare: 2,
  green: 2,
  white: 3,
};

const END_MARGIN = 36;
const END_SPACING = 46;

/** Placement of a cable jacket. */
export interface CableLayout {
  /** Cable id */
  cableId: string;
  /** Knockout the cable comes through, null for fixture leads and the bonding jumper */
  entry: Vec2 | null;
  /** Direction into the box */
  inward: Vec2;
  /** Where the jacket is cut and the conductors fan out */
  sheathEnd: Vec2;
  /** Jacket width in scene units */
  width: number;
  /** Rotation jitter of the tape flag in radians */
  tagTilt: number;
}

/** Placement of a conductor. */
export interface ConductorLayout {
  /** Conductor id */
  conductorId: string;
  /** Fixed start of the free conductor length */
  anchor: Vec2;
  /** Direction the conductor leaves its anchor */
  direction: Vec2;
  /** Free length in scene units; the end can never be farther from the anchor */
  length: number;
  /** Outer width including insulation */
  width: number;
  /** Width of the bare copper */
  copperWidth: number;
  /** Where the end lies when the round starts */
  initialEnd: Vec2;
}

/** Full scene geometry of a round. */
export interface WiringLayout {
  /** One entry per cable, in puzzle order */
  cables: readonly CableLayout[];
  /** One entry per conductor, in puzzle order */
  conductors: readonly ConductorLayout[];
}

function mm(value: number): number {
  return value * PX_PER_MM;
}

function clampToInner(point: Vec2, margin: number): Vec2 {
  return vec(
    Math.min(BOX_INNER.right - margin, Math.max(BOX_INNER.left + margin, point.x)),
    Math.min(BOX_INNER.bottom - margin, Math.max(BOX_INNER.top + margin, point.y)),
  );
}

function conductorWidth(conductor: Conductor): number {
  const bare = conductor.insulation === 'bare';
  return mm(bare ? COPPER_MM[conductor.awg] : INSULATED_MM[conductor.awg]);
}

/**
 * Picks a resting position for a conductor end that does not sit on top of another end.
 */
function placeEnd(
  random: Random,
  anchor: Vec2,
  length: number,
  propose: (random: Random) => Vec2,
  taken: readonly Vec2[],
): Vec2 {
  let candidate = anchor;
  for (let attempt = 0; attempt < 30; attempt++) {
    candidate = clampToInner(propose(random), END_MARGIN);
    const reach = distance(candidate, anchor);
    if (reach > length * 0.85) continue;
    if (taken.every((other: Vec2): boolean => distance(other, candidate) >= END_SPACING))
      return candidate;
  }
  return candidate;
}

/**
 * Lays out a round.
 *
 * @param puzzle - Generated round
 * @returns Scene geometry; identical for identical puzzles
 */
export function computeWiringLayout(puzzle: WiringPuzzle): WiringLayout {
  const random = new Random(puzzle.seed).fork('layout');
  const byId = new Map(puzzle.conductors.map((c: Conductor): [string, Conductor] => [c.id, c]));
  const nmCables = puzzle.cables.filter(
    (c: Cable): boolean => c.role !== 'fixture' && c.role !== 'pigtail',
  );
  const slots = random.fork('slots').sample(ENTRY_SLOTS, nmCables.length);

  const cables: CableLayout[] = [];
  const conductors: ConductorLayout[] = [];
  const ends: Vec2[] = [];
  const placement = random.fork('ends');

  nmCables.forEach((cable: Cable, index: number): void => {
    const slot = slots[index] as EntrySlot;
    const members = cable.conductorIds.map((id: string): Conductor => byId.get(id) as Conductor);
    const insulated = members.filter((c: Conductor): boolean => c.insulation !== 'bare').length;
    const width = mm(SHEATH_MM[`${cable.awg}/${insulated}`] ?? 10);
    const sheathEnd = add(slot.position, scale(slot.inward, random.float(58, 92)));
    const across = perpendicular(slot.inward);

    cables.push({
      cableId: cable.id,
      entry: slot.position,
      inward: slot.inward,
      sheathEnd,
      width,
      tagTilt: random.float(-0.14, 0.14),
    });

    // Inside the jacket the conductors lie side by side, ground in the middle, and come out
    // from under the cut edge.
    const ordered = [...members].sort(
      (a: Conductor, b: Conductor): number =>
        JACKET_ORDER[a.insulation] - JACKET_ORDER[b.insulation],
    );
    const widths = ordered.map(conductorWidth);
    const packed =
      widths.reduce((sum: number, w: number): number => sum + w, 0) + (ordered.length - 1) * 1.5;
    let cursor = -packed / 2;
    const tucked = sub(sheathEnd, scale(slot.inward, JACKET_LIP));

    ordered.forEach((conductor: Conductor, i: number): void => {
      const w = widths[i] as number;
      const offset = cursor + w / 2;
      cursor += w + 1.5;
      const anchor = add(tucked, scale(across, offset));
      const length = random.float(520, 600);
      const initialEnd = placeEnd(
        placement,
        anchor,
        length,
        (r: Random): Vec2 =>
          add(
            add(anchor, scale(slot.inward, r.float(170, 300))),
            scale(across, offset * 2.4 + r.float(-120, 120)),
          ),
        ends,
      );
      ends.push(initialEnd);
      conductors.push({
        conductorId: conductor.id,
        anchor,
        direction: slot.inward,
        length,
        width: conductorWidth(conductor),
        copperWidth: mm(COPPER_MM[conductor.awg]),
        initialEnd,
      });
    });
  });

  const fixture = puzzle.cables.find((c: Cable): boolean => c.role === 'fixture');
  if (fixture) {
    // The fixture hangs below the box; its leads come out of the canopy grommet.
    const hole = vec(BOX.x + BOX.size * random.float(0.42, 0.58), CANOPY.holeY);
    const up = vec(0, -1);
    cables.push({
      cableId: fixture.id,
      entry: null,
      inward: up,
      sheathEnd: hole,
      width: 0,
      tagTilt: 0,
    });
    fixture.conductorIds.forEach((id: string, i: number): void => {
      const conductor = byId.get(id) as Conductor;
      const anchor = vec(hole.x + (i === 0 ? -5 : 5), hole.y);
      const length = 600;
      const initialEnd = placeEnd(
        placement,
        anchor,
        length,
        (r: Random): Vec2 => vec(hole.x + r.float(-130, 130), BOX_INNER.bottom - r.float(20, 130)),
        ends,
      );
      ends.push(initialEnd);
      conductors.push({
        conductorId: id,
        anchor,
        direction: up,
        length,
        width: conductorWidth(conductor),
        copperWidth: mm(COPPER_MM[conductor.awg]),
        initialEnd,
      });
    });
  }

  const pigtail = byId.get('pg.bare');
  if (pigtail) {
    const direction = rotate(vec(1, 0), random.float(0, Math.PI * 2));
    cables.push({
      cableId: 'pg',
      entry: null,
      inward: direction,
      sheathEnd: SCREW_POSITION,
      width: 0,
      tagTilt: 0,
    });
    const length = 280;
    const initialEnd = placeEnd(
      placement,
      SCREW_POSITION,
      length,
      (r: Random): Vec2 =>
        add(SCREW_POSITION, scale(rotate(direction, r.float(-0.6, 0.6)), r.float(110, 170))),
      ends,
    );
    conductors.push({
      conductorId: pigtail.id,
      anchor: SCREW_POSITION,
      direction: normalize(sub(initialEnd, SCREW_POSITION)),
      length,
      width: conductorWidth(pigtail),
      copperWidth: mm(COPPER_MM[pigtail.awg]),
      initialEnd,
    });
  }

  return { cables, conductors };
}
