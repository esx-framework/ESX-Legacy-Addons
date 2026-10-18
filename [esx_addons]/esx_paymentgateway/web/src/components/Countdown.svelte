<script lang="ts">
  /**
   * Time left before the server lets the payment expire: a small spinner and the minutes and
   * seconds. Every digit has a fixed slot, so the clock never shifts as the digits change. In the
   * last seconds it turns to the error color, so the player is not surprised when it closes.
   */
  import { formatClock } from '../lib/payment/format';

  interface Props {
    /** performance.now() at which the payment expires */
    deadline: number;
  }

  let { deadline }: Props = $props();

  /** Below this many milliseconds the clock warns. */
  const LOW_MS = 15_000;

  let now: number = $state(performance.now());
  const left = $derived(Math.max(0, deadline - now));
  const clock = $derived(formatClock(left));

  $effect((): (() => void) => {
    const timer = setInterval((): void => {
      now = performance.now();
    }, 250);
    return (): void => clearInterval(timer);
  });
</script>

<span class="countdown" class:low={left <= LOW_MS} role="timer" aria-label={clock}>
  <span class="spinner" aria-hidden="true"></span>
  <span class="time" aria-hidden="true">
    {#each clock.split('') as char, index (index)}
      <span class:digit={char !== ':'}>{char}</span>
    {/each}
  </span>
</span>

<style>
  .countdown {
    --tone: var(--brand-color);
    display: inline-flex;
    align-items: center;
    gap: 7px;
    height: 26px;
    padding: 0 10px 0 7px;
    border: 1px solid var(--mid-color);
    border-radius: 999px;
    color: var(--light-color);
    transition:
      color 200ms ease,
      border-color 200ms ease;
  }

  .low {
    --tone: var(--error-color);
    border-color: var(--error-color);
    color: var(--error-color);
  }

  .spinner {
    width: 12px;
    height: 12px;
    border: 2px solid var(--mid-color);
    border-top-color: var(--tone);
    border-radius: 50%;
    animation: spin 900ms linear infinite;
  }

  .time {
    display: inline-flex;
    font-size: var(--font-size-caption);
    font-weight: 600;
    line-height: 1;
  }

  .digit {
    display: inline-block;
    width: 0.62em;
    text-align: center;
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }

  @media (prefers-reduced-motion: reduce) {
    .spinner {
      animation-duration: 3s;
    }
  }
</style>
