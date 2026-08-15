import type { NuiCallbackResponse } from '@/types/nui.types';

/**
 * Checks if the code is running inside FiveM or in a regular browser.
 *
 * @returns {boolean} True if running in FiveM, false if in browser
 */
export const isInGame = (): boolean => {
  // @ts-ignore - GetParentResourceName is a FiveM native function
  return typeof GetParentResourceName !== 'undefined';
};

/**
 * Gets the current resource name for constructing NUI callback URLs.
 * Falls back to 'esx_garages' in development mode.
 *
 * @returns {string} The resource name
 */
const getResourceName = (): string => {
  if (isInGame()) {
    // @ts-ignore - GetParentResourceName is a FiveM native function
    return GetParentResourceName();
  }
  // Development fallback
  return 'esx_garages';
};

/**
 * Sends a fetch request to the FiveM client via NUI callback.
 * In development mode, returns mock data if provided.
 *
 * @template T - Expected response type
 * @param {string} eventName - The NUI callback event name
 * @param {unknown} data - Data to send to the callback
 * @param {T} mockData - Mock data to return in development mode
 * @returns {Promise<T>} The response data
 * @throws {Error} If the callback fails or returns an error
 *
 * @example
 * ```typescript
 * const result = await fetchNui<boolean>('garage:retrieveVehicle', { vehicleId: '1' });
 * if (result) {
 *   console.log('Vehicle retrieved successfully');
 * }
 * ```
 */
export async function fetchNui<T = unknown>(
  eventName: string,
  data?: unknown,
  mockData?: T
): Promise<T> {
  // In development, return mock data if provided
  if (!isInGame() && mockData !== undefined) {
    await new Promise((resolve) => setTimeout(resolve, 100)); // Simulate network delay
    return mockData;
  }

  const resourceName = getResourceName();
  const url = `https://${resourceName}/${eventName}`;

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(data || {}),
    });

    const result: NuiCallbackResponse<T> = await response.json();

    if (!result.success) {
      throw new Error(result.error || 'Unknown error occurred');
    }

    return result.data as T;
  } catch (error) {
    console.error(`fetchNui error for ${eventName}:`, error);
    throw error;
  }
}

/**
 * Sends a message to close the NUI interface.
 * Triggers the 'closeUI' callback on the game client.
 */
export const closeNui = (): void => {
  fetchNui('closeUI', {}, true).catch(console.error);
};

/**
 * Sends a notification message to the game client.
 * The game client should display this as a toast notification.
 *
 * @param {string} message - The notification message
 * @param {'success' | 'error' | 'info'} type - The notification type
 */
export const sendNotification = (
  message: string,
  type: 'success' | 'error' | 'info' = 'info'
): void => {
  fetchNui('notification', { message, type }, true).catch(console.error);
};
