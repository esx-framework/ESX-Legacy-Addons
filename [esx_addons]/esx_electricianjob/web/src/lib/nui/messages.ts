/**
 * Message contract between the Lua client script and the NUI page.
 *
 * Lua sends {@link NuiMessage} objects through SendNUIMessage; the page answers through the
 * `finish` NUI callback with a {@link FinishPayload}. Everything coming in is validated here
 * before the rest of the UI sees it.
 *
 * @see parseNuiMessage
 */

/** The four minigames the resource ships. */
export type GameKind = 'wiring' | 'circuit' | 'fuse' | 'voltage';

/** All game kinds, in the order they are presented in the dev harness. */
export const GAME_KINDS: readonly GameKind[] = ['wiring', 'circuit', 'fuse', 'voltage'];

/** Difficulty tier: 1 = apprentice, 2 = journeyman, 3 = master electrician. */
export type Difficulty = 1 | 2 | 3;

/** Largest seed value; seeds are unsigned 32-bit integers so Lua and JS agree on them. */
export const MAX_SEED = 0xffffffff;

/** One round of a minigame, created by the server. */
export interface GameSession {
  /** Opaque id the server uses to match the result to the round it handed out */
  id: string;
  /** Which minigame to run */
  game: GameKind;
  /** Seed for the puzzle generator; the same seed always produces the same round */
  seed: number;
  /** Difficulty tier */
  difficulty: Difficulty;
}

/** Starts a round. */
export interface OpenMessage {
  /** Discriminator */
  action: 'open';
  /** Round to start */
  session: GameSession;
}

/** Closes the UI without a result, e.g. when the player is moved away by the server. */
export interface CloseMessage {
  /** Discriminator */
  action: 'close';
}

/** Any message Lua can send to the page. */
export type NuiMessage = OpenMessage | CloseMessage;

/** How a round ended. */
export type GameOutcome = 'success' | 'failure' | 'aborted';

/** Body of the `finish` NUI callback. */
export interface FinishPayload<TAction> {
  /** Id of the session that ended */
  sessionId: string;
  /** Result as seen by the client; the server re-checks it from {@link actions} */
  outcome: GameOutcome;
  /** Wall time from opening the round to the result, in milliseconds */
  durationMs: number;
  /** Ordered player actions, enough for the server to replay and verify the round */
  actions: readonly TAction[];
}

const SESSION_ID_PATTERN = /^[\w-]{1,64}$/;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function isGameKind(value: unknown): value is GameKind {
  return typeof value === 'string' && (GAME_KINDS as readonly string[]).includes(value);
}

function isDifficulty(value: unknown): value is Difficulty {
  return value === 1 || value === 2 || value === 3;
}

function isSeed(value: unknown): value is number {
  return typeof value === 'number' && Number.isInteger(value) && value >= 0 && value <= MAX_SEED;
}

function parseSession(value: unknown): GameSession | undefined {
  if (!isRecord(value)) return undefined;
  const { id, game, seed, difficulty } = value;
  if (typeof id !== 'string' || !SESSION_ID_PATTERN.test(id)) return undefined;
  if (!isGameKind(game) || !isSeed(seed) || !isDifficulty(difficulty)) return undefined;
  return { id, game, seed, difficulty };
}

/**
 * Validates raw `message` event data.
 *
 * @param data - `event.data` of a window message event
 * @returns The typed message, or undefined if the data is not a valid message
 */
export function parseNuiMessage(data: unknown): NuiMessage | undefined {
  if (!isRecord(data)) return undefined;

  switch (data.action) {
    case 'open': {
      const session = parseSession(data.session);
      return session ? { action: 'open', session } : undefined;
    }
    case 'close':
      return { action: 'close' };
    default:
      return undefined;
  }
}
