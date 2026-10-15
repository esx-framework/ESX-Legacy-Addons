/**
 * Plays junction box rounds through the engine's pointer API, the way the UI feeds it, and
 * checks that a careful player can always finish the job.
 */

import { describe, expect, it } from 'vitest';
import type { Difficulty } from '../../nui/messages';
import { distance, vec, type Vec2 } from '../../core/vec';
import {
  WiringEngine,
  type ConductorRuntime,
  type EngineEvent,
  type SpliceRuntime,
} from './engine';
import { generateWiringPuzzle } from './generator';
import { computeWiringLayout, SCREW_POSITION } from './layout';
import { NUT_COLORS, type Conductor } from './model';
import { TRAY_AREAS } from './scene/tray';

type Group = 'hot' | 'switched' | 'neutral' | 'ground';

const GROUP_ANGLE: Readonly<Record<Group, number>> = {
  hot: Math.PI * 1.15,
  neutral: Math.PI * 0.68,
  switched: Math.PI * 0.32,
  ground: Math.PI * 1.7,
};

function groupOf(conductor: Conductor): Group {
  if (conductor.insulation === 'bare' || conductor.insulation === 'green') return 'ground';
  if (conductor.terminal === 'switch.b' || conductor.terminal === 'fixture.hot') return 'switched';
  if (conductor.terminal === 'switch.a' || conductor.terminal.endsWith('.hot')) return 'hot';
  return 'neutral';
}

function areaCenter(area: { x: number; y: number; width: number; height: number }): Vec2 {
  return vec(area.x + area.width / 2, area.y + area.height / 2);
}

/** Minimal player: press, move in steps, release. */
class Player {
  readonly events: EngineEvent[] = [];
  readonly engine: WiringEngine;

  constructor(seed: number, difficulty: Difficulty) {
    const puzzle = generateWiringPuzzle(seed, difficulty);
    this.engine = new WiringEngine(puzzle, computeWiringLayout(puzzle), TRAY_AREAS, (event) => {
      this.events.push(event);
    });
  }

  drag(from: Vec2, to: Vec2): void {
    this.engine.pointerDown(from, 0);
    for (let i = 1; i <= 10; i++) {
      this.engine.pointerMove(
        vec(from.x + ((to.x - from.x) * i) / 10, from.y + ((to.y - from.y) * i) / 10),
      );
    }
    this.engine.pointerUp(to);
  }

  end(id: string): ConductorRuntime {
    return this.engine.conductor(id);
  }

  spliceOf(id: string): SpliceRuntime | undefined {
    const spliceId = this.end(id).spliceId;
    return spliceId ? this.engine.splices.get(spliceId) : undefined;
  }

  /** A spot every conductor of the group can reach, clear of foreign ends and splices. */
  target(ids: readonly string[], group: Group): Vec2 {
    const members = ids.map((id: string): ConductorRuntime => this.end(id));
    const obstacles: Vec2[] = [
      ...this.engine.conductors
        .filter((runtime: ConductorRuntime): boolean => !ids.includes(runtime.conductor.id))
        .map((runtime: ConductorRuntime): Vec2 => runtime.end),
      ...[...this.engine.splices.values()].map((splice: SpliceRuntime): Vec2 => splice.point),
    ];
    let best = SCREW_POSITION;
    let bestClearance = -Infinity;
    for (const radius of [70, 110, 150, 190]) {
      for (let k = 0; k < 18; k++) {
        const angle = GROUP_ANGLE[group] + (k % 2 === 0 ? 1 : -1) * Math.ceil(k / 2) * 0.35;
        let point = vec(
          SCREW_POSITION.x + Math.cos(angle) * radius,
          SCREW_POSITION.y + Math.sin(angle) * radius,
        );
        for (let pass = 0; pass < 8; pass++) {
          for (const member of members) {
            const { anchor, length } = member.layout;
            const span = distance(point, anchor);
            const max = length * 0.8;
            if (span > max) {
              point = vec(
                anchor.x + ((point.x - anchor.x) * max) / span,
                anchor.y + ((point.y - anchor.y) * max) / span,
              );
            }
          }
        }
        const reachable = members.every(
          (member: ConductorRuntime): boolean =>
            distance(point, member.layout.anchor) <= member.layout.length * 0.85,
        );
        if (!reachable) continue;
        const clearance = Math.min(...obstacles.map((o: Vec2): number => distance(o, point)));
        if (clearance > bestClearance) {
          best = point;
          bestClearance = clearance;
        }
      }
    }
    return best;
  }

