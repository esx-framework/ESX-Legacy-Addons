/**
 * Builds junction box rounds from a seed.
 *
 * Every round is a real residential box: a feed from the panel, optionally a switch loop and
 * a ceiling fixture hanging from the box, optionally cables continuing to receptacles. What
 * varies per seed is the scenario, wire size, switch loop style, which cables still carry
 * the previous electrician's tape flags and which conductor ends are damaged.
 *
 * Counts are capped so that every splice a correct solution needs fits the red connector;
 * the generator tests check that for thousands of seeds.
 *
 * @see generateWiringPuzzle
 */

import type { Difficulty } from '../../nui/messages';
import { Random, type Weighted } from '../../core/random';
import { BOX_GROUND, PANEL_GROUND, PANEL_HOT, PANEL_NEUTRAL } from './electrical';
import type {
  Awg,
  BreakerAmps,
  Cable,
  CableRole,
  Conductor,
  Insulation,
  Load,
  Sheath,
  SwitchLoopStyle,
  TerminalId,
  WiringPuzzle,
  WiringTemplate,
} from './model';

/** Cable before ids are assigned. */
interface CableDraft {
  role: CableRole;
  awg: Awg;
  sheath: Sheath;
  wires: readonly WireDraft[];
}

interface WireDraft {
  insulation: Insulation;
  terminal: TerminalId;
  marked?: boolean;
}

const TEMPLATE_WEIGHTS: Readonly<Record<Difficulty, readonly Weighted<WiringTemplate>[]>> = {
  1: [
    { value: 'splice-through', weight: 7 },
    { value: 'switched-light', weight: 3 },
  ],
  2: [
    { value: 'splice-through', weight: 2 },
    { value: 'switched-light', weight: 5 },
    { value: 'switched-light-feed-through', weight: 3 },
  ],
  3: [
    { value: 'switched-light', weight: 3 },
    { value: 'switched-light-feed-through', weight: 7 },
  ],
};

const LOOP_WEIGHTS: Readonly<Record<Difficulty, readonly Weighted<SwitchLoopStyle>[]>> = {
  1: [{ value: 'three-wire', weight: 1 }],
  2: [
    { value: 'three-wire', weight: 6 },
    { value: 'two-wire-marked', weight: 4 },
  ],
  3: [
    { value: 'three-wire', weight: 4 },
    { value: 'two-wire-marked', weight: 2 },
    { value: 'two-wire-unmarked', weight: 4 },
  ],
};

/** Conductors with damaged ends, as [min, max] per difficulty. */
const STRIP_COUNT: Readonly<Record<Difficulty, readonly [number, number]>> = {
  1: [0, 0],
  2: [1, 2],
  3: [2, 4],
};

const TAG_TEXT: Readonly<Record<CableRole, readonly string[]>> = {
  line: ['LINE', 'FEED', 'PWR IN'],
  switch: ['SW', 'SWITCH', 'SW LOOP'],
  receptacle: ['REC', 'RECPT', 'OUTLETS'],
  fixture: [],
};

const SHEATH_BY_AWG: Readonly<Record<Awg, Sheath>> = {
  18: 'none',
  14: 'white',
  12: 'yellow',
  10: 'orange',
};

function nmCable(role: CableRole, awg: Awg, wires: readonly WireDraft[]): CableDraft {
  return { role, awg, sheath: SHEATH_BY_AWG[awg], wires };
}

function lineCable(awg: Awg): CableDraft {
  return nmCable('line', awg, [
    { insulation: 'black', terminal: PANEL_HOT },
    { insulation: 'white', terminal: PANEL_NEUTRAL },
    { insulation: 'bare', terminal: PANEL_GROUND },
  ]);
}

function receptacleCable(awg: Awg, device: string): CableDraft {
  return nmCable('receptacle', awg, [
    { insulation: 'black', terminal: `${device}.hot` },
    { insulation: 'white', terminal: `${device}.neutral` },
    { insulation: 'bare', terminal: `${device}.ground` },
  ]);
}

