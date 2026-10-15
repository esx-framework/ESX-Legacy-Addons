/**
 * Interaction logic of the junction box scene.
 *
 * Holds everything that changes while the player works: where each conductor end lies, which
 * ends are bundled, connectors and how far they are twisted on, stripped and taped
 * conductors, breaker and switch. Pointer input comes in through the `pointer*` methods,
 * the renderer reads the public fields every frame and anything the HUD or audio cares
 * about is reported through {@link EngineEvent}s.
 *
 * Plain objects on purpose: positions change on every pointer move and must not go through
 * Svelte's reactive proxies.
 *
 * @see WiringEngine
 */

import {
  add,
  distance,
  distanceToSegment,
  normalize,
  perpendicular,
  scale,
  sub,
  vec,
  type Vec2,
} from '../../core/vec';
import { evaluateWiring, nutFits, simulateWiring, type Issue, type Simulation } from './electrical';
import { BOX_INNER, PX_PER_MM, WORK_AREA, type ConductorLayout, type WiringLayout } from './layout';
import type { Conductor, NutColor, Splice, WiringPuzzle, WiringState } from './model';
import {
  createPolyline,
  distanceToPolyline,
  sampleWire,
  startHandleFor,
  type WirePolyline,
} from './scene/wire-path';

/** Length of bare copper on a stripped end; wire nut packaging asks for 5/8" or less. */
export const STRIP_LENGTH = 11 * PX_PER_MM;

/** Drawn length of each connector size. */
export const NUT_LENGTH: Readonly<Record<NutColor, number>> = {
  orange: 21 * PX_PER_MM,
  yellow: 25 * PX_PER_MM,
  red: 29 * PX_PER_MM,
};

/** Full turns needed to seat a connector. */
const TWIST_TURNS = 1.75;
const PICK_RADIUS = 22;
const JOIN_RADIUS = 38;
const SPLICE_RADIUS = 46;
const TESTER_RANGE = 80;
const TAPE_RANGE = 34;

/** Tools lying in the tray. */
export type ToolKind = 'tester' | 'stripper' | 'tape';

/** Something the player can carry with the pointer. */
export type Held = { kind: 'tool'; tool: ToolKind } | { kind: 'nut'; color: NutColor };

/** Rectangle on the stage, used for tray hit areas. */
export interface Area {
  /** Left edge */
  x: number;
  /** Top edge */
  y: number;
  /** Width */
  width: number;
  /** Height */
  height: number;
}

/** Live state of a conductor. */
export interface ConductorRuntime {
  /** Static data */
  readonly conductor: Conductor;
  /** Static geometry */
  readonly layout: ConductorLayout;
  /** Current end position */
  end: Vec2;
  /** Direction the end points to */
  endDirection: Vec2;
  /** Splice the end belongs to, null when free */
  spliceId: string | null;
  /** Sampled shape, refreshed by {@link WiringEngine.updateGeometry} */
  readonly line: WirePolyline;
  /** Arc length of {@link line} */
  total: number;
}

/** Live state of a splice. */
export interface SpliceRuntime {
  /** Id, also used in the action log */
  readonly id: string;
  /** Joined conductors */
  members: string[];
  /** Where the conductor ends meet */
  point: Vec2;
  /** Direction from the conductors into the connector */
  direction: Vec2;
  /** Connector on the bundle, null when the ends are only held together */
  nut: NutColor | null;
  /** Twist progress of the connector, 1 = tight */
  twist: number;
}

/** Entry of the action log the server replays. */
export type WiringAction =
  | { t: number; a: 'join'; ids: readonly string[] }
  | { t: number; a: 'part'; id: string }
  | { t: number; a: 'nut'; splice: readonly string[]; color: NutColor }
  | { t: number; a: 'unnut'; splice: readonly string[] }
  | { t: number; a: 'strip'; id: string; notch: number }
  | { t: number; a: 'tape'; id: string }
  | { t: number; a: 'breaker'; on: boolean }
  | { t: number; a: 'switch'; on: boolean }
  | { t: number; a: 'shock'; id: string }
  | { t: number; a: 'inspect' };

