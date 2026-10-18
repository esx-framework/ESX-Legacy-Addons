<script lang="ts">
  /**
   * Root component. Listens for NUI messages, shows the payment dialog over the transparent
   * page and sends the player's choices back to Lua.
   */
  import PaymentDialog from './components/PaymentDialog.svelte';
  import { onNuiMessage, postNui } from './lib/nui/bridge';
  import type { NuiMessage } from './lib/nui/messages';
  import { flow } from './lib/payment/flow.svelte';
  import type { PaymentMethod } from './lib/payment/types';
  import { uiScale } from './lib/ui/scale.svelte';
  import { applyTheme } from './lib/ui/theme';

  /** Shortest time the pay button shows that it is working, so an instant answer reads as one. */
  const MIN_PAYING_MS = 650;
  /** Longest the page waits for the server's answer before it lets the player try again. */
  const ANSWER_TIMEOUT_MS = 10_000;

  let logo: string | null = $state(null);
  let payingSince = 0;
  let answerTimer: ReturnType<typeof setTimeout> | undefined;

  function clearTimers(): void {
    clearTimeout(answerTimer);
  }

  function handleMessage(message: NuiMessage): void {
    switch (message.action) {
      case 'open':
        clearTimers();
        logo = applyTheme(message.theme);
        flow.open(message);
        break;
      case 'result': {
        const { result } = message;
        clearTimeout(answerTimer);
        answerTimer = setTimeout(
          (): void => {
            if (flow.answer(result) && flow.phase === 'paid') void close();
          },
          Math.max(0, payingSince + MIN_PAYING_MS - Date.now()),
        );
        break;
      }
      case 'close':
        clearTimers();
        flow.close();
        break;
      default:
        break;
    }
  }

  function choose(method: PaymentMethod): void {
    flow.choose(method);
  }

  async function pay(): Promise<void> {
    const body = flow.pay();
    if (!body) return;
    payingSince = Date.now();
    const giveUp = (): void => {
      flow.answer({ id: body.id, ok: false, message: flow.labels.unreachable });
    };
    answerTimer = setTimeout(giveUp, ANSWER_TIMEOUT_MS);
    try {
      await postNui('pay', body);
    } catch (err: unknown) {
      console.error('[esx_paymentgateway] pay callback failed', err);
      clearTimeout(answerTimer);
      giveUp();
    }
  }

  async function close(): Promise<void> {
    if (flow.phase === 'paying') return;
    clearTimers();
    const body = flow.close();
    if (!body) return;
    try {
      await postNui('close', body);
    } catch (err: unknown) {
      console.error('[esx_paymentgateway] close callback failed', err);
    }
  }

  function handleKeydown(event: KeyboardEvent): void {
    const payment = flow.payment;
    if (!payment) return;
    if (event.key === 'Escape') {
      event.preventDefault();
      void close();
    } else if (event.key === 'Enter' && !(event.target instanceof HTMLButtonElement)) {
      event.preventDefault();
      if (flow.phase === 'paid') void close();
      else void pay();
    } else if (/^[1-9]$/.test(event.key)) {
      const method = payment.methods[Number(event.key) - 1];
      if (method) choose(method);
    }
  }

  $effect((): (() => void) => onNuiMessage(handleMessage));
  $effect((): (() => void) => uiScale.track());
</script>

<svelte:window onkeydown={handleKeydown} />

<main class="app">
  {#if flow.payment}
    <PaymentDialog payment={flow.payment} {logo} onchoose={choose} onpay={pay} onclose={close} />
  {/if}
</main>
