<script lang="ts">
  /**
   * Bottom of the dialog: cancel, and the pay button that names the amount and the chosen
   * method, so the player knows exactly what one click does. For payments the server marks as
   * large, the button has to be held until it has filled.
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
  const payLabel = $derived(
    fill(
      labels[payment.hold ? (card ? 'hold_card' : 'hold_cash') : card ? 'pay_card' : 'pay_cash'],
      {
        amount: formatMoney(payment.amount, payment.currency, flow.locale),
      },
    ),
  );

  function press(event: PointerEvent): void {
    if (event.button === 0 && flow.method && !paying) hold.start(onpay);
  }

  function release(): void {
    hold.cancel();
  }
</script>

<footer class="actions">
  <Button
    variant="secondary"
    size="lg"
    class="esx-button esx-button-secondary cancel"
    disabled={paying}
    onclick={oncancel}
  >
    {labels.cancel}
  </Button>
  {#if payment.hold && !paying}
    <Button
      variant="primary"
      size="lg"
      class="esx-button pay hold"
      disabled={!flow.method}
      onpointerdown={press}
      onpointerup={release}
      onpointerleave={release}
    >
      <span class="fill" style:transform="scaleX({hold.progress})"></span>
      <span class="hand"><Hand size={17} strokeWidth={2.5} /></span>
      {payLabel}
    </Button>
  {:else}
    <Button
      variant="primary"
      size="lg"
      class="esx-button pay {paying ? 'busy' : ''}"
      disabled={!flow.method && !paying}
      aria-busy={paying}
      onclick={onpay}
    >
      {#if paying}
        <span class="spin"><LoaderCircle size={18} strokeWidth={2.5} /></span>
        {labels.processing}
      {:else}
        {payLabel}
        <span class="enter"><CornerDownLeft size={16} strokeWidth={2.5} /></span>
      {/if}
    </Button>
  {/if}
</footer>

<style>
  .actions {
    display: flex;
    gap: 12px;
  }

  .actions :global(.cancel) {
    flex: none;
    padding-inline: 24px;
  }

  .actions :global(.pay) {
    flex: 1;
    min-width: 0;
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

  .spin {
    display: inline-grid;
    animation: spin 800ms linear infinite;
  }

  .enter,
  .hand {
    display: inline-grid;
    opacity: 0.75;
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }
</style>
