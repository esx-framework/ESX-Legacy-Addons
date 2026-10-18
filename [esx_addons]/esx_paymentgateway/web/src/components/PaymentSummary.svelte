<script lang="ts">
  /**
   * What the payment is for and how much it is.
   */
  import { flow } from '../lib/payment/flow.svelte';
  import { formatMoney } from '../lib/payment/format';
  import type { Payment } from '../lib/payment/types';

  interface Props {
    /** The payment on screen */
    payment: Payment;
  }

  let { payment }: Props = $props();
</script>

<section class="summary">
  <div class="what">
    <h4 class="title">{payment.title}</h4>
    {#if payment.description}
      <p class="description">{payment.description}</p>
    {/if}
  </div>
  <p class="amount">{formatMoney(payment.amount, payment.currency, flow.locale)}</p>
</section>

<style>
  .summary {
    display: flex;
    flex-direction: column;
    gap: 14px;
  }

  .what {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .title {
    font-weight: 600;
    line-height: 1.3;
    overflow-wrap: anywhere;
  }

  .description {
    font-size: var(--font-size-body-small);
    color: var(--light-color);
    overflow-wrap: anywhere;
  }

  .amount {
    font-size: var(--font-size-h1);
    font-weight: 700;
    line-height: 1.1;
    letter-spacing: -0.01em;
    font-variant-numeric: tabular-nums;
  }
</style>