/** Notifications for HUD, audio and effects. */
export type EngineEvent =
  | { type: 'pickup' }
  | { type: 'joined'; at: Vec2 }
  | { type: 'parted' }
  | { type: 'nut-seated'; at: Vec2 }
  | { type: 'nut-rejected'; reason: 'too-small' | 'single' | 'occupied'; at: Vec2 }
  | { type: 'nut-tight'; at: Vec2 }
  | { type: 'nut-removed'; at: Vec2 }
  | { type: 'strip-request'; conductorId: string; at: Vec2 }
  | { type: 'stripped'; at: Vec2 }
  | { type: 'strip-nicked'; at: Vec2 }
  | { type: 'strip-slipped'; at: Vec2 }
  | { type: 'not-damaged'; at: Vec2 }
  | { type: 'taped'; at: Vec2 }
  | { type: 'shock'; at: Vec2 }
  | { type: 'short'; at: Vec2 }
  | { type: 'breaker'; on: boolean }
  | { type: 'switch'; on: boolean }
  | { type: 'mistake'; count: number };

type Drag =
  | { kind: 'end'; id: string; offset: Vec2 }
  | { kind: 'splice'; id: string; offset: Vec2 }
  | { kind: 'twist'; id: string; lastAngle: number }
  | { kind: 'held'; held: Held };

/** Tray layout the engine needs for picking things up. */
export interface TrayAreas {
  /** Hit area per tool */
  tools: Readonly<Record<ToolKind, Area>>;
  /** Hit area per connector compartment */
  nuts: Readonly<Record<NutColor, Area>>;
}

/**
 * Where a splice's wire nut sits. It slides further over the copper as it is twisted on.
 *
 * @param splice - Splice with a nut
 * @returns Center of the nut sprite
 */
export function nutCenter(splice: SpliceRuntime): Vec2 {
  const length = splice.nut ? NUT_LENGTH[splice.nut] : 0;
  return add(splice.point, scale(splice.direction, length * (0.18 + splice.twist * 0.14)));
}

/**
 * Direction a free end points to when nothing holds it: the wire simply continues its arc,
 * so the end never kinks.
 */
function naturalEndDirection(layout: ConductorLayout, end: Vec2): Vec2 {
  const span = distance(layout.anchor, end);
  const handle = add(layout.anchor, scale(layout.direction, startHandleFor(span)));
  const towards = sub(end, handle);
  return Math.hypot(towards.x, towards.y) < 1 ? layout.direction : normalize(towards);
}

function inside(area: Area, p: Vec2): boolean {
  return (
    p.x >= area.x && p.x <= area.x + area.width && p.y >= area.y && p.y <= area.y + area.height
  );
}

/** Junction box interaction state machine. */
export class WiringEngine {
  readonly conductors: ConductorRuntime[];
  readonly splices = new Map<string, SpliceRuntime>();
  readonly stripped = new Set<string>();
  readonly taped = new Set<string>();
  readonly actions: WiringAction[] = [];

  breakerOn = true;
  switchOn = false;
  mistakes = 0;
  /** Pointer position on the stage */
  pointer: Vec2 = vec(0, 0);
  /** Item following the pointer, if any */
  held: Held | null = null;
  /** Conductor or splice under the pointer, for hover highlighting */
  hover: string | null = null;
  /** 0..1 proximity of the tester tip to a live conductor */
  testerLevel = 0;
  /** Conductor ends glowing after a failed inspection */
  highlighted: ReadonlySet<string> = new Set();

  private drag: Drag | null = null;
  private simulation: Simulation;
  private readonly byId = new Map<string, ConductorRuntime>();
  private nextSpliceId = 1;
  private readonly startedAt = performance.now();

