<script lang="ts">
  /**
   * The methods the payment offers, side by side so they compare at a glance, and the reason
   * the last attempt failed.
   */
  import CircleAlert from 'lucide-svelte/icons/circle-alert';
  import { slide } from 'svelte/transition';
  import { flow } from '../lib/payment/flow.svelte';
  import { formatMoney } from '../lib/payment/format';
  import { fillParts, type TextPart } from '../lib/payment/labels';
  import type { Payment, PaymentMethod } from '../lib/payment/types';
  import { DURATION } from '../lib/ui/motion';
  import MethodCard from './MethodCard.svelte';

  interface Props {
    /** The payment on screen */
    payment: Payment;
    /** Called when the player picks a method */
    onchoose: (method: PaymentMethod) => void;
  }

  let { payment, onchoose }: Props = $props();

  const labels = $derived(flow.labels);
  const money = (amount: number): string => formatMoney(amount, payment.currency, flow.locale);

  function note(method: PaymentMethod): TextPart[] {
    const left = flow.balances[method] - payment.amount;
    return left >= 0
      ? fillParts(labels.remaining, { amount: money(left) })
      : fillParts(labels.short, { amount: money(-left) });
  }

  const problem = $derived(
    flow.error ?? (flow.affordable.length === 0 ? labels.unaffordable : null),
  );
</script>

<div class="methods">
  <div
    class="grid"
    class:single={payment.methods.length === 1}
    role="radiogroup"
    aria-label={labels.choose}
  >
    {#each payment.methods as method, index (method)}
      <MethodCard
        {method}
        label={labels[method]}
        balance={money(flow.balances[method])}
        note={note(method)}
        affordable={flow.canAfford(method)}
        selected={flow.method === method}
        locked={flow.phase !== 'choosing'}
        refusals={flow.refusals}
        delay={120 + index * DURATION.stagger}
        wide={payment.methods.length === 1}
        {onchoose}
      />
    {/each}
  </div>
  {#if problem}
    <p class="problem" role="alert" transition:slide={{ duration: 180 }}>
      <CircleAlert size={16} strokeWidth={2.25} />
      <span>{problem}</span>
    </p>
  {/if}
</div>

<style>
  .methods {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
  }

  .single {
    grid-template-columns: 1fr;
  }

  .problem {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: var(--font-size-body-small);
    color: var(--error-color);
  }
</style>