  solve(): void {
    const { engine } = this;
    engine.toggleBreaker();

    for (const runtime of engine.conductors) {
      if (!runtime.conductor.needsStrip) continue;
      this.drag(areaCenter(TRAY_AREAS.tools.stripper), runtime.end);
      engine.strip(runtime.conductor.id, runtime.conductor.awg);
    }

    const groups = new Map<Group, string[]>();
    for (const runtime of engine.conductors) {
      const group = groupOf(runtime.conductor);
      groups.set(group, [...(groups.get(group) ?? []), runtime.conductor.id]);
    }

    for (const [group, ids] of groups) {
      if (group !== 'hot' && group !== 'switched') continue;
      for (const id of ids) {
        const { conductor } = this.end(id);
        if (conductor.insulation === 'white' && !conductor.marked) {
          this.drag(areaCenter(TRAY_AREAS.tools.tape), this.end(id).end);
        }
      }
    }

    for (const [group, ids] of groups) {
      const target = this.target(ids, group);
      ids.forEach((id: string, index: number): void => {
        const splice = this.spliceOf(ids[0] as string);
        const drop =
          index === 0
            ? target
            : splice
              ? vec(splice.point.x + 2, splice.point.y + 2)
              : vec(target.x + 6, target.y + 4);
        const before = this.end(id).end;
        this.drag(before, drop);
        expect(this.engine.dragged, `drag of ${id} still active`).toBeNull();
      });

      const splice = this.spliceOf(ids[0] as string);
      expect(splice, `bundle ${ids.join(',')}`).toBeDefined();
      expect([...(splice as SpliceRuntime).members].sort(), `bundle ${ids.join(',')}`).toEqual(
        [...ids].sort(),
      );

      for (const color of NUT_COLORS) {
        this.drag(areaCenter(TRAY_AREAS.nuts[color]), (splice as SpliceRuntime).point);
        if ((splice as SpliceRuntime).nut) break;
      }
      expect((splice as SpliceRuntime).nut, `nut on ${ids.join(',')}`).not.toBeNull();

      const center = (splice as SpliceRuntime).point;
      engine.pointerDown(center, 0);
      for (let step = 0; step <= 64; step++) {
        const angle = (step / 28) * Math.PI * 2;
        engine.pointerMove(vec(center.x + Math.cos(angle) * 54, center.y + Math.sin(angle) * 54));
      }
      engine.pointerUp(center);
      expect((splice as SpliceRuntime).twist, `twist on ${ids.join(',')}`).toBe(1);
    }

    engine.toggleBreaker();
    if (engine.puzzle.wallSwitch) engine.toggleSwitch();
  }
}

const SEEDS = Array.from(
  { length: 120 },
  (_: unknown, i: number): number => (i * 92821 + 1056) >>> 0,
);

describe('WiringEngine', () => {
  it.each([1, 2, 3] as const)(
    'should let a careful player pass inspection on difficulty %i',
    (difficulty: Difficulty) => {
      for (const seed of SEEDS) {
        const player = new Player(seed, difficulty);
        player.solve();
        expect(player.engine.inspect(), `seed ${seed}`).toEqual([]);
        expect(player.engine.mistakes, `seed ${seed}`).toBe(0);
        if (player.engine.puzzle.wallSwitch) {
          expect(player.engine.live.loads.get('fixture'), `seed ${seed}`).toBe('on');
        }
      }
    },
  );

  it('should shock a player who grabs the live feed with the breaker on', () => {
    const player = new Player(1056, 1);
    const feed = player.engine.conductors.find(
      (runtime: ConductorRuntime): boolean => runtime.conductor.terminal === 'panel.hot',
    ) as ConductorRuntime;
    player.engine.pointerDown(feed.end, 0);
    expect(player.events.some((event: EngineEvent): boolean => event.type === 'shock')).toBe(true);
    expect(player.engine.mistakes).toBe(1);
    expect(player.engine.dragged).toBeNull();
  });

  it('should trip the breaker when hot is spliced to neutral', () => {
    const player = new Player(1056, 1);
    const { engine } = player;
    engine.toggleBreaker();
    const hot = engine.conductors.find(
      (r: ConductorRuntime): boolean => r.conductor.terminal === 'panel.hot',
    ) as ConductorRuntime;
    const neutral = engine.conductors.find(
      (r: ConductorRuntime): boolean => r.conductor.terminal === 'panel.neutral',
    ) as ConductorRuntime;
    const target = vec((hot.end.x + neutral.end.x) / 2, (hot.end.y + neutral.end.y) / 2);
    player.drag(hot.end, target);
    player.drag(neutral.end, vec(target.x + 5, target.y + 3));
    const splice = player.spliceOf(hot.conductor.id) as SpliceRuntime;
    player.drag(areaCenter(TRAY_AREAS.nuts.yellow), splice.point);
    engine.pointerDown(splice.point, 0);
    for (let step = 0; step <= 64; step++) {
      const angle = (step / 28) * Math.PI * 2;
      engine.pointerMove(
        vec(splice.point.x + Math.cos(angle) * 54, splice.point.y + Math.sin(angle) * 54),
      );
    }
    engine.pointerUp(splice.point);
    engine.toggleBreaker();
    expect(player.events.some((event: EngineEvent): boolean => event.type === 'short')).toBe(true);
    expect(engine.breakerOn).toBe(false);
  });

  it('should only seat a wire nut rated for the bundle', () => {
    const player = new Player(1056, 3);
    const { engine } = player;
    engine.toggleBreaker();
    const grounds = engine.conductors.filter(
      (r: ConductorRuntime): boolean => r.conductor.insulation === 'bare',
    );
    const target = player.target(
      grounds.map((r: ConductorRuntime): string => r.conductor.id),
      'ground',
    );
    grounds.forEach((runtime: ConductorRuntime, index: number): void => {
      const splice = player.spliceOf((grounds[0] as ConductorRuntime).conductor.id);
      player.drag(
        runtime.end,
        index === 0 ? target : splice ? splice.point : vec(target.x + 6, target.y),
      );
    });
    const splice = player.spliceOf((grounds[0] as ConductorRuntime).conductor.id) as SpliceRuntime;
    player.drag(areaCenter(TRAY_AREAS.nuts.orange), splice.point);
    expect(splice.nut).toBeNull();
    expect(player.events.some((event: EngineEvent): boolean => event.type === 'nut-rejected')).toBe(
      true,
    );
  });
});
