<script lang="ts">
  /**
   * Bottom of the dialog: cancel, and the pay button that names the amount and the chosen
   * method, so the player knows exactly what one click does.
   */
  import { Button } from 'esx-ui-kit-svelte';
  import CornerDownLeft from 'lucide-svelte/icons/corner-down-left';
  import LoaderCircle from 'lucide-svelte/icons/loader-circle';
  import { flow } from '../lib/payment/flow.svelte';
  import { formatMoney } from '../lib/payment/format';
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
  const payLabel = $derived(
    fill(labels[flow.method === 'card' ? 'pay_card' : 'pay_cash'], {
      amount: formatMoney(payment.amount, payment.currency, flow.locale),
    }),
  );
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

  .spin {
    display: inline-grid;
    animation: spin 800ms linear infinite;
  }

  .enter {
    display: inline-grid;
    opacity: 0.7;
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }
</style>
