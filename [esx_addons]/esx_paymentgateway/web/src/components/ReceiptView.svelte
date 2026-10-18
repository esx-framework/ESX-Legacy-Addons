<script lang="ts">
  /**
   * What the player sees once the money is taken: the success mark, the amount and a short
   * receipt. The dialog closes on its own after the configured delay; a thin line shows the time
   * left, and Done closes it at once.
   */
  import { Button } from 'esx-ui-kit-svelte';
  import { flow, type Receipt } from '../lib/payment/flow.svelte';
  import { formatMoney } from '../lib/payment/format';
  import type { Payment } from '../lib/payment/types';
  import { DURATION, rise } from '../lib/ui/motion';
  import SuccessMark from './SuccessMark.svelte';

  interface Props {
    /** The payment that went through */
    payment: Payment;
    /** Its receipt */
    receipt: Receipt;
    /** Milliseconds until the dialog closes itself, 0 to wait for Done */
    closeDelay: number;
    /** Called when the player is done */
    ondone: () => void;
  }

  let { payment, receipt, closeDelay, ondone }: Props = $props();

  const labels = $derived(flow.labels);
  const money = (amount: number): string => formatMoney(amount, payment.currency, flow.locale);
  const rows = $derived([
    { label: labels.paid_with, value: labels[receipt.method] },
    { label: labels.new_balance, value: money(receipt.balance) },
    { label: labels.reference, value: receipt.reference },
  ]);
</script>

<section class="receipt" in:rise={{ distance: 6 }}>
  <SuccessMark />
  <div class="headline">
    <h3>{labels.success}</h3>
    <p class="amount">{money(payment.amount)}</p>
    <p class="title">{payment.title}</p>
  </div>
  <dl class="rows">
    {#each rows as row, index (row.label)}
      <div class="row" in:rise={{ delay: 280 + index * DURATION.stagger, distance: 6 }}>
        <dt>{row.label}</dt>
        <dd>{row.value}</dd>
      </div>
    {/each}
  </dl>
  <div class="done">
    <Button variant="primary" size="lg" fullWidth class="esx-button" onclick={ondone}>
      {labels.done}
    </Button>
    {#if closeDelay > 0}
      <span class="countdown" style:animation-duration="{closeDelay}ms"></span>
    {/if}
  </div>
</section>

<style>
  .receipt {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 18px;
    padding-top: 6px;
  }

  .headline {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
    text-align: center;
  }

  .amount {
    font-size: var(--font-size-h1);
    font-weight: 700;
    line-height: 1.15;
    font-variant-numeric: tabular-nums;
  }

  .title {
    font-size: var(--font-size-body-small);
    color: var(--light-color);
  }

  .rows {
    width: 100%;
    margin: 0;
    padding: 14px 16px;
    border: 2px dashed var(--mid-color);
    border-radius: 12px;
    background: var(--darkest-color);
  }

  .row {
    display: flex;
    justify-content: space-between;
    gap: 16px;
    padding: 4px 0;
    font-size: var(--font-size-body-small);
  }

  dt {
    color: var(--light-color);
  }

  dd {
    margin: 0;
    font-weight: 600;
    font-variant-numeric: tabular-nums;
  }

  .done {
    display: flex;
    flex-direction: column;
    gap: 8px;
    width: 100%;
  }

  .countdown {
    display: block;
    height: 3px;
    border-radius: 2px;
    background: var(--brand-color);
    transform-origin: left center;
    animation: countdown linear forwards;
  }

  @keyframes countdown {
    to {
      transform: scaleX(0);
    }
  }
</style>
