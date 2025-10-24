import type { NuiCallbackResponse } from '../types/nui';
import { getResourceName, isEnvBrowser } from '../types/nui';

/**
 * Sends a message to the FiveM game client via NUI callback
 * Handles communication between the UI and Lua scripts
 * @template T - Expected response data type
 * @param {string} eventName - The NUI callback event name registered in Lua
 * @param {unknown} data - Data to send with the request
 * @returns {Promise<T>} Response from the game client
 * @throws {Error} If the request fails or server returns an error
 * @example
 * // Call a Lua RegisterNUICallback
 * const result = await fetchNui<{ success: boolean }>('getPlayerData', { id: 1 });
 * if (result.success) {
 *   console.log('Player data retrieved');
 * }
 */
export async function fetchNui<T = unknown>(
  eventName: string,
  data: unknown = {}
): Promise<T> {
  const resourceName = getResourceName();

  if (isEnvBrowser()) {
    console.warn(
      `[fetchNui] Browser environment detected. Event: ${eventName}`,
      data
    );
    return {} as T;
  }

  try {
    const response = await fetch(`https://${resourceName}/${eventName}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: JSON.stringify(data),
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const responseData: NuiCallbackResponse<T> = await response.json();

    if (!responseData.ok && responseData.error) {
      throw new Error(responseData.error);
    }

    return responseData.data as T;
  } catch (error) {
    console.error(`[fetchNui] Error calling ${eventName}:`, error);
    throw error;
  }
}
