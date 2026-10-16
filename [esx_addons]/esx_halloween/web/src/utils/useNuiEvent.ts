import { onMount, onDestroy } from 'svelte';
import type { NuiMessage, NuiEventHandler } from '../types/nui';

/**
 * Svelte hook for listening to NUI events from the FiveM game client
 * Automatically registers and cleans up event listeners on component mount/destroy
 * @template T - Expected data type for the event
 * @param {string} eventType - The event type to listen for (must match SendNUIMessage type)
 * @param {NuiEventHandler<T>} handler - Callback function to handle the event data
 * @returns {void}
 * @example
 * // Listen for player data updates from Lua
 * useNuiEvent<{ name: string; id: number }>('setPlayerData', (data) => {
 *   playerName = data.name;
 *   playerId = data.id;
 * });
 *
 * // Lua side:
 * // SendNUIMessage({ type = 'setPlayerData', name = 'John', id = 1 })
 */
export function useNuiEvent<T = unknown>(
  eventType: string,
  handler: NuiEventHandler<T>
): void {
  const eventListener = (event: MessageEvent<NuiMessage<T>>) => {
    const { type, ...data } = event.data;

    if (type === eventType) {
      handler(data as T);
    }
  };

  onMount(() => {
    window.addEventListener('message', eventListener as EventListener);
  });

  onDestroy(() => {
    window.removeEventListener('message', eventListener as EventListener);
  });
}
