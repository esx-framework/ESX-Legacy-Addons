<script lang="ts">
  /**
   * A small drawing of the method: a stack of bank notes for cash, a card with a chip for card.
   * The drawing takes the brand color when the method is chosen and stays muted otherwise, so
   * only the chosen side catches the eye. Each method is drawn only for its own name, so a value
   * that is missing for a moment draws nothing rather than the wrong method.
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
    <rect class="bill under" x="8" y="2" width="38" height="22" rx="3.5" />
    <rect class="bill" x="2" y="9" width="38" height="23" rx="3.5" />
    <rect class="engrave" x="6" y="13" width="30" height="15" rx="2" />
    <circle class="engrave" cx="21" cy="20.5" r="4" />
    <path class="engrave dot" d="M10.5 20.5h.01M31.5 20.5h.01" />
  {:else if method === 'card'}
    <rect class="card" x="2" y="2" width="44" height="30" rx="5" />
    <path class="shine" d="M7 2h24L2 26V7a5 5 0 0 1 5-5z" />
    <rect class="chip" x="8" y="10" width="9" height="7.5" rx="1.75" />
    <path class="wave" d="M35 10.5a8 8 0 0 1 0 8M38.5 8.5a11.5 11.5 0 0 1 0 12" />
    <path class="digits" d="M8 25h7M18.5 25h7M29 25h7" />
  {/if}
</svg>

<style>
  .icon {
    --plastic: var(--mid-color);
    --etch: rgba(242, 242, 242, 0.25);
    display: block;
    flex: none;
    transition: transform 200ms cubic-bezier(0.3, 1.4, 0.5, 1);
  }

  .active {
    --plastic: var(--brand-color);
    --etch: rgba(22, 22, 22, 0.45);
    transform: translateY(-1px);
  }

  .bill {
    fill: var(--plastic);
    stroke: var(--dark-color);
    stroke-width: 2.5;
    transition: fill 200ms ease;
  }

  .under {
    opacity: 0.5;
  }

  .engrave {
    fill: none;
    stroke: var(--etch);
    stroke-width: 1.75;
    stroke-linecap: round;
  }

  .dot {
    stroke-width: 3;
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
    stroke: var(--etch);
    stroke-width: 2;
    stroke-linecap: round;
  }
</style>
