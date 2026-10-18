<script lang="ts">
  /**
   * Bottom of the dialog: the pay button that names the amount and the chosen method, so the
   * player knows exactly what one click does, and a quiet way out. For payments the server marks
   * as large, the button has to be held until it has filled.
   */
  import { Button } from 'esx-ui-kit-svelte';
  import CornerDownLeft from 'lucide-svelte/icons/corner-down-left';
  import Hand from 'lucide-svelte/icons/hand';
  import LoaderCircle from 'lucide-svelte/icons/loader-circle';
  import { flow } from '../lib/payment/flow.svelte';
  import { formatMoney } from '../lib/payment/format';
  import { hold } from '../lib/payment/hold.svelte';
  import { fill } from '../lib/payment/labels';
  import type { Payment } from '../lib/payment/types';

  interface Props {
    /** The payment on screen */
    payment: Payment;
    /** Called when the player pays */
    onpay: () => void;
    /** Called when the player cancels */
    oncancel: () => void;
  }

  let { payment, onpay, oncancel }: Props = $props();

  const labels = $derived(flow.labels);
  const paying = $derived(flow.phase === 'paying');
  const card = $derived(flow.method === 'card');
  const key = $derived(
    payment.hold ? (card ? 'hold_card' : 'hold_cash') : card ? 'pay_card' : 'pay_cash',
  );
  const payLabel = $derived(
    fill(labels[key], { amount: formatMoney(payment.amount, payment.currency, flow.locale) }),
  );

  function press(event: PointerEvent): void {
    if (event.button === 0 && flow.method && !paying) hold.start(onpay);
  }

  function release(): void {
    hold.cancel();
  }
</script>

<footer class="actions">
  {#if payment.hold && !paying}
    <Button
      variant="primary"
      size="lg"
      fullWidth
      class="esx-button pay hold"
      disabled={!flow.method}
      onpointerdown={press}
      onpointerup={release}
      onpointerleave={release}
    >
      <span class="fill" style:transform="scaleX({hold.progress})"></span>
      <span class="glyph"><Hand size={17} strokeWidth={2.5} /></span>
      {payLabel}
    </Button>
  {:else}
    <Button
      variant="primary"
      size="lg"
      fullWidth
      class="esx-button pay {paying ? 'busy' : ''}"
      disabled={!flow.method && !paying}
      aria-busy={paying}
      onclick={onpay}
    >
      {#if paying}
        <span class="glyph spin"><LoaderCircle size={18} strokeWidth={2.5} /></span>
        {labels.processing}
      {:else}
        {payLabel}
        <span class="glyph"><CornerDownLeft size={16} strokeWidth={2.5} /></span>
      {/if}
    </Button>
  {/if}
  <button type="button" class="cancel" disabled={paying} onclick={oncancel}>
    {labels.cancel}
    <kbd>Esc</kbd>
  </button>
</footer>

<style>
  .actions {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
  }

  .actions :global(.pay) {
    padding-inline: 20px;
    white-space: nowrap;
  }

  .actions :global(.hold) {
    position: relative;
    overflow: hidden;
    isolation: isolate;
    touch-action: none;
  }

  /* The hold fills the button, so it stays solid under the pointer instead of turning to outline. */
  .actions :global(.hold:hover:not(:disabled)) {
    background-color: var(--brand-color);
    color: var(--darkest-color);
  }

  .fill {
    position: absolute;
    inset: 0;
    z-index: -1;
    background: rgba(var(--darkest-color-rgb), 0.28);
    transform-origin: left center;
  }

  .glyph {
    display: inline-grid;
    opacity: 0.75;
  }

  .spin {
    opacity: 1;
    animation: spin 800ms linear infinite;
  }

  .cancel {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    height: 30px;
    padding: 0 12px;
    border: none;
    border-radius: 8px;
    background: transparent;
    color: var(--light-color);
    font: 500 var(--font-size-body-small) / 1 var(--font-family);
    cursor: pointer;
    transition: color 150ms ease;
  }

  .cancel:hover:not(:disabled) {
    color: var(--lightest-color);
  }

  .cancel:focus-visible {
    outline: 2px solid var(--brand-color);
    outline-offset: 2px;
  }

  .cancel:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  kbd {
    display: inline-grid;
    place-items: center;
    height: 18px;
    padding: 0 5px;
    border: 1px solid var(--mid-color);
    border-radius: 4px;
    font: 500 11px / 1 var(--font-family);
    color: var(--light-color);
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }
</style>
