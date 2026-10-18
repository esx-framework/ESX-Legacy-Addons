<script lang="ts">
  /**
   * The methods the payment offers, one tile each, and the reason the last attempt failed.
   */
  import CircleAlert from 'lucide-svelte/icons/circle-alert';
  import { slide } from 'svelte/transition';
  import { flow } from '../lib/payment/flow.svelte';
  import { formatMoney } from '../lib/payment/format';
  import { fill } from '../lib/payment/labels';
  import type { Payment, PaymentMethod } from '../lib/payment/types';
  import { DURATION } from '../lib/ui/motion';
  import MethodTile from './MethodTile.svelte';

  interface Props {
    /** The payment on screen */
    payment: Payment;
    /** Called when the player picks a method */
    onchoose: (method: PaymentMethod) => void;
  }

  let { payment, onchoose }: Props = $props();

  const labels = $derived(flow.labels);
  const money = (amount: number): string => formatMoney(amount, payment.currency, flow.locale);

  function note(method: PaymentMethod): string {
    const left = flow.balances[method] - payment.amount;
    return left >= 0
      ? fill(labels.remaining, { amount: money(left) })
      : fill(labels.short, { amount: money(-left) });
  }

  const problem = $derived(
    flow.error ?? (flow.affordable.length === 0 ? labels.unaffordable : null),
  );
</script>

<div class="methods">
  <p class="caption" id="methods-caption">{labels.choose}</p>
  <div class="list" role="radiogroup" aria-labelledby="methods-caption">
    {#each payment.methods as method, index (method)}
      <MethodTile
        {method}
        label={labels[method]}
        balance={money(flow.balances[method])}
        balanceLabel={labels.balance}
        note={note(method)}
        affordable={flow.canAfford(method)}
        selected={flow.method === method}
        locked={flow.phase !== 'choosing'}
        hotkey={String(index + 1)}
        refusals={flow.refusals}
        delay={120 + index * DURATION.stagger}
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
    gap: 10px;
  }

  .caption {
    font-size: var(--font-size-caption);
    font-weight: 600;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--light-color);
  }

  .list {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .problem {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: var(--font-size-body-small);
    color: var(--error-color);
  }
</style>