  constructor(
    readonly puzzle: WiringPuzzle,
    readonly layout: WiringLayout,
    private readonly tray: TrayAreas,
    private readonly emit: (event: EngineEvent) => void,
  ) {
    const layoutById = new Map(
      layout.conductors.map((c: ConductorLayout): [string, ConductorLayout] => [c.conductorId, c]),
    );
    this.conductors = puzzle.conductors.map((conductor: Conductor): ConductorRuntime => {
      const geometry = layoutById.get(conductor.id);
      if (!geometry) throw new Error(`layout misses conductor ${conductor.id}`);
      const runtime: ConductorRuntime = {
        conductor,
        layout: geometry,
        end: geometry.initialEnd,
        endDirection: naturalEndDirection(geometry, geometry.initialEnd),
        spliceId: null,
        line: createPolyline(),
        total: 0,
      };
      this.byId.set(conductor.id, runtime);
      return runtime;
    });
    this.simulation = this.simulate();
    this.updateGeometry();
  }

  /** Model view of what the player did, for simulation and inspection. */
  get state(): WiringState {
    const splices: Splice[] = [];
    for (const splice of this.splices.values()) {
      splices.push({
        id: splice.id,
        conductorIds: splice.members.slice(),
        nut: splice.nut !== null && splice.twist >= 1 ? splice.nut : null,
      });
    }
    return { splices, stripped: this.stripped, taped: this.taped };
  }

  /** Current simulation for the breaker and switch positions. */
  get live(): Simulation {
    return this.simulation;
  }

  /** Splice currently being twisted, if any. */
  get twisting(): SpliceRuntime | null {
    return this.drag?.kind === 'twist' ? (this.splices.get(this.drag.id) ?? null) : null;
  }

  /** Item being dragged, for the renderer to draw it last. */
  get dragged(): string | null {
    if (this.drag?.kind === 'end') return this.drag.id;
    if (this.drag?.kind === 'splice') return this.drag.id;
    return null;
  }

  /**
   * @param id - Conductor id
   * @returns Runtime state of the conductor
   */
  conductor(id: string): ConductorRuntime {
    const runtime = this.byId.get(id);
    if (!runtime) throw new Error(`unknown conductor ${id}`);
    return runtime;
  }

  /** Whether a conductor end shows bare copper. */
  isExposed(id: string): boolean {
    const runtime = this.conductor(id);
    return (
      runtime.conductor.insulation === 'bare' ||
      !runtime.conductor.needsStrip ||
      this.stripped.has(id)
    );
  }

  /** Recomputes every wire shape. Cheap enough to run each frame something moved. */
  updateGeometry(): void {
    for (const runtime of this.conductors) {
      const { anchor, direction } = runtime.layout;
      if (runtime.spliceId === null)
        runtime.endDirection = naturalEndDirection(runtime.layout, runtime.end);
      runtime.total = sampleWire(
        { anchor, direction, end: runtime.end, endDirection: runtime.endDirection },
        runtime.line,
      );
    }
  }

  pointerDown(p: Vec2, button: number): void {
    this.pointer = p;
    if (button === 2) {
      this.secondaryAction(p);
      return;
    }
    if (this.held) return;

    const tool = (Object.keys(this.tray.tools) as ToolKind[]).find((kind: ToolKind): boolean =>
      inside(this.tray.tools[kind], p),
    );
    if (tool) {
      this.held = { kind: 'tool', tool };
      this.drag = { kind: 'held', held: this.held };
      this.emit({ type: 'pickup' });
      return;
    }
    const nut = (Object.keys(this.tray.nuts) as NutColor[]).find((color: NutColor): boolean =>
      inside(this.tray.nuts[color], p),
    );
    if (nut) {
      this.held = { kind: 'nut', color: nut };
      this.drag = { kind: 'held', held: this.held };
      this.emit({ type: 'pickup' });
      return;
    }

    const hit = this.spliceAt(p);
    const end = this.endAt(p);
    // When a loose end lies right next to a nut, whichever is closer wins.
    const splice = hit && (!end || hit.distance <= distance(end.end, p)) ? hit.splice : null;
    if (splice) {
      if (splice.twist < 1) {
        this.drag = {
          kind: 'twist',
          id: splice.id,
          lastAngle: Math.atan2(p.y - splice.point.y, p.x - splice.point.x),
        };
        return;
      }
      if (this.shockOnTouch(splice.members)) return;
      this.drag = { kind: 'splice', id: splice.id, offset: sub(splice.point, p) };
      this.emit({ type: 'pickup' });
      return;
    }

    if (!end) return;
    if (this.shockOnTouch([end.conductor.id])) return;
    if (end.spliceId) this.leaveSplice(end.conductor.id);
    this.drag = { kind: 'end', id: end.conductor.id, offset: sub(end.end, p) };
    this.emit({ type: 'pickup' });
  }

