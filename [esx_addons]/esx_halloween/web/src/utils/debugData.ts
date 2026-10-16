import type { NuiMessage, DebugOptions } from '../types/nui';
import { isEnvBrowser } from '../types/nui';

/**
 * Dispatches mock NUI events for testing in browser environment
 * Simulates SendNUIMessage calls from FiveM for development purposes
 * @template T - Type of data to send
 * @param {string} action - The action/event name to trigger
 * @param {T} data - Mock data payload to send
 * @param {number} delay - Delay in milliseconds before dispatching (default: 100)
 * @returns {void}
 * @example
 * // Simulate showing UI after 1 second
 * debugData('showUI', { visible: true }, 1000);
 *
 * // Simulate player data update
 * debugData('setPlayerData', { name: 'TestPlayer', health: 100 });
 */
export function debugData<T = unknown>(
  action: string,
  data: T,
  delay = 100
): void {
  if (!isEnvBrowser()) {
    console.warn('[debugData] Only works in browser environment');
    return;
  }

  setTimeout(() => {
    const message: NuiMessage<T> = {
      action,
      data,
    };

    window.dispatchEvent(
      new MessageEvent('message', {
        data: message,
      })
    );

    console.log(`[debugData] Dispatched event: ${action}`, data);
  }, delay);
}

/**
 * Sets up debug events on component mount for browser development
 * Allows testing NUI functionality without running in FiveM
 * @param {DebugOptions} options - Debug configuration
 * @param {() => void} callback - Function to execute with debug setup
 * @returns {void}
 * @example
 * setupDebugData({ enabled: true, delay: 1000 }, () => {
 *   debugData('showUI', {});
 *   debugData('setPlayerData', { name: 'Dev', id: 1 }, 2000);
 * });
 */
export function setupDebugData(
  options: DebugOptions,
  callback: () => void
): void {
  if (!options.enabled || !isEnvBrowser()) {
    return;
  }

  setTimeout(() => {
    console.log('[debugData] Setting up debug data...');
    callback();
  }, options.delay || 100);
}
