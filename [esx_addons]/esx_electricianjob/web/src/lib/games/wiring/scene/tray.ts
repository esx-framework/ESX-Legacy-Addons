/**
 * Placement of the parts tray and tools next to the box, shared by engine, renderer and HUD.
 */

import { NUT_COLORS, type NutColor } from '../model';
import type { Area, ToolKind, TrayAreas } from '../engine';

/** Parts organizer holding the wire nuts. */
export const TRAY = { x: 1440, y: 236, width: 430, height: 430 * (438 / 920) } as const;

/** Inner compartments of the tray artwork, as fractions of its width. */
const COMPARTMENTS: readonly (readonly [number, number])[] = [
  [0.045, 0.335],
  [0.355, 0.645],
  [0.665, 0.955],
];

/** Where a tool rests while it is not in use. */
export interface ToolPlacement {
  /** Center x */
  x: number;
  /** Center y */
  y: number;
  /** Drawn width */
  width: number;
  /** Drawn height */
  height: number;
  /** Resting rotation in radians */
  angle: number;
}

/** Resting places of the tools below the tray. */
export const TOOL_PLACEMENT: Readonly<Record<ToolKind, ToolPlacement>> = {
  tester: { x: 1660, y: 560, width: 330, height: 330 * (130 / 720), angle: -0.06 },
  stripper: { x: 1650, y: 692, width: 360, height: 360 * (262 / 760), angle: 0.04 },
  tape: { x: 1520, y: 862, width: 150, height: 150 * (308 / 300), angle: 0 },
};

function toolArea(placement: ToolPlacement): Area {
  return {
    x: placement.x - placement.width / 2,
    y: placement.y - placement.height / 2 - 8,
    width: placement.width,
    height: placement.height + 16,
  };
}

/**
 * @param color - Connector size
 * @returns Stage rectangle of the compartment holding that size
 */
export function compartment(color: NutColor): Area {
  const [from, to] = COMPARTMENTS[NUT_COLORS.indexOf(color)] as readonly [number, number];
  return {
    x: TRAY.x + TRAY.width * from,
    y: TRAY.y + TRAY.height * 0.09,
    width: TRAY.width * (to - from),
    height: TRAY.height * 0.82,
  };
}

/** Hit areas handed to the engine. */
export const TRAY_AREAS: TrayAreas = {
  tools: {
    tester: toolArea(TOOL_PLACEMENT.tester),
    stripper: toolArea(TOOL_PLACEMENT.stripper),
    tape: toolArea(TOOL_PLACEMENT.tape),
  },
  nuts: {
    orange: compartment('orange'),
    yellow: compartment('yellow'),
    red: compartment('red'),
  },
};
