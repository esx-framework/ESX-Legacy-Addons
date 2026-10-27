<script lang="ts">
  /**
   * One way to pay, as a card next to the others: what it is, the balance, and what stays after
   * paying or how much is missing. A method the balance cannot cover is shown but cannot be
   * chosen. A refusal from the server shakes the chosen card.
   */
  import type { TextPart } from '../lib/payment/labels';
  import type { PaymentMethod } from '../lib/payment/types';
  import { prefersReducedMotion } from '../lib/ui/motion';
  import MethodIcon from './MethodIcon.svelte';

  interface Props {
    /** Method of the card */
    method: PaymentMethod;
    /** Name of the method, e.g. "Cash" */
    label: string;
    /** Formatted balance of the method */
    balance: string;
    /** Line under the balance: what is left after paying, or how much is missing */
    note: TextPart[];
    /** Whether the balance covers the payment */
    affordable: boolean;
    /** Whether this is the chosen method */
    selected: boolean;
    /** Whether choosing is locked while the server answers */
    locked: boolean;
    /** Counts refusals; a new value shakes the card while it is chosen */
    refusals: number;
    /** Delay of the entrance, in milliseconds */
    delay: number;
    /** Lays the card out in one row, for a payment with a single method */
    wide: boolean;
    /** Called when the player picks the card */
    onchoose: (method: PaymentMethod) => void;
  }

  let {
    method,
    label,
    balance,
    note,
    affordable,
    selected,
    locked,
    refusals,
    delay,
    wide,
    onchoose,
  }: Props = $props();

  let card: HTMLButtonElement | undefined = $state();
  let seenRefusals = 0;

  $effect((): void => {
    const count = refusals;
    if (count === seenRefusals) return;
    seenRefusals = count;
    if (!selected || !card || prefersReducedMotion()) return;
    card.animate(
      [
        { transform: 'translateX(0)' },
        { transform: 'translateX(-6px)' },
        { transform: 'translateX(5px)' },
        { transform: 'translateX(-3px)' },
        { transform: 'translateX(1px)' },
        { transform: 'translateX(0)' },
      ],
      { duration: 360, easing: 'ease-in-out' },
    );
  });
</script>

<button
  bind:this={card}
  type="button"
  role="radio"
  class="card"
  class:selected
  class:short={!affordable}
  class:locked={locked && !selected}
  class:wide
  aria-checked={selected}
  aria-label="{label}, {balance}, {note.map((part: TextPart): string => part.text).join('')}"
  disabled={!affordable || locked}
  style:animation-delay="{delay}ms"
  onclick={(): void => onchoose(method)}
>
  <span class="top">
    <MethodIcon {method} active={selected} />
    <span class="radio" aria-hidden="true"></span>
  </span>
  <span class="figure">
    <span class="name">{label}</span>
    <span class="balance">{balance}</span>
  </span>
  <span class="note">
    {#each note as part, index (index)}
      {#if part.value}<b>{part.text}</b>{:else}{part.text}{/if}
    {/each}
  </span>
</button>

<style>
  .card {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    min-width: 0;
    padding: 16px;
    border: 2px solid var(--mid-color);
    border-radius: 14px;
    background: var(--darkest-color);
    color: var(--lightest-color);
    font: inherit;
    text-align: left;
    cursor: pointer;
    transition:
      border-color 160ms ease,
      background-color 160ms ease,
      opacity 160ms ease;
    animation: card-in 260ms cubic-bezier(0.2, 0.8, 0.2, 1) backwards;
  }

  .card:hover:not(:disabled):not(.selected) {
    border-color: var(--light-color);
  }

  .card:focus-visible {
    outline: 2px solid var(--brand-color);
    outline-offset: 3px;
  }

  .selected {
    border-color: var(--brand-color);
    background: rgba(var(--brand-color-rgb), 0.06);
  }

  .card:disabled {
    cursor: not-allowed;
  }

  .short,
  .locked {
    opacity: 0.45;
  }

  .top {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    width: 100%;
    margin-bottom: 14px;
  }

  .radio {
    display: grid;
    place-items: center;
    width: 20px;
    height: 20px;
    border: 2px solid var(--mid-color);
    border-radius: 50%;
    transition: border-color 160ms ease;
  }

  .radio::after {
    content: '';
    width: 10px;
    height: 10px;
    border-radius: 50%;
    background: var(--brand-color);
    transform: scale(0);
    transition: transform 220ms cubic-bezier(0.3, 1.6, 0.5, 1);
  }

  .selected .radio {
    border-color: var(--brand-color);
  }

  .selected .radio::after {
    transform: scale(1);
  }

  .figure {
    display: flex;
    flex-direction: column;
    min-width: 0;
    max-width: 100%;
  }

  .wide {
    display: grid;
    grid-template-columns: auto 1fr auto;
    align-items: center;
    gap: 16px;
  }

  .wide .top {
    width: auto;
    margin: 0;
  }

  .wide .radio {
    display: none;
  }

  .wide .note {
    margin: 0;
    text-align: right;
  }

  .name {
    font-size: var(--font-size-body-small);
    font-weight: 600;
    color: var(--light-color);
    transition: color 160ms ease;
  }

  .selected .name {
    color: var(--lightest-color);
  }

  .balance {
    max-width: 100%;
    overflow: hidden;
    text-overflow: ellipsis;
    font-size: 22px;
    font-weight: 700;
    line-height: 1.2;
    font-variant-numeric: tabular-nums;
  }

  .note {
    max-width: 100%;
    margin-top: 6px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-size: var(--font-size-caption);
    color: var(--light-color);
  }

  .note b {
    font-weight: 600;
    color: var(--lightest-color);
  }

  .short .note,
  .short .note b {
    color: var(--error-color);
  }

  @keyframes card-in {
    from {
      opacity: 0;
      transform: translateY(8px);
    }
  }

  @media (prefers-reduced-motion: reduce) {
    .card {
      animation: none;
    }
  }
</style>