  pointerMove(p: Vec2): void {
    this.pointer = p;
    const drag = this.drag;

    if (!drag) {
      this.hover = this.spliceAt(p)?.splice.id ?? this.endAt(p)?.conductor.id ?? null;
      return;
    }

    switch (drag.kind) {
      case 'end': {
        const runtime = this.conductor(drag.id);
        runtime.end = this.reach(runtime, add(p, drag.offset));
        break;
      }
      case 'splice': {
        const splice = this.splices.get(drag.id);
        if (splice) this.moveSplice(splice, add(p, drag.offset));
        break;
      }
      case 'twist': {
        const splice = this.splices.get(drag.id);
        if (!splice) break;
        const angle = Math.atan2(p.y - splice.point.y, p.x - splice.point.x);
        let delta = angle - drag.lastAngle;
        if (delta > Math.PI) delta -= Math.PI * 2;
        if (delta < -Math.PI) delta += Math.PI * 2;
        drag.lastAngle = angle;
        // Righty-tighty: only clockwise motion (positive in screen space) seats the connector.
        if (delta > 0)
          splice.twist = Math.min(1, splice.twist + delta / (Math.PI * 2 * TWIST_TURNS));
        if (splice.twist >= 1) this.finishTwist(splice);
        break;
      }
      case 'held':
        if (drag.held.kind === 'tool' && drag.held.tool === 'tester') this.updateTester(p);
        break;
      default:
        break;
    }
    this.updateGeometry();
  }

  pointerUp(p: Vec2): void {
    this.pointer = p;
    const drag = this.drag;
    this.drag = null;
    if (!drag) return;

    if (drag.kind === 'end') this.dropEnd(drag.id);
    if (drag.kind === 'held') this.dropHeld(drag.held, p);
    this.testerLevel = 0;
    this.updateGeometry();
  }

  /** Releases whatever is held without using it, e.g. when focus is lost. */
  cancel(): void {
    this.drag = null;
    this.held = null;
    this.testerLevel = 0;
  }

  toggleBreaker(): void {
    this.breakerOn = !this.breakerOn;
    this.log({ t: this.now(), a: 'breaker', on: this.breakerOn });
    this.emit({ type: 'breaker', on: this.breakerOn });
    this.refresh();
  }

  toggleSwitch(): void {
    this.switchOn = !this.switchOn;
    this.log({ t: this.now(), a: 'switch', on: this.switchOn });
    this.emit({ type: 'switch', on: this.switchOn });
    this.refresh();
  }

  /**
   * Strips a damaged conductor with the chosen stripper notch.
   *
   * @param id - Conductor to strip
   * @param notch - AWG size of the stripper notch the player picked
   */
  strip(id: string, notch: number): void {
    const runtime = this.conductor(id);
    const at = runtime.end;
    this.log({ t: this.now(), a: 'strip', id, notch });
    if (notch === runtime.conductor.awg) {
      this.stripped.add(id);
      this.emit({ type: 'stripped', at });
    } else if (notch > runtime.conductor.awg) {
      // Higher AWG number = smaller hole: the blades bite into the copper.
      this.addMistake();
      this.emit({ type: 'strip-nicked', at });
    } else {
      this.emit({ type: 'strip-slipped', at });
    }
  }

  /**
   * Runs the final inspection.
   *
   * @returns Findings; empty when the job passes
   */
  inspect(): Issue[] {
    this.log({ t: this.now(), a: 'inspect' });
    const issues = evaluateWiring(this.puzzle, this.state);
    const refs = new Set<string>();
    for (const issue of issues) for (const ref of issue.refs) refs.add(ref);
    this.highlighted = refs;
    return issues;
  }

