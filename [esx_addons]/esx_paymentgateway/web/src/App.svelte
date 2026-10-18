<script lang="ts">
  /**
   * Root component. Shows the payment dialog over the transparent page and maps the keyboard
   * onto it; the controller talks to Lua.
   */
  import PaymentDialog from './components/PaymentDialog.svelte';
  import { sounds } from './lib/audio/sounds';
  import { onNuiMessage } from './lib/nui/bridge';
  import type { NuiMessage } from './lib/nui/messages';
  import { controller } from './lib/payment/controller.svelte';
  import { flow } from './lib/payment/flow.svelte';
  import { hold } from './lib/payment/hold.svelte';
  import type { PaymentMethod } from './lib/payment/types';
  import { uiScale } from './lib/ui/scale.svelte';

  const pay = (): void => void controller.pay();
  const close = (): void => void controller.close();

  /** Whether a key confirms: Enter always, Space only while a payment needs holding. */
  function confirms(event: KeyboardEvent): boolean {
    return event.key === 'Enter' || (event.key === ' ' && flow.payment?.hold === true);
  }

  function handleKeydown(event: KeyboardEvent): void {
    const payment = flow.payment;
    if (!payment) return;
    if (event.key === 'Escape') {
      event.preventDefault();
      close();
    } else if (confirms(event) && flow.phase === 'paid') {
      event.preventDefault();
      close();
    } else if (confirms(event) && payment.hold) {
      // Held keys repeat; the gesture ignores starts while it runs.
      event.preventDefault();
      if (flow.method && flow.phase === 'choosing') hold.start(pay);
    } else if (event.key === 'Enter' && !(event.target instanceof HTMLButtonElement)) {
      event.preventDefault();
      pay();
    } else if (/^[1-9]$/.test(event.key)) {
      const method = payment.methods[Number(event.key) - 1];
      if (method) controller.choose(method);
    }
  }

  function handleKeyup(event: KeyboardEvent): void {
    if (!confirms(event) || !flow.payment?.hold) return;
    event.preventDefault();
    hold.cancel();
  }

  $effect((): (() => void) =>
    onNuiMessage((message: NuiMessage): void => controller.handle(message)),
  );
  $effect((): (() => void) => uiScale.track());
  // Decodes the cues up front, so the first one is not lost to loading.
  $effect((): void => void sounds.load());
</script>

<svelte:window onkeydown={handleKeydown} onkeyup={handleKeyup} />

<main class="app">
  {#if flow.payment}
    <PaymentDialog
      payment={flow.payment}
      logo={controller.logo}
      closeDelay={controller.closeDelay}
      onchoose={(method: PaymentMethod): void => controller.choose(method)}
      onpay={pay}
      onclose={close}
    />
  {/if}
</main>
