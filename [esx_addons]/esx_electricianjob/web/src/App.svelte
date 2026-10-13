<script lang="ts">
  /**
   * Root component. Listens for NUI messages and hosts the running minigame on top of the
   * transparent page.
   */
  import { onNuiMessage } from './lib/nui/bridge';
  import type { NuiMessage } from './lib/nui/messages';
  import { session } from './lib/session.svelte';

  function handleMessage(message: NuiMessage): void {
    switch (message.action) {
      case 'open':
        session.open(message.session);
        break;
      case 'close':
        session.close();
        break;
      default:
        break;
    }
  }

  function handleKeydown(event: KeyboardEvent): void {
    if (event.key !== 'Escape' || !session.current) return;
    event.preventDefault();
    void session.finish('aborted');
  }

  $effect((): (() => void) => onNuiMessage(handleMessage));
</script>

<svelte:window onkeydown={handleKeydown} />

<main class="app" data-game={session.current?.game}></main>

<style>
  .app {
    position: fixed;
    inset: 0;
  }
</style>