  /** Counts a mistake and reports the new total. */
  addMistake(): void {
    this.mistakes += 1;
    this.emit({ type: 'mistake', count: this.mistakes });
  }

  private now(): number {
    return Math.round(performance.now() - this.startedAt);
  }

  private log(action: WiringAction): void {
    this.actions.push(action);
  }

  private simulate(): Simulation {
    return simulateWiring(this.puzzle, this.state, {
      breakerOn: this.breakerOn,
      switchOn: this.switchOn,
    });
  }

  /** Re-runs the simulation after a change and trips the breaker on a short. */
  private refresh(): void {
    this.simulation = this.simulate();
    if (!this.simulation.shorted) return;

    const at = this.lastSplicePoint();
    this.breakerOn = false;
    this.addMistake();
    this.emit({ type: 'short', at });
    this.emit({ type: 'breaker', on: false });
    this.simulation = this.simulate();
  }

  private lastSplicePoint(): Vec2 {
    let point = vec((BOX_INNER.left + BOX_INNER.right) / 2, (BOX_INNER.top + BOX_INNER.bottom) / 2);
    for (const splice of this.splices.values()) point = splice.point;
    return point;
  }

  /** Grabbing live bare copper hurts. Returns true when the touch was a shock. */
  private shockOnTouch(ids: readonly string[]): boolean {
    const live = ids.find(
      (id: string): boolean => this.simulation.energized.has(id) && this.isExposed(id),
    );
    if (!live) return false;
    this.log({ t: this.now(), a: 'shock', id: live });
    this.addMistake();
    this.emit({ type: 'shock', at: this.conductor(live).end });
    return true;
  }

  /** Free or loosely bundled conductor end under the pointer; ends inside a nut are held. */
  private endAt(p: Vec2): ConductorRuntime | null {
    let best: ConductorRuntime | null = null;
    let bestDistance = Infinity;
    for (const runtime of this.conductors) {
      if (runtime.spliceId !== null && this.splices.get(runtime.spliceId)?.nut) continue;
      const d = distance(runtime.end, p);
      const radius = Math.max(PICK_RADIUS, runtime.layout.width);
      if (d < radius && d < bestDistance) {
        best = runtime;
        bestDistance = d;
      }
    }
    return best;
  }

  /** Nutted splice under the pointer and how far the pointer is from the nut's axis. */
  private spliceAt(p: Vec2): { splice: SpliceRuntime; distance: number } | null {
    let best: { splice: SpliceRuntime; distance: number } | null = null;
    for (const splice of this.splices.values()) {
      if (splice.nut === null) continue;
      const length = NUT_LENGTH[splice.nut];
      const center = nutCenter(splice);
      const d = distanceToSegment(
        p,
        add(center, scale(splice.direction, -length * 0.45)),
        add(center, scale(splice.direction, length * 0.42)),
      );
      if (d < length * 0.24 && (!best || d < best.distance)) best = { splice, distance: d };
    }
    return best;
  }

  /** Keeps an end within the free length of its conductor and on the stage. */
  private reach(runtime: ConductorRuntime, target: Vec2): Vec2 {
    const { anchor, length } = runtime.layout;
    const bounded = vec(
      Math.min(WORK_AREA.right, Math.max(WORK_AREA.left, target.x)),
      Math.min(WORK_AREA.bottom, Math.max(WORK_AREA.top, target.y)),
    );
    const offset = sub(bounded, anchor);
    const span = Math.hypot(offset.x, offset.y);
    const max = length * 0.92;
    return span <= max ? bounded : add(anchor, scale(offset, max / span));
  }

