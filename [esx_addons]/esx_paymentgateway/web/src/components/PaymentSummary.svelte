<script lang="ts">
  /**
   * The bill, as checkout pages set it: who is paid and the amount due at the top, the line and
   * the total at the bottom, everything aligned to the left edge.
   */
  import ReceiptText from 'lucide-svelte/icons/receipt-text';
  import { flow } from '../lib/payment/flow.svelte';
  import { formatMoney } from '../lib/payment/format';
  import type { Payment } from '../lib/payment/types';
  import Money from './Money.svelte';

  interface Props {
    /** The payment on screen */
    payment: Payment;
  }

  let { payment }: Props = $props();

  const price = $derived(formatMoney(payment.amount, payment.currency, flow.locale));
</script>

<section class="summary">
  <div class="due">
    {#if payment.description}
      <p class="merchant">{payment.description}</p>
    {/if}
    <Money amount={payment.amount} currency={payment.currency} locale={flow.locale} />
  </div>
  <dl class="ledger">
    <div class="row">
      <dt class="item">
        <span class="tile" aria-hidden="true"><ReceiptText size={16} strokeWidth={2} /></span>
        {payment.title}
      </dt>
      <dd>{price}</dd>
    </div>
    <div class="row total">
      <dt>{flow.labels.total}</dt>
      <dd>{price}</dd>
    </div>
  </dl>
</section>

<style>
  .summary {
    display: flex;
    flex: 1;
    flex-direction: column;
    justify-content: space-between;
    gap: 28px;
  }

  .due {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 8px;
  }

  .merchant {
    font-size: var(--font-size-body-small);
    color: var(--light-color);
    overflow-wrap: anywhere;
  }

  .ledger {
    margin: 0;
    font-size: var(--font-size-body-small);
  }

  .row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
    padding: 12px 0;
  }

  .row + .row {
    border-top: 1px solid var(--mid-color);
  }

  dt {
    min-width: 0;
    color: var(--light-color);
  }

  .item {
    display: flex;
    align-items: center;
    gap: 10px;
    color: var(--lightest-color);
    overflow-wrap: anywhere;
  }

  .tile {
    display: grid;
    flex: none;
    place-items: center;
    width: 32px;
    height: 32px;
    border: 1px solid var(--mid-color);
    border-radius: 9px;
    background: var(--dark-color);
    color: var(--light-color);
  }

  dd {
    margin: 0;
    white-space: nowrap;
    font-variant-numeric: tabular-nums;
  }

  .total dt,
  .total dd {
    font-weight: 600;
    color: var(--lightest-color);
  }
</style>
