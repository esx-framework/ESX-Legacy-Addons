<script lang="ts">
  /**
   * What the player sees once the money is taken: the success mark, the amount and a short
   * receipt. The headline has three levels only (status, amount, what for) and every line of the
   * slip is set the same way, so the screen reads calm. The dialog closes on its own after the
   * configured delay; the Done button drains to show the time left, and pressing it closes at
   * once.
   */
  import { Button } from 'esx-ui-kit-svelte';
  import { flow, type Receipt } from '../lib/payment/flow.svelte';
  import { formatMoney } from '../lib/payment/format';
  import type { Payment } from '../lib/payment/types';
  import { DURATION, rise } from '../lib/ui/motion';
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
  const rows = $derived([
    { label: labels.paid_with, value: labels[receipt.method] },
    {
      label: labels.new_balance,
      value: formatMoney(receipt.balance, payment.currency, flow.locale),
    },
    { label: labels.reference, value: receipt.reference },
  ]);
</script>

<section class="receipt" in:rise={{ distance: 6 }}>
  <SuccessMark method={receipt.method} />
  <div class="headline">
    <p class="status">{labels.success}</p>
    <Money amount={payment.amount} currency={payment.currency} locale={flow.locale} />
    <p class="what">
      {payment.description ? `${payment.title} · ${payment.description}` : payment.title}
    </p>
  </div>
  <dl class="slip">
    {#each rows as row, index (row.label)}
      <div class="row" in:rise={{ delay: 280 + index * DURATION.stagger, distance: 6 }}>
        <dt>{row.label}</dt>
        <dd>
          {row.value}
        </dd>
      </div>
    {/each}
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
    gap: 20px;
    padding-top: 4px;
  }

  .headline {
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
  }

  .status {
    margin-bottom: 4px;
    font-size: var(--font-size-caption);
    font-weight: 600;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    color: var(--brand-color);
  }

  .what {
    margin-top: 6px;
    font-size: var(--font-size-body-small);
    color: var(--light-color);
  }

  .slip {
    position: relative;
    width: 100%;
    margin: 7px 0 0;
    padding: 4px 16px;
    border-radius: 0 0 12px 12px;
    background: var(--darkest-color);
  }

  /* The torn top edge of a till slip. */
  .slip::before {
    content: '';
    position: absolute;
    left: 0;
    right: 0;
    top: -7px;
    height: 7px;
    background: var(--darkest-color);
    mask: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='14' height='7'%3E%3Cpath d='M0 7 7 0l7 7z'/%3E%3C/svg%3E")
      center bottom / 14px 7px repeat-x;
    -webkit-mask: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='14' height='7'%3E%3Cpath d='M0 7 7 0l7 7z'/%3E%3C/svg%3E")
      center bottom / 14px 7px repeat-x;
  }

  .row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
    height: 40px;
    font-size: var(--font-size-body-small);
  }

  .row + .row {
    border-top: 1px solid var(--mid-color);
  }

  dt {
    color: var(--light-color);
  }

  dd {
    margin: 0;
    font-weight: 600;
    font-variant-numeric: tabular-nums;
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