  private dropEnd(id: string): void {
    const runtime = this.conductor(id);
    const splice = [...this.splices.values()].find(
      (s: SpliceRuntime): boolean =>
        s.nut === null && distance(s.point, runtime.end) < SPLICE_RADIUS,
    );
    if (splice) {
      this.joinSplice(splice, [id]);
      return;
    }

    const partner = this.conductors.find(
      (other: ConductorRuntime): boolean =>
        other !== runtime &&
        other.spliceId === null &&
        distance(other.end, runtime.end) < JOIN_RADIUS,
    );
    if (partner) {
      const created: SpliceRuntime = {
        id: `s${this.nextSpliceId++}`,
        members: [],
        point: partner.end,
        direction: partner.endDirection,
        nut: null,
        twist: 0,
      };
      this.splices.set(created.id, created);
      this.joinSplice(created, [partner.conductor.id, id]);
    }
  }

  private joinSplice(splice: SpliceRuntime, ids: readonly string[]): void {
    for (const id of ids) {
      splice.members.push(id);
      this.conductor(id).spliceId = splice.id;
    }
    this.log({ t: this.now(), a: 'join', ids: splice.members.slice() });
    this.arrangeSplice(splice);
    this.emit({ type: 'joined', at: splice.point });
  }

  private leaveSplice(id: string): void {
    const runtime = this.conductor(id);
    const splice = runtime.spliceId ? this.splices.get(runtime.spliceId) : undefined;
    runtime.spliceId = null;
    if (!splice) return;

    splice.members = splice.members.filter((member: string): boolean => member !== id);
    this.log({ t: this.now(), a: 'part', id });
    if (splice.members.length < 2) {
      for (const member of splice.members) this.conductor(member).spliceId = null;
      this.splices.delete(splice.id);
    } else {
      this.arrangeSplice(splice);
    }
    this.emit({ type: 'parted' });
  }

  /** Lines the bundled ends up side by side, pointing into the connector. */
  private arrangeSplice(splice: SpliceRuntime): void {
    const members = splice.members.map((id: string): ConductorRuntime => this.conductor(id));
    let cx = 0;
    let cy = 0;
    for (const member of members) {
      cx += member.layout.anchor.x;
      cy += member.layout.anchor.y;
    }
    const centroid = vec(cx / members.length, cy / members.length);
    const outward = sub(splice.point, centroid);
    splice.direction =
      Math.hypot(outward.x, outward.y) > 20 ? normalize(outward) : splice.direction;

    const across = perpendicular(splice.direction);
    const widths = members.map((m: ConductorRuntime): number => m.layout.width * 0.72);
    const total = widths.reduce((sum: number, w: number): number => sum + w, 0);
    let cursor = -total / 2;
    members.forEach((member: ConductorRuntime, i: number): void => {
      const w = widths[i] as number;
      member.end = this.reach(member, add(splice.point, scale(across, cursor + w / 2)));
      member.endDirection = splice.direction;
      cursor += w;
    });
  }

  private moveSplice(splice: SpliceRuntime, target: Vec2): void {
    let point = target;
    // Pull the bundle back toward any conductor that would be overstretched.
    for (let pass = 0; pass < 3; pass++) {
      for (const id of splice.members) {
        const layout = this.conductor(id).layout;
        const offset = sub(point, layout.anchor);
        const span = Math.hypot(offset.x, offset.y);
        const max = layout.length * 0.9;
        if (span > max) point = add(layout.anchor, scale(offset, max / span));
      }
    }
    splice.point = point;
    this.arrangeSplice(splice);
  }

  private finishTwist(splice: SpliceRuntime): void {
    this.drag = null;
    const color = splice.nut as NutColor;
    this.log({ t: this.now(), a: 'nut', splice: splice.members.slice(), color });
    this.emit({ type: 'nut-tight', at: splice.point });
    this.refresh();
  }

  private secondaryAction(p: Vec2): void {
    if (this.held) {
      this.cancel();
      return;
    }
    const splice = this.spliceAt(p)?.splice;
    if (!splice || splice.nut === null) return;
    if (this.shockOnTouch(splice.members)) return;
    const wasTight = splice.twist >= 1;
    splice.nut = null;
    splice.twist = 0;
    if (wasTight) this.log({ t: this.now(), a: 'unnut', splice: splice.members.slice() });
    this.emit({ type: 'nut-removed', at: splice.point });
    this.refresh();
  }

