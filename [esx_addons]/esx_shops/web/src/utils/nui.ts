/**
 * NUI Communication utilities for FiveM
 */

/**
 * NUI error types
 */
export type NuiErrorCode = 'TIMEOUT' | 'NETWORK' | 'SERVER' | 'ABORTED' | 'UNKNOWN';

/**
 * NUI error structure
 */
export interface NuiError {
  code: NuiErrorCode;
  message: string;
  details?: unknown;
}

/**
 * NUI response structure
 */
export interface NuiResponse<T = unknown> {
  ok: boolean;
  data?: T;
  error?: NuiError;
}

/**
 * Fetch options for NUI requests
 */
export interface FetchNuiOptions {
  timeout?: number;
  signal?: AbortSignal;
}

/**
 * Window interface extension for FiveM
 */
declare global {
  interface Window {
    GetParentResourceName?: () => string;
  }
}

/**
 * Checks if running in browser (development) or FiveM
 * @returns True if in browser, false if in FiveM
 */
export const isEnvBrowser = (): boolean => !window.GetParentResourceName;

/**
 * Sends a message to the NUI (Lua side) and awaits response
 * @param eventName - NUI callback event name
 * @param data - Data to send with the event
 * @param options - Additional fetch options (timeout, signal)
 * @returns Promise with response data
 */
export async function fetchNui<T = unknown>(
  eventName: string,
  data: Record<string, unknown> = {},
  options: FetchNuiOptions = {}
): Promise<NuiResponse<T>> {
  const { timeout = 5000, signal } = options;

  // Development mode mock
  if (isEnvBrowser()) {
    console.log(`[DEV] NUI Event: ${eventName}`, data);
    return new Promise((resolve) => {
      setTimeout(() => resolve({ ok: true }), 100);
    });
  }

  const controller = new AbortController();
  const resourceName = window.GetParentResourceName?.() ?? 'esx_shops';

  // Setup timeout
  const timeoutId = setTimeout(() => controller.abort(), timeout);

  // Combine signals if external signal provided
  if (signal) {
    signal.addEventListener('abort', () => controller.abort());
  }

  try {
    const response = await fetch(`https://${resourceName}/${eventName}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=UTF-8'
      },
      body: JSON.stringify(data),
      signal: controller.signal
    });

    clearTimeout(timeoutId);

    // Check HTTP status
    if (!response.ok) {
      return {
        ok: false,
        error: {
          code: 'SERVER',
          message: `HTTP ${response.status}: ${response.statusText}`,
          details: { status: response.status, statusText: response.statusText }
        }
      };
    }

    // Parse JSON response
    const json = await response.json() as T;
    return { ok: true, data: json };

  } catch (error) {
    clearTimeout(timeoutId);

    // Handle different error types
    if (error instanceof Error) {
      if (error.name === 'AbortError') {
        return {
          ok: false,
          error: {
            code: signal?.aborted ? 'ABORTED' : 'TIMEOUT',
            message: signal?.aborted ? 'Request cancelled' : 'Request timeout',
            details: error
          }
        };
      }

      // Network or other errors
      return {
        ok: false,
        error: {
          code: 'NETWORK',
          message: error.message || 'Network error occurred',
          details: error
        }
      };
    }

    // Unknown error type
    console.error(`NUI fetch error for ${eventName}:`, error);
    return {
      ok: false,
      error: {
        code: 'UNKNOWN',
        message: 'An unknown error occurred',
        details: error
      }
    };
  }
}

/**
 * Message event handler callback
 */
type MessageHandler = (data: Record<string, unknown>) => void;

/**
 * Registers a listener for NUI messages from Lua
 * @param callback - Function to call when message received
 * @returns Cleanup function to remove listener
 */
export function onNuiMessage(callback: MessageHandler): () => void {
  const handler = (event: MessageEvent<Record<string, unknown>>): void => {
    callback(event.data);
  };

  window.addEventListener('message', handler);

  return () => window.removeEventListener('message', handler);
}

/**
 * Sends close UI event to Lua
 */
export function closeUI(): void {
  fetchNui('closeUI');
}

/**
 * Keyboard event handler callback
 */
type KeyHandler = () => void;

/**
 * Registers ESC key listener to close UI
 * @param callback - Function to call on ESC press
 * @returns Cleanup function to remove listener
 */
export function registerEscapeListener(callback: KeyHandler): () => void {
  const handler = (event: KeyboardEvent): void => {
    if (event.key === 'Escape') {
      event.preventDefault();
      callback();
    }
  };

  window.addEventListener('keydown', handler);

  return () => window.removeEventListener('keydown', handler);
}
