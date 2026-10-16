<script lang="ts">
  /**
   * Time left and mistakes, top center. Kept off the work order so the order reads like a
   * document and the clock stays in view wherever the player looks.
   */
  import Icon from '../../../ui/Icon.svelte';
  import Meter from '../../../ui/Meter.svelte';
  import { LABEL } from '../strings';

  interface Props {
    /** Seconds left */
    remaining: number;
    /** Seconds the round started with */
    timeLimit: number;
    /** Mistakes made so far */
    mistakes: number;
    /** Mistakes allowed before the round is lost */
    maxMistakes: number;
  }

  let { remaining, timeLimit, mistakes, maxMistakes }: Props = $props();

  /** Below this many seconds the clock turns red. */
  const CRITICAL_SECONDS = 30;

  let critical: boolean = $derived(remaining <= CRITICAL_SECONDS);
  let timeLabel: string = $derived(
    `${Math.floor(remaining / 60)}:${String(Math.max(0, remaining) % 60).padStart(2, '0')}`,
  );
  let pips: number[] = $derived(
    Array.from({ length: maxMistakes }, (_: unknown, i: number): number => i),
  );
</script>

<div class="status">
  <div class="clock" class:critical>
    <Icon name="clock" size={18} />
    <span class="time">{timeLabel}</span>
    <span class="meter"><Meter value={remaining / timeLimit} {critical} /></span>
  </div>
  <span class="divider"></span>
  <div class="mistakes" aria-label="{LABEL.mistakes}: {mistakes} / {maxMistakes}">
    <span class="label">{LABEL.mistakes}</span>
    <span class="pips">
      {#each pips as i (i)}
        <span class="pip" class:used={i < mistakes}></span>
      {/each}
    </span>
  </div>
</div>

<style>
  .status {
    display: flex;
    align-items: center;
    gap: 16px;
    padding: 10px 18px;
    border: 1px solid var(--esx-line);
    border-radius: var(--esx-radius-lg);
    background: var(--esx-darkest-glass);
    box-shadow: var(--esx-shadow);
  }

  .clock {
    display: flex;
    align-items: center;
    gap: 9px;
    color: var(--esx-brand);
  }

  .clock.critical {
    color: var(--esx-danger);
  }

  .time {
    min-width: 44px;
    font-size: var(--esx-h5);
    font-weight: 600;
    color: var(--esx-lightest);
    font-variant-numeric: tabular-nums;
  }

  .clock.critical .time {
    color: var(--esx-danger);
  }

  .meter {
    width: 150px;
  }

  .divider {
    width: 1px;
    height: 22px;
    background: var(--esx-mid);
  }

  .mistakes {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .label {
    font-size: var(--esx-caption);
    font-weight: 600;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    color: var(--esx-light);
  }

  .pips {
    display: flex;
    gap: 6px;
  }

  .pip {
    width: 10px;
    height: 10px;
    border: 2px solid var(--esx-mid);
    border-radius: 50%;
  }

  .pip.used {
    border-color: var(--esx-danger);
    background: var(--esx-danger);
  }
</style>