  private dropHeld(held: Held, p: Vec2): void {
    this.held = null;
    if (held.kind === 'nut') {
      this.dropNut(held.color, p);
      return;
    }
    switch (held.tool) {
      case 'stripper':
        this.dropStripper(p);
        break;
      case 'tape':
        this.dropTape(p);
        break;
      case 'tester':
      default:
        break;
    }
  }

  private dropNut(color: NutColor, p: Vec2): void {
    const splice = [...this.splices.values()].find(
      (s: SpliceRuntime): boolean => distance(s.point, p) < SPLICE_RADIUS + 14,
    );
    if (!splice) return;
    if (splice.nut !== null) {
      this.emit({ type: 'nut-rejected', reason: 'occupied', at: splice.point });
      return;
    }
    const members = splice.members.map((id: string): Conductor => this.conductor(id).conductor);
    if (!nutFits(color, members)) {
      this.emit({
        type: 'nut-rejected',
        reason: members.length < 2 ? 'single' : 'too-small',
        at: splice.point,
      });
      return;
    }
    if (this.shockOnTouch(splice.members)) return;
    splice.nut = color;
    splice.twist = 0;
    this.emit({ type: 'nut-seated', at: splice.point });
  }

  private nearestEnd(
    p: Vec2,
    range: number,
    filter: (runtime: ConductorRuntime) => boolean,
  ): ConductorRuntime | null {
    let best: ConductorRuntime | null = null;
    let bestDistance = range;
    for (const runtime of this.conductors) {
      if (!filter(runtime)) continue;
      const d = distance(runtime.end, p);
      if (d < bestDistance) {
        best = runtime;
        bestDistance = d;
      }
    }
    return best;
  }

  private dropStripper(p: Vec2): void {
    const target = this.nearestEnd(
      p,
      60,
      (r: ConductorRuntime): boolean => r.conductor.insulation !== 'bare' && r.spliceId === null,
    );
    if (!target) return;
    if (!target.conductor.needsStrip || this.stripped.has(target.conductor.id)) {
      this.emit({ type: 'not-damaged', at: target.end });
      return;
    }
    if (this.shockOnTouch([target.conductor.id])) return;
    this.emit({ type: 'strip-request', conductorId: target.conductor.id, at: target.end });
  }

  private dropTape(p: Vec2): void {
    let best: ConductorRuntime | null = null;
    let bestDistance = TAPE_RANGE;
    for (const runtime of this.conductors) {
      if (runtime.conductor.insulation === 'bare' || runtime.conductor.stranded) continue;
      const d = distanceToPolyline(runtime.line, p.x, p.y);
      if (d < bestDistance) {
        best = runtime;
        bestDistance = d;
      }
    }
    if (!best || this.taped.has(best.conductor.id) || best.conductor.marked) return;
    this.taped.add(best.conductor.id);
    this.log({ t: this.now(), a: 'tape', id: best.conductor.id });
    this.emit({ type: 'taped', at: p });
    this.refresh();
  }

  private updateTester(p: Vec2): void {
    let nearest = Infinity;
    for (const runtime of this.conductors) {
      if (!this.simulation.energized.has(runtime.conductor.id)) continue;
      nearest = Math.min(nearest, distanceToPolyline(runtime.line, p.x, p.y));
    }
    for (const cable of this.layout.cables) {
      if (!cable.entry) continue;
      const live = this.puzzle.cables
        .find((c): boolean => c.id === cable.cableId)
        ?.conductorIds.some((id: string): boolean => this.simulation.energized.has(id));
      if (!live) continue;
      const mid = vec(
        (cable.entry.x + cable.sheathEnd.x) / 2,
        (cable.entry.y + cable.sheathEnd.y) / 2,
      );
      nearest = Math.min(nearest, Math.max(0, distance(mid, p) - cable.width / 2));
    }
    this.testerLevel = nearest >= TESTER_RANGE ? 0 : 1 - nearest / TESTER_RANGE;
  }
}
