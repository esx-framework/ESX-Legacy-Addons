/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

/**
 * Maps the snake_case error codes returned by the Lua callbacks to text a
 * player can actually read. Anything unknown falls back to a generic line so a
 * raw code never reaches the UI.
 */
const ERROR_MESSAGES: Record<string, string> = {
  already_stored: 'This vehicle is already stored.',
  bad_spawn: 'That spawn point does not belong to this garage.',
  blocked: 'Every spawn point is blocked right now.',
  busy: 'This vehicle is already being handled, try again.',
  disabled: 'This feature is disabled on this server.',
  invalid: 'Invalid request.',
  no_location: 'You are not at a garage.',
  no_money: 'You cannot afford this.',
  no_vehicle: 'You are not in a vehicle.',
  not_allowed: 'You do not have access to this garage.',
  not_owned: 'This vehicle is not yours.',
  not_stored: 'This vehicle is not stored.',
  plate_mismatch: 'That is not the vehicle for this plate.',
  player: 'Player not found.',
  rate_limited: 'Please wait a moment before trying again.',
  self: 'You already own this vehicle.',
  spawn_failed: 'The vehicle could not be spawned.',
  state_changed: 'Vehicle state changed, reopen the garage.',
  target_offline: 'That player is not online.',
  too_far: 'You are too far from the garage.',
  use_impound: 'This vehicle can only be recovered from an impound.',
  wrong_garage: 'This vehicle is parked in another garage.',
};

let lastQuietNotificationAt = 0;
const QUIET_ERROR_CODES = new Set(['rate_limited', 'busy']);

export const errorCode = (error: unknown): string => (
  error instanceof Error ? error.message : String(error ?? '')
);

export const isErrorCode = (error: unknown, code: string): boolean => errorCode(error) === code;
export const isQuietErrorCode = (error: unknown): boolean => QUIET_ERROR_CODES.has(errorCode(error));

export const errorMessage = (error: unknown, fallback = 'Something went wrong.'): string => {
  return ERROR_MESSAGES[errorCode(error)] ?? fallback;
};

export const showErrorNotification = (error: unknown, fallback?: string): void => {
  const code = errorCode(error);
  if (QUIET_ERROR_CODES.has(code)) {
    const now = Date.now();
    if (now - lastQuietNotificationAt < 1200) {
      return;
    }

    lastQuietNotificationAt = now;
  }

  window.postMessage({
    type: 'showNotification',
    payload: {
      message: errorMessage(error, fallback),
      type: 'error'
    }
  }, '*');
};
