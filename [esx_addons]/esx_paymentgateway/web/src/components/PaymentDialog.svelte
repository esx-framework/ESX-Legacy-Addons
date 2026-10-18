<script lang="ts">
  /**
   * The payment dialog over a dimmed game: header, what is paid and the choice of method. It is
   * zoomed with the screen height so it reads the same from 720p to 4K.
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

  interface Props {
    /** The payment on screen */
    payment: Payment;
    /** Server logo URL, null for the ESX mark */
    logo: string | null;
    /** Called when the player picks a method */
    onchoose: (method: PaymentMethod) => void;
    /** Called when the player pays */
    onpay: () => void;
    /** Called when the player closes the dialog */
    onclose: () => void;
  }

  let { payment, logo, onchoose, onpay, onclose }: Props = $props();
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
      <DialogHeader
        {logo}
        heading={flow.labels.heading}
        closeLabel={flow.labels.close}
        canClose={flow.phase !== 'paying'}
        {onclose}
      />
      <PaymentSummary {payment} />
      <MethodList {payment} {onchoose} />
      <PayActions {payment} {onpay} oncancel={onclose} />
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
    width: 480px;
  }

  .stage :global(.dialog) {
    display: flex;
    flex-direction: column;
    gap: 22px;
    box-shadow:
      0 24px 60px rgba(0, 0, 0, 0.45),
      0 0 0 1px rgba(var(--brand-color-rgb), 0.06);
  }
</style>
