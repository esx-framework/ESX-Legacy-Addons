<script lang="ts">
  /**
   * Who is paid, what for and how much, read top to bottom like a price tag.
   */
  import { flow } from '../lib/payment/flow.svelte';
  import type { Payment } from '../lib/payment/types';
  import Money from './Money.svelte';

  interface Props {
    /** The payment on screen */
    payment: Payment;
  }

  let { payment }: Props = $props();
</script>

<section class="summary">
  {#if payment.description}
    <p class="merchant">{payment.description}</p>
  {/if}
  <h4 class="title">{payment.title}</h4>
  <p class="amount">
    <Money amount={payment.amount} currency={payment.currency} locale={flow.locale} />
  </p>
</section>

<style>
  .summary {
    display: flex;
    flex-direction: column;
  }

  .merchant {
    font-size: var(--font-size-body-small);
    color: var(--light-color);
    overflow-wrap: anywhere;
  }

  .title {
    font-weight: 600;
    line-height: 1.35;
    overflow-wrap: anywhere;
  }

  .amount {
    margin-top: 8px;
  }
</style>
