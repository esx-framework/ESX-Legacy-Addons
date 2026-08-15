import { isInGame } from './nui';

/**
 * Send mock data for development testing
 * Only works when not in game
 */
export function debugData<T = any>(eventName: string, data: T, delay = 500): void {
  // Only send debug data in development
  if (!isInGame()) {
    setTimeout(() => {
      window.postMessage(
        {
          type: eventName,
          payload: data
        },
        '*'
      );
    }, delay);
  }
}

/**
 * Enable debug logging
 */
export const enableDebugMode = (): void => {
  localStorage.setItem('debug', 'true');
  console.log('🔧 Debug mode enabled');
};

/**
 * Disable debug logging
 */
export const disableDebugMode = (): void => {
  localStorage.removeItem('debug');
  console.log('🔧 Debug mode disabled');
};

/**
 * Check if debug mode is enabled
 */
export const isDebugMode = (): boolean => {
  return localStorage.getItem('debug') === 'true';
};

/**
 * Debug logger that only logs when debug mode is enabled
 */
export const debugLog = (...args: any[]): void => {
  if (isDebugMode()) {
    console.log('[DEBUG]', ...args);
  }
};

// Log all NUI events when debug mode is enabled
if (isDebugMode()) {
  window.addEventListener('message', (event) => {
    debugLog('NUI Event:', event.data);
  });
}