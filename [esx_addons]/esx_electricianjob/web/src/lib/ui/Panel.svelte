<script lang="ts">
  /**
   * Dark translucent card for HUD content, in the ESX UI Kit palette.
   */
  import type { Snippet } from 'svelte';

  interface Props {
    /** Small uppercase caption above the content */
    caption?: string;
    /** Card content */
    children: Snippet;
  }

  let { caption, children }: Props = $props();
</script>

<section class="panel">
  {#if caption}
    <h6 class="caption">{caption}</h6>
  {/if}
  {@render children()}
</section>

<style>
  .panel {
    padding: 16px 18px;
    border: 1px solid var(--esx-line);
    border-radius: var(--esx-radius-lg);
    background: var(--esx-darkest-glass);
    box-shadow: var(--esx-shadow);
  }

  .caption {
    margin-bottom: 10px;
    font-size: var(--esx-caption);
    font-weight: 600;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    color: var(--esx-light);
  }
</style>
