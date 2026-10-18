<script lang="ts">
  /**
   * Small controls of the browser demo: the next sample payment, the blue theme and the German
   * texts. Only shown outside the game, where the page also gets a dark backdrop in place of
   * the game world.
   */
  import { Button } from 'esx-ui-kit-svelte';
  import { demo } from '../lib/demo/server.svelte';

  $effect((): (() => void) => {
    document.body.classList.add('demo-backdrop');
    return (): void => document.body.classList.remove('demo-backdrop');
  });

  function toggleTheme(): void {
    demo.blue = !demo.blue;
    demo.open();
  }

  function toggleLanguage(): void {
    demo.german = !demo.german;
    demo.open();
  }
</script>

<aside class="demo" aria-label="Demo">
  <span class="tag">Demo</span>
  <Button
    variant="secondary"
    size="sm"
    class="esx-button esx-button-secondary"
    onclick={(): void => demo.next()}
  >
    Next payment
  </Button>
  <Button
    variant="secondary"
    size="sm"
    class="esx-button esx-button-secondary"
    onclick={toggleTheme}
  >
    {demo.blue ? 'ESX colors' : 'Server theme'}
  </Button>
  <Button
    variant="secondary"
    size="sm"
    class="esx-button esx-button-secondary"
    onclick={toggleLanguage}
  >
    {demo.german ? 'English' : 'Deutsch'}
  </Button>
</aside>

<style>
  :global(body.demo-backdrop) {
    background:
      radial-gradient(ellipse at 25% 15%, #3b4652 0%, transparent 55%),
      radial-gradient(ellipse at 80% 90%, #2a2f35 0%, transparent 50%), #15181b;
  }

  .demo {
    position: fixed;
    left: 24px;
    bottom: 24px;
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px;
    border: 2px solid var(--mid-color);
    border-radius: 12px;
    background: var(--darkest-color);
    z-index: 10;
  }

  .tag {
    padding: 0 8px;
    font-size: var(--font-size-caption);
    font-weight: 600;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--brand-color);
  }
</style>
