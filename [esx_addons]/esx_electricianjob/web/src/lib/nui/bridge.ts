/**
 * Transport between the page and the Lua side of the resource.
 *
 * In game, CEF exposes `GetParentResourceName` and NUI callbacks are plain POST requests to
 * `https://<resource>/<callback>`. Outside the game (vite dev server) callbacks are logged
 * instead, so the UI can be developed in a normal browser.
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
    if (import.meta.env.DEV) console.info(`[nui] ${callback}`, payload);
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
 * Subscribes to messages sent by SendNUIMessage. Invalid messages are dropped.
 *
 * @param handler - Called for every valid message
 * @returns Function that removes the listener
 */
export function onNuiMessage(handler: (message: NuiMessage) => void): () => void {
  const listener = (event: MessageEvent<unknown>): void => {
    const message: NuiMessage | undefined = parseNuiMessage(event.data);
    if (message) handler(message);
  };
  window.addEventListener('message', listener);
  return (): void => window.removeEventListener('message', listener);
}
