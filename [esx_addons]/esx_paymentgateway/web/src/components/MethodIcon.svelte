<script lang="ts">
  /**
   * A small drawing of the method: a stack of bank notes for cash, a card with a chip for card.
   * The drawing takes the brand color when the method is chosen and stays muted otherwise, so
   * only the chosen side catches the eye.
   */
  import type { PaymentMethod } from '../lib/payment/types';

  interface Props {
    /** Method to draw */
    method: PaymentMethod;
    /** Whether the method is chosen */
    active: boolean;
  }

  let { method, active }: Props = $props();
</script>

<svg class="icon" class:active viewBox="0 0 48 34" width="54" height="38" aria-hidden="true">
  {#if method === 'cash'}
    <rect class="note back" x="7" y="2" width="38" height="21" rx="3.5" />
    <rect class="note base" x="2" y="9" width="38" height="21" rx="3.5" />
    <rect class="note front" x="2" y="9" width="38" height="21" rx="3.5" />
    <circle class="mark" cx="21" cy="19.5" r="4.25" />
    <path class="mark" d="M8.5 19.5h.01M33.5 19.5h.01" />
  {:else}
    <rect class="card" x="2" y="2" width="44" height="30" rx="5" />
    <path class="shine" d="M7 2h24L2 26V7a5 5 0 0 1 5-5z" />
    <rect class="chip" x="8" y="10" width="9" height="7.5" rx="1.75" />
    <path class="wave" d="M35 10.5a8 8 0 0 1 0 8M38.5 8.5a11.5 11.5 0 0 1 0 12" />
    <path class="digits" d="M8 25h7M18.5 25h7M29 25h7" />
  {/if}
</svg>

<style>
  .icon {
    --ink: var(--light-color);
    --paper: rgba(var(--mid-color-rgb), 0.55);
    --plastic: var(--mid-color);
    display: block;
    flex: none;
    transition: transform 200ms cubic-bezier(0.3, 1.4, 0.5, 1);
  }

  .active {
    --ink: var(--brand-color);
    --paper: rgba(var(--brand-color-rgb), 0.16);
    --plastic: var(--brand-color);
    transform: translateY(-1px);
  }

  .note {
    fill: var(--darkest-color);
    stroke: var(--ink);
    stroke-width: 2;
    transition: stroke 200ms ease;
  }

  .base {
    stroke: none;
  }

  .front {
    fill: var(--paper);
  }

  .back {
    opacity: 0.55;
  }

  .mark {
    fill: none;
    stroke: var(--ink);
    stroke-width: 2;
    stroke-linecap: round;
    transition: stroke 200ms ease;
  }

  .card {
    fill: var(--plastic);
    transition: fill 200ms ease;
  }

  .shine {
    fill: rgba(255, 255, 255, 0.08);
  }

  .chip {
    fill: var(--lightest-color);
    opacity: 0.85;
  }

  .wave,
  .digits {
    fill: none;
    stroke: rgba(22, 22, 22, 0.45);
    stroke-width: 2;
    stroke-linecap: round;
  }

  .icon:not(.active) .wave,
  .icon:not(.active) .digits {
    stroke: rgba(242, 242, 242, 0.25);
  }
</style>
