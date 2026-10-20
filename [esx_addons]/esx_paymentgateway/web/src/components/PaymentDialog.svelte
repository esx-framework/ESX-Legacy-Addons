<script lang="ts">
  /**
   * The payment dialog over a dimmed game, split like a checkout page: the bill on the left, how
   * to pay on the right. Once the money is taken, the right side turns into the receipt and the
   * bill stays. It is zoomed with the screen height so it reads the same from 720p to 4K.
   */
  import { Card } from 'esx-ui-kit-svelte';
  import { fade } from 'svelte/transition';
  import { flow } from '../lib/payment/flow.svelte';
  import type { Payment, PaymentMethod } from '../lib/payment/types';
  import { DURATION, rise } from '../lib/ui/motion';
  import { uiScale } from '../lib/ui/scale.svelte';
  import DialogHeader from './DialogHeader.svelte';
  import MethodList from './MethodList.svelte';
  import PayActions from './PayActions.svelte';
  import PaymentSummary from './PaymentSummary.svelte';
  import ReceiptView from './ReceiptView.svelte';

  interface Props {
    /** The payment on screen */
    payment: Payment;
    /** Server logo URL, null for the ESX mark */
    logo: string | null;
    /** Milliseconds the receipt stays before the dialog closes itself, 0 to wait for Done */
    closeDelay: number;
    /** Called when the player picks a method */
    onchoose: (method: PaymentMethod) => void;
    /** Called when the player pays */
    onpay: () => void;
    /** Called when the player closes the dialog, before or after paying */
    onclose: () => void;
  }

  let { payment, logo, closeDelay, onchoose, onpay, onclose }: Props = $props();
</script>

<div class="backdrop" transition:fade={{ duration: DURATION.enter }}>
  <div
    class="stage"
    style:zoom={uiScale.zoom}
    in:rise={{ distance: 14, from: 0.96 }}
    out:rise={{ duration: DURATION.leave, distance: 8 }}
  >
    <Card
      variant="bordered"
      class="dialog"
      role="dialog"
      aria-modal="true"
      aria-label={flow.labels.heading}
      data-phase={flow.phase}
    >
      <aside class="bill">
        <DialogHeader {logo} heading={flow.labels.heading} />
        <PaymentSummary {payment} />
      </aside>
      <div class="pane">
        {#if flow.phase === 'paid' && flow.receipt}
          <ReceiptView {payment} receipt={flow.receipt} {closeDelay} ondone={onclose} />
        {:else}
          <div class="pane-head">
            <h5>{flow.labels.choose}</h5>
          </div>
          <div class="choices">
            <MethodList {payment} {onchoose} />
          </div>
          <PayActions {payment} {onpay} oncancel={onclose} />
        {/if}
      </div>
    </Card>
  </div>
</div>

<style>
  .backdrop {
    position: fixed;
    inset: 0;
    display: grid;
    place-items: center;
    background: radial-gradient(
      ellipse at center,
      rgba(var(--darkest-color-rgb), 0.35) 0%,
      rgba(var(--darkest-color-rgb), 0.7) 100%
    );
  }

  .stage {
    width: 760px;
  }

  .stage :global(.dialog) {
    display: grid;
    grid-template-columns: 304px 1fr;
    padding: 0;
    overflow: hidden;
    box-shadow:
      0 24px 60px rgba(0, 0, 0, 0.45),
      0 0 0 1px rgba(var(--brand-color-rgb), 0.06);
  }

  /* A faint glow of the brand color in the corner of the logo, over the darkest tone. */
  .bill {
    display: flex;
    flex-direction: column;
    gap: 28px;
    padding: 24px;
    border-right: 1px solid var(--mid-color);
    background:
      radial-gradient(
        120% 70% at 0% 0%,
        rgba(var(--brand-color-rgb), 0.09) 0%,
        rgba(var(--brand-color-rgb), 0) 70%
      ),
      var(--darkest-color);
  }

  .pane {
    display: flex;
    flex-direction: column;
    gap: 18px;
    min-width: 0;
    padding: 24px 24px 12px;
  }

  .pane-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    min-height: 28px;
  }

  /* Takes the height the bill adds, so the pay button stays at the bottom. */
  .choices {
    flex: 1;
  }
</style>
