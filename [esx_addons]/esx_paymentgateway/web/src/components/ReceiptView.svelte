<script lang="ts">
  /**
   * The right side of the dialog once the money is taken: the success mark, the status and a
   * short slip. The bill next to it keeps the amount and what it was for, so the slip only adds
   * what changed, and the seller's reference when it gave one. Every line is set the same way. The dialog closes on its own after
   * the configured delay; the Done button drains to show the time left, and pressing it closes
   * at once.
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
  const rows = $derived([
    { label: labels.paid_with, value: labels[receipt.method] },
    {
      label: labels.new_balance,
      value: formatMoney(receipt.balance, payment.currency, flow.locale),
    },
    ...(receipt.reference ? [{ label: labels.reference, value: receipt.reference }] : []),
  ]);
</script>

<section class="receipt" in:rise={{ distance: 6 }}>
  <SuccessMark method={receipt.method} />
  <h4 class="status">{labels.success}</h4>
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
    flex: 1;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 12px;
  }

  .status {
    text-align: center;
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
    height: 38px;
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
