<script lang="ts">
  /**
   * Button following the ESX UI Kit: active = solid brand orange with black text, hover =
   * orange outline on a transparent background, inactive = dark gray with white text,
   * disabled = light gray with white text.
   */
  import type { Snippet } from 'svelte';

  interface Props {
    /** `primary` renders the active style, `secondary` the inactive style */
    variant?: 'primary' | 'secondary';
    /** Disables the button */
    disabled?: boolean;
    /** Click handler */
    onclick?: (event: MouseEvent) => void;
    /** Button label */
    children: Snippet;
  }

  let { variant = 'secondary', disabled = false, onclick, children }: Props = $props();
</script>

<button type="button" class="button {variant}" {disabled} {onclick}>
  {@render children()}
</button>

<style>
  .button {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    min-width: 120px;
    height: 44px;
    padding: 0 22px;
    border: 2px solid transparent;
    border-radius: var(--esx-radius);
    font-size: var(--esx-h6);
    font-weight: 600;
    letter-spacing: 0.02em;
    cursor: pointer;
    transition:
      background-color 140ms var(--esx-ease),
      border-color 140ms var(--esx-ease),
      color 140ms var(--esx-ease),
      transform 140ms var(--esx-ease);
  }

  .primary {
    background: var(--esx-brand);
    color: var(--esx-darkest);
  }

  .secondary {
    background: var(--esx-mid);
    color: var(--esx-lightest);
  }

  .button:hover:not(:disabled),
  .button:focus-visible {
    background: transparent;
    border-color: var(--esx-brand);
    color: var(--esx-lightest);
    outline: none;
  }

  .button:active:not(:disabled) {
    transform: scale(0.97);
  }

  .button:disabled {
    background: var(--esx-light);
    color: var(--esx-lightest);
    cursor: default;
  }
</style>
