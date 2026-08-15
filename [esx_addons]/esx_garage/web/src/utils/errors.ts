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
  self: 'You already own this vehicle.',
  spawn_failed: 'The vehicle could not be spawned.',
  target_offline: 'That player is not online.',
  too_far: 'You are too far from the garage.',
  use_impound: 'This vehicle can only be recovered from an impound.',
  wrong_garage: 'This vehicle is parked in another garage.',
};

export const errorMessage = (error: unknown, fallback = 'Something went wrong.'): string => {
  const code = error instanceof Error ? error.message : String(error ?? '');
  return ERROR_MESSAGES[code] ?? fallback;
};