function switchCable(awg: Awg, style: SwitchLoopStyle): CableDraft {
  if (style === 'three-wire') {
    return nmCable('switch', awg, [
      { insulation: 'black', terminal: 'switch.a' },
      { insulation: 'red', terminal: 'switch.b' },
      { insulation: 'white', terminal: 'switch.neutral' },
      { insulation: 'bare', terminal: 'switch.ground' },
    ]);
  }
  return nmCable('switch', awg, [
    { insulation: 'black', terminal: 'switch.b' },
    { insulation: 'white', terminal: 'switch.a', marked: style === 'two-wire-marked' },
    { insulation: 'bare', terminal: 'switch.ground' },
  ]);
}

function fixtureLeads(): CableDraft {
  return {
    role: 'fixture',
    awg: 18,
    sheath: 'none',
    wires: [
      { insulation: 'black', terminal: 'fixture.hot' },
      { insulation: 'white', terminal: 'fixture.neutral' },
    ],
  };
}

function receptacleLoad(device: string): Load {
  return {
    id: device,
    kind: 'receptacle',
    hot: `${device}.hot`,
    neutral: `${device}.neutral`,
    ground: `${device}.ground`,
    switched: false,
  };
}

/** Fixtures are grounded through their mounting strap, which is screwed to the box. */
const FIXTURE_LOAD: Load = {
  id: 'fixture',
  kind: 'fixture',
  hot: 'fixture.hot',
  neutral: 'fixture.neutral',
  ground: BOX_GROUND,
  switched: true,
};

/**
 * Most receptacle cables per scenario so that the largest splice still fits a red
 * connector (5 conductors, 4 × 12 AWG).
 */
function receptacleRange(
  template: WiringTemplate,
  awg: Awg,
  difficulty: Difficulty,
): [number, number] {
  switch (template) {
    case 'splice-through':
      return awg === 12 ? [1, 2] : difficulty === 1 ? [1, 2] : [2, 3];
    case 'switched-light-feed-through':
      return awg === 12 ? [1, 1] : [1, 2];
    case 'switched-light':
      return [0, 0];
    default:
      return [0, 0];
  }
}

/**
 * Keeps the round fair when tags are missing: the line is found with the tester, fixture
 * leads and 3-wire or taped loops are recognisable, but two unlabelled plain 2-wire cables
 * could not be told apart. All but one of those get their tag back.
 */
function ensureDeducible(
  cables: Cable[],
  drafts: ReadonlyMap<string, CableDraft>,
  random: Random,
): void {
  const ambiguous = cables.filter((cable: Cable): boolean => {
    const draft: CableDraft | undefined = drafts.get(cable.id);
    if (!draft || cable.tag !== null || draft.role === 'line' || draft.role === 'fixture')
      return false;
    const recognisable = draft.wires.some(
      (wire: WireDraft): boolean => wire.insulation === 'red' || wire.marked === true,
    );
    return !recognisable;
  });

  for (const cable of ambiguous.slice(1)) {
    const draft = drafts.get(cable.id) as CableDraft;
    cable.tag = random.pick(TAG_TEXT[draft.role]);
  }
}

function tagProbability(role: CableRole, difficulty: Difficulty): number {
  if (role === 'fixture') return 0;
  if (difficulty === 1) return 1;
  if (difficulty === 2) return role === 'line' ? 1 : 0.75;
  return role === 'line' ? 0.3 : 0.5;
}

/**
 * Generates a junction box round.
 *
 * @param seed - Unsigned 32-bit seed from the server
 * @param difficulty - Difficulty tier
 * @returns The round; the same arguments always return an identical round
 *
 * @example
 * ```typescript
 * const puzzle = generateWiringPuzzle(184_467, 2);
 * puzzle.cables.map((cable) => cable.tag); // ['SW', 'LINE', null, null]
 * ```
 */
