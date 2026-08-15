import { useEffect, useRef } from 'react';
import type { NuiMessage } from '@/types/nui.types';

/**
 * Hook for listening to NUI events from the FiveM game client.
 *
 * @template T - Type of the event payload
 * @param {string} eventName - Name of the NUI event to listen for
 * @param {function(T): void} handler - Callback function invoked when the event is received
 *
 * @example
 * ```typescript
 * useNuiEvent<OpenGarageData>('openGarage', (data) => {
 *   setGarage(data.garage);
 *   setVehicles(data.vehicles);
 * });
 * ```
 */
export function useNuiEvent<T = unknown>(
  eventName: string,
  handler: (data: T) => void
) {
  const savedHandler = useRef(handler);

  // Update ref when handler changes to avoid stale closures
  useEffect(() => {
    savedHandler.current = handler;
  }, [handler]);

  useEffect(() => {
    const eventListener = (event: MessageEvent<NuiMessage<T>>) => {
      const { data } = event;

      // Check if this is the event we're listening for
      if (data.type === eventName) {
        savedHandler.current(data.payload);
      }
    };

    // Add event listener for postMessage events
    window.addEventListener('message', eventListener);

    // Cleanup on unmount
    return () => {
      window.removeEventListener('message', eventListener);
    };
  }, [eventName]);
}
