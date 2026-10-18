<script lang="ts">
  /**
   * What the player sees once the money is taken: the success mark, the amount and a short
   * receipt. The dialog closes on its own after the configured delay; the Done button drains
   * to show the time left, and pressing it closes at once.
   */
  import { Button } from 'esx-ui-kit-svelte';
  import { flow, type Receipt } from '../lib/payment/flow.svelte';
  import { formatMoney } from '../lib/payment/format';
  import type { Payment } from '../lib/payment/types';
  import { DURATION, rise } from '../lib/ui/motion';
  import MethodIcon from './MethodIcon.svelte';
  import Money from './Money.svelte';
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
</script>

<section class="receipt" in:rise={{ distance: 6 }}>
  <SuccessMark />
  <div class="headline">
    <p class="success">{labels.success}</p>
    <Money amount={payment.amount} currency={payment.currency} locale={flow.locale} />
    <p class="title">
      {payment.description ? `${payment.title} · ${payment.description}` : payment.title}
    </p>
  </div>
  <dl class="slip">
    <div class="row" in:rise={{ delay: 280, distance: 6 }}>
      <dt>{labels.paid_with}</dt>
      <dd class="method">
        <span class="mini"><MethodIcon method={receipt.method} active /></span>{labels[
          receipt.method
        ]}
      </dd>
    </div>
    <div class="row" in:rise={{ delay: 280 + DURATION.stagger, distance: 6 }}>
      <dt>{labels.new_balance}</dt>
      <dd>{formatMoney(receipt.balance, payment.currency, flow.locale)}</dd>
    </div>
    <div class="row" in:rise={{ delay: 280 + DURATION.stagger * 2, distance: 6 }}>
      <dt>{labels.reference}</dt>
      <dd>{receipt.reference}</dd>
    </div>
  </dl>
  <Button variant="primary" size="lg" fullWidth class="esx-button done" onclick={ondone}>
    {labels.done}
    {#if closeDelay > 0}
      <span class="drain" style:animation-duration="{closeDelay}ms"></span>
    {/if}
  </Button>
</section>

<style>
  .receipt {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 18px;
    padding-top: 4px;
  }

  .headline {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
    text-align: center;
  }

  .success {
    font-size: var(--font-size-h5);
    font-weight: 600;
  }

  .title {
    margin-top: 2px;
    font-size: var(--font-size-body-small);
    color: var(--light-color);
  }

  .slip {
    position: relative;
    width: 100%;
    margin: 0;
    padding: 14px 16px;
    border-radius: 12px;
    background: var(--darkest-color);
  }

  /* A row of punched holes along the top, like the tear-off edge of a till slip. */
  .slip::before {
    content: '';
    position: absolute;
    top: -5px;
    left: 14px;
    right: 14px;
    height: 10px;
    background: radial-gradient(circle, var(--dark-color) 4px, transparent 4.5px) 0 0 / 16px 10px
      repeat-x;
  }

  .row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
    min-height: 30px;
    font-size: var(--font-size-body-small);
  }

  .row + .row {
    border-top: 1px dashed var(--mid-color);
  }

  dt {
    color: var(--light-color);
  }

  dd {
    margin: 0;
    font-weight: 600;
    font-variant-numeric: tabular-nums;
  }

  .method {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .mini :global(svg) {
    width: 24px;
    height: 17px;
  }

  .receipt :global(.done) {
    position: relative;
    overflow: hidden;
    isolation: isolate;
  }

  .drain {
    position: absolute;
    inset: auto 0 0 0;
    height: 4px;
    background: rgba(var(--darkest-color-rgb), 0.3);
    transform-origin: left center;
    animation: drain linear forwards;
  }

  @keyframes drain {
    to {
      transform: scaleX(0);
    }
  }
</style>