export function generateWiringPuzzle(seed: number, difficulty: Difficulty): WiringPuzzle {
  const random = new Random(seed);
  const template: WiringTemplate = random.fork('template').weighted(TEMPLATE_WEIGHTS[difficulty]);

  const circuit = random.fork('circuit');
  const awg: Awg = circuit.chance(0.6) ? 14 : 12;
  const breakerAmps: BreakerAmps = awg === 14 ? 15 : 20;

  const hasSwitch = template !== 'splice-through';
  const switchLoop: SwitchLoopStyle | null = hasSwitch
    ? random.fork('switch-loop').weighted(LOOP_WEIGHTS[difficulty])
    : null;

  const [minRec, maxRec] = receptacleRange(template, awg, difficulty);
  const receptacleCount = random.fork('receptacles').int(minRec, maxRec);

  const drafts: CableDraft[] = [lineCable(awg)];
  const loads: Load[] = [];
  for (let i = 1; i <= receptacleCount; i++) {
    drafts.push(receptacleCable(awg, `rec${i}`));
    loads.push(receptacleLoad(`rec${i}`));
  }
  if (switchLoop) {
    drafts.push(switchCable(awg, switchLoop), fixtureLeads());
    loads.push(FIXTURE_LOAD);
  }

  // Ids follow a shuffled order so that c1 is not always the feed.
  const order = random.fork('order').shuffle(drafts);
  const tags = random.fork('tags');
  const cables: Cable[] = [];
  const conductors: Conductor[] = [];
  const draftsById = new Map<string, CableDraft>();

  order.forEach((draft: CableDraft, index: number): void => {
    const id = draft.role === 'fixture' ? 'fx' : `c${index + 1}`;
    draftsById.set(id, draft);
    const conductorIds: string[] = [];
    for (const wire of draft.wires) {
      const conductorId = `${id}.${wire.insulation}`;
      conductorIds.push(conductorId);
      conductors.push({
        id: conductorId,
        cableId: id,
        insulation: wire.insulation,
        awg: draft.awg,
        stranded: draft.role === 'fixture',
        terminal: wire.terminal,
        marked: wire.marked ?? false,
        needsStrip: false,
      });
    }
    const hasTag = tags.chance(tagProbability(draft.role, difficulty));
    cables.push({
      id,
      role: draft.role,
      awg: draft.awg,
      sheath: draft.sheath,
      tag: hasTag ? tags.pick(TAG_TEXT[draft.role]) : null,
      conductorIds,
    });
  });
  ensureDeducible(cables, draftsById, tags.fork('fair'));

  // Bonding jumper, already screwed to the box.
  cables.push({
    id: 'pg',
    role: 'pigtail',
    awg,
    sheath: 'none',
    tag: null,
    conductorIds: ['pg.bare'],
  });
  conductors.push({
    id: 'pg.bare',
    cableId: 'pg',
    insulation: 'bare',
    awg,
    stranded: false,
    terminal: BOX_GROUND,
    marked: false,
    needsStrip: false,
  });

  // Damaged ends only on solid insulated building wire; bare copper and fixture leads are fine.
  const strippable = conductors.filter(
    (c: Conductor): boolean => !c.stranded && c.insulation !== 'bare' && c.cableId !== 'pg',
  );
  const strip = random.fork('strip');
  const [minStrip, maxStrip] = STRIP_COUNT[difficulty];
  for (const conductor of strip.sample(
    strippable,
    Math.min(strippable.length, strip.int(minStrip, maxStrip)),
  )) {
    conductor.needsStrip = true;
  }

  return {
    seed,
    difficulty,
    template,
    breakerAmps,
    cables,
    conductors,
    loads,
    wallSwitch: switchLoop ? { poles: ['switch.a', 'switch.b'] } : null,
    switchLoop,
  };
}
