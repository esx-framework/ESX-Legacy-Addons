/**
 * Transport between the page and the Lua side of the resource.
 *
 * In game, CEF exposes `GetParentResourceName` and NUI callbacks are plain POST requests to
 * `https://<resource>/<callback>`. Outside the game the callbacks go to the handler set with
 * {@link answerOffline}, so the page can play both sides in a normal browser.
 *
 * @see onNuiMessage
 * @see postNui
 */

import { parseNuiMessage, type NuiMessage } from './messages';

declare global {
  interface Window {
    /** Injected by FiveM's CEF; returns the name of the resource that owns the page. */
    GetParentResourceName?: () => string;
  }
}

/** Raised when Lua does not acknowledge a NUI callback. */
export class NuiCallbackError extends Error {
  constructor(
    readonly callback: string,
    readonly status: number,
  ) {
    super(`NUI callback "${callback}" failed with HTTP ${status}`);
    this.name = 'NuiCallbackError';
  }
}

/** Answers callbacks outside the game, in place of Lua. */
export type OfflineHandler = (callback: string, payload: unknown) => void;

let offlineHandler: OfflineHandler | null = null;

/**
 * Routes the NUI callbacks to a handler while the page runs outside the game.
 *
 * @param handler - Stand-in for the Lua client script
 */
export function answerOffline(handler: OfflineHandler): void {
  offlineHandler = handler;
}

/**
 * Whether the page runs inside FiveM.
 *
 * @returns True in game, false in a regular browser
 */
export function isInGame(): boolean {
  return typeof window.GetParentResourceName === 'function';
}

/**
 * Sends a NUI callback to the Lua client script.
 *
 * @param callback - Name registered with RegisterNUICallback
 * @param payload - JSON-serialisable body
 * @returns The parsed JSON the Lua callback answered with, undefined outside the game
 * @throws {NuiCallbackError} When the callback request does not succeed
 */
export async function postNui(callback: string, payload: unknown): Promise<unknown> {
  const resource: string | undefined = window.GetParentResourceName?.();
  if (resource === undefined) {
    offlineHandler?.(callback, payload);
    return undefined;
  }

  const response: Response = await fetch(`https://${resource}/${callback}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new NuiCallbackError(callback, response.status);
  return response.json() as Promise<unknown>;
}

/**
 * Subscribes to messages sent by SendNUIMessage.
 *
 * @param handler - Called for every valid message
 * @param onRefused - Called with the raw data of every invalid message
 * @returns Function that removes the listener
 */
export function onNuiMessage(
  handler: (message: NuiMessage) => void,
  onRefused: (data: unknown) => void,
): () => void {
  const listener = (event: MessageEvent<unknown>): void => {
    const message: NuiMessage | undefined = parseNuiMessage(event.data);
    if (message) handler(message);
    else onRefused(event.data);
  };
  window.addEventListener('message', listener);
  return (): void => window.removeEventListener('message', listener);
}
