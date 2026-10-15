<script lang="ts">
  /**
   * Root component. Listens for NUI messages and hosts the running minigame on top of the
   * transparent page.
   */
  import WiringGame from './lib/games/wiring/WiringGame.svelte';
  import { onNuiMessage } from './lib/nui/bridge';
  import type { GameOutcome, NuiMessage } from './lib/nui/messages';
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

  function handleFinish<TAction>(outcome: GameOutcome, actions: readonly TAction[]): void {
    void session.finish(outcome, actions);
  }

  $effect((): (() => void) => onNuiMessage(handleMessage));
</script>

<svelte:window onkeydown={handleKeydown} />

<main class="app" data-game={session.current?.game}>
  {#if session.current}
    {#key session.current.id}
      {#if session.current.game === 'wiring'}
        <WiringGame session={session.current} onfinish={handleFinish} />
      {/if}
    {/key}
  {/if}
</main>

{#if import.meta.env.DEV}
  {#await import('./dev/DevHarness.svelte') then harness}
    <harness.default />
  {/await}
{/if}

<style>
  .app {
    position: fixed;
    inset: 0;
  }
</style>
