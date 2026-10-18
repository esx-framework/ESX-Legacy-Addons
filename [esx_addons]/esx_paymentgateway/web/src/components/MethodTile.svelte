<script lang="ts">
  /**
   * One way to pay: what it is, what the player has and what stays after paying. Methods the
   * balance cannot cover are shown but cannot be chosen. A refusal from the server shakes the
   * chosen tile.
   */
  import Banknote from 'lucide-svelte/icons/banknote';
  import Check from 'lucide-svelte/icons/check';
  import CreditCard from 'lucide-svelte/icons/credit-card';
  import type { PaymentMethod } from '../lib/payment/types';
  import { prefersReducedMotion } from '../lib/ui/motion';

  interface Props {
    /** Method of the tile */
    method: PaymentMethod;
    /** Name of the method, e.g. "Cash" */
    label: string;
    /** Formatted balance of the method */
    balance: string;
    /** Caption of the balance, e.g. "Balance" */
    balanceLabel: string;
    /** Line under the name: what is left after paying, or how much is missing */
    note: string;
    /** Whether the balance covers the payment */
    affordable: boolean;
    /** Whether this is the chosen method */
    selected: boolean;
    /** Whether choosing is locked while the server answers */
    locked: boolean;
    /** Key that chooses the method, shown as a keycap */
    hotkey: string;
    /** Counts refusals; a new value shakes the tile while it is chosen */
    refusals: number;
    /** Delay of the entrance, in milliseconds */
    delay: number;
    /** Called when the player picks the tile */
    onchoose: (method: PaymentMethod) => void;
  }

  let {
    method,
    label,
    balance,
    balanceLabel,
    note,
    affordable,
    selected,
    locked,
    hotkey,
    refusals,
    delay,
    onchoose,
  }: Props = $props();

  let tile: HTMLButtonElement | undefined = $state();
  let seenRefusals = 0;

  const Icon = $derived(method === 'cash' ? Banknote : CreditCard);

  $effect((): void => {
    const count = refusals;
    if (count === seenRefusals) return;
    seenRefusals = count;
    if (!selected || !tile || prefersReducedMotion()) return;
    tile.animate(
      [
        { transform: 'translateX(0)' },
        { transform: 'translateX(-7px)' },
        { transform: 'translateX(6px)' },
        { transform: 'translateX(-4px)' },
        { transform: 'translateX(2px)' },
        { transform: 'translateX(0)' },
      ],
      { duration: 380, easing: 'ease-in-out' },
    );
  });
</script>

<button
  bind:this={tile}
  type="button"
  role="radio"
  class="tile"
  class:selected
  class:short={!affordable}
  class:locked={locked && !selected}
  aria-checked={selected}
  aria-disabled={!affordable || locked}
  disabled={!affordable || locked}
  style:animation-delay="{delay}ms"
  onclick={(): void => onchoose(method)}
>
  <span class="icon"><Icon size={22} strokeWidth={2} /></span>
  <span class="text">
    <span class="name">{label}<kbd>{hotkey}</kbd></span>
    <span class="note">{note}</span>
  </span>
  <span class="money">
    <span class="caption">{balanceLabel}</span>
    <span class="balance">{balance}</span>
  </span>
  <span class="mark" aria-hidden="true">
    {#if selected}<Check size={14} strokeWidth={3} />{/if}
  </span>
</button>

<style>
  .tile {
    display: grid;
    grid-template-columns: 44px 1fr auto 22px;
    align-items: center;
    gap: 14px;
    width: 100%;
    padding: 14px 16px;
    border: 2px solid var(--mid-color);
    border-radius: 12px;
    background: var(--darkest-color);
    color: var(--lightest-color);
    font: inherit;
    text-align: left;
    cursor: pointer;
    transition:
      border-color 150ms ease,
      background-color 150ms ease,
      opacity 150ms ease;
    animation: tile-in 240ms cubic-bezier(0.2, 0.8, 0.2, 1) backwards;
  }

  .tile:hover:not(:disabled):not(.selected) {
    border-color: var(--light-color);
  }

  .tile:focus-visible {
    outline: 2px solid var(--brand-color);
    outline-offset: 3px;
  }

  .selected {
    border-color: var(--brand-color);
    background: rgba(var(--brand-color-rgb), 0.07);
  }

  .tile:disabled {
    cursor: not-allowed;
  }

  .short,
  .locked {
    opacity: 0.5;
  }

  .icon {
    display: grid;
    place-items: center;
    width: 44px;
    height: 44px;
    border-radius: 10px;
    background: var(--mid-color);
    color: var(--lightest-color);
    transition:
      background-color 150ms ease,
      color 150ms ease;
  }

  .selected .icon {
    background: var(--brand-color);
    color: var(--darkest-color);
  }

  .text,
  .money {
    display: flex;
    flex-direction: column;
    min-width: 0;
  }

  .money {
    align-items: flex-end;
  }

  .name {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: var(--font-size-h5);
    font-weight: 600;
  }

  kbd {
    display: inline-grid;
    place-items: center;
    min-width: 18px;
    height: 18px;
    padding: 0 4px;
    border: 1px solid var(--mid-color);
    border-radius: 4px;
    color: var(--light-color);
    font: 500 11px/1 var(--font-family);
  }

  .note,
  .caption {
    font-size: var(--font-size-caption);
    color: var(--light-color);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .short .note {
    color: var(--error-color);
  }

  .balance {
    font-size: var(--font-size-h5);
    font-weight: 600;
    font-variant-numeric: tabular-nums;
  }

  .mark {
    display: grid;
    place-items: center;
    width: 22px;
    height: 22px;
    border: 2px solid var(--mid-color);
    border-radius: 50%;
    color: var(--darkest-color);
    transition:
      background-color 150ms ease,
      border-color 150ms ease;
  }

  .selected .mark {
    border-color: var(--brand-color);
    background: var(--brand-color);
    animation: mark-pop 260ms cubic-bezier(0.3, 1.6, 0.5, 1);
  }

  @keyframes tile-in {
    from {
      opacity: 0;
      transform: translateY(8px);
    }
  }

  @keyframes mark-pop {
    from {
      transform: scale(0.6);
    }
  }

  @media (prefers-reduced-motion: reduce) {
    .tile,
    .selected .mark {
      animation: none;
    }
  }
</style>
