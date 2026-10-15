/**
 * Read-only view of the junction box scene for end-to-end tests.
 *
 * Only installed in `--mode e2e` builds (see WiringGame); production bundles never contain
 * it. Positions are CSS pixels relative to the page, ready for synthetic mouse events.
 *
 * @see installWiringProbe
 */

import type { Vec2 } from '../../core/vec';
import type { ConductorRuntime, SpliceRuntime, ToolKind, WiringEngine } from './engine';
import type { NutColor } from './model';
import type { StageTransform } from './scene/renderer';
import { TRAY_AREAS } from './scene/tray';

/** Conductor end as seen by a test. */
export interface ProbeEnd {
  /** Conductor id */
  id: string;
  /** Where the far end lands, e.g. `panel.hot` */
  terminal: string;
  /** Insulation color */
  insulation: string;
  /** Wire size in AWG */
  awg: number;
  /** Whether the end has to be stripped first */
  needsStrip: boolean;
  /** Whether the end shows bare copper */
  exposed: boolean;
  /** Re-identified as hot, either from the start or by the player */
  marked: boolean;
  /** Splice the end belongs to */
  spliceId: string | null;
  /** End position */
  x: number;
  /** End position */
  y: number;
  /** Fixed anchor of the conductor */
  anchorX: number;
  /** Fixed anchor of the conductor */
  anchorY: number;
  /** Farthest the end may be from its anchor, in CSS pixels */
  reach: number;
}

/** Splice as seen by a test. */
export interface ProbeSplice {
  /** Splice id */
  id: string;
  /** Joined conductor ids */
  members: readonly string[];
  /** Where the ends meet */
  x: number;
  /** Where the ends meet */
  y: number;
  /** Connector on the bundle */
  nut: NutColor | null;
  /** Twist progress, 1 = tight */
  twist: number;
}

/** Test access to the running round. */
export interface WiringProbe {
  /** All conductor ends */
  ends(): ProbeEnd[];
  /** All splices */
  splices(): ProbeSplice[];
  /** Center of a tool's resting place */
  tool(kind: ToolKind): Vec2;
  /** Center of a connector compartment */
  nuts(color: NutColor): Vec2;
  /** Scene units to CSS pixels */
  scale(): number;
}

declare global {
  interface Window {
    /** Installed by e2e builds only. */
    __wiringProbe?: WiringProbe;
  }
}

/**
 * Exposes the engine to end-to-end tests.
 *
 * @param engine - Running engine
 * @param canvas - Scene canvas, for its page offset
 * @param stage - Returns the current stage transform
 * @returns Function that removes the probe again
 */
export function installWiringProbe(
  engine: WiringEngine,
  canvas: HTMLCanvasElement,
  stage: () => StageTransform,
): () => void {
  const toPage = (p: Vec2): Vec2 => {
    const rect = canvas.getBoundingClientRect();
    const { scale, offsetX, offsetY } = stage();
    return { x: rect.left + offsetX + p.x * scale, y: rect.top + offsetY + p.y * scale };
  };
  const center = (area: { x: number; y: number; width: number; height: number }): Vec2 =>
    toPage({ x: area.x + area.width / 2, y: area.y + area.height / 2 });

  window.__wiringProbe = {
    ends: (): ProbeEnd[] =>
      engine.conductors.map((runtime: ConductorRuntime): ProbeEnd => {
        const end = toPage(runtime.end);
        const anchor = toPage(runtime.layout.anchor);
        return {
          id: runtime.conductor.id,
          terminal: runtime.conductor.terminal,
          insulation: runtime.conductor.insulation,
          awg: runtime.conductor.awg,
          needsStrip: runtime.conductor.needsStrip,
          exposed: engine.isExposed(runtime.conductor.id),
          marked: runtime.conductor.marked || engine.taped.has(runtime.conductor.id),
          spliceId: runtime.spliceId,
          x: end.x,
          y: end.y,
          anchorX: anchor.x,
          anchorY: anchor.y,
          reach: runtime.layout.length * 0.92 * stage().scale,
        };
      }),
    splices: (): ProbeSplice[] =>
      [...engine.splices.values()].map((splice: SpliceRuntime): ProbeSplice => {
        const point = toPage(splice.point);
        return {
          id: splice.id,
          members: splice.members.slice(),
          x: point.x,
          y: point.y,
          nut: splice.nut,
          twist: splice.twist,
        };
      }),
    tool: (kind: ToolKind): Vec2 => center(TRAY_AREAS.tools[kind]),
    nuts: (color: NutColor): Vec2 => center(TRAY_AREAS.nuts[color]),
    scale: (): number => stage().scale,
  };
  return (): void => {
    delete window.__wiringProbe;
  };
}
