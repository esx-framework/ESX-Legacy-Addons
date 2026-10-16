<script lang="ts">
  /**
   * Work order card: what to do, time left, mistakes and the step checklist with the current
   * step highlighted.
   */
  import Meter from '../../../ui/Meter.svelte';
  import Icon from '../../../ui/Icon.svelte';
  import Panel from '../../../ui/Panel.svelte';
  import type { ChecklistStep } from '../guide';
  import { LABEL, STEP_TEXT } from '../strings';

  interface Props {
    /** Seed of the round, shown as work order number */
    seed: number;
    /** What the job is about */
    briefing: string;
    /** Seconds left */
    remaining: number;
    /** Seconds the round started with */
    timeLimit: number;
    /** Mistakes made so far */
    mistakes: number;
    /** Mistakes allowed before the round is lost */
    maxMistakes: number;
    /** Checklist steps in order */
    steps: readonly ChecklistStep[];
    /** Job grade of the difficulty tier, e.g. Apprentice */
    grade: string;
    /** Difficulty tier, 1 to 3 */
    level: number;
  }

  let { seed, briefing, remaining, timeLimit, mistakes, maxMistakes, steps, grade, level }: Props =
    $props();

  let current: string | undefined = $derived(
    steps.find((step: ChecklistStep): boolean => !step.done)?.id,
  );
  let timeLabel: string = $derived(
    `${Math.floor(remaining / 60)}:${String(Math.max(0, remaining) % 60).padStart(2, '0')}`,
  );
  let pips: number[] = $derived(
    Array.from({ length: maxMistakes }, (_: unknown, i: number): number => i),
  );
</script>

<Panel caption="{LABEL.workOrder} #{seed.toString(16).toUpperCase().padStart(8, '0')}">
  <div class="heading">
    <h4 class="title">{LABEL.title}</h4>
    <span class="grade" title="Difficulty {level} of 3">
      {grade}
      <span class="grade-pips">
        {#each [1, 2, 3] as pip (pip)}
          <span class="grade-pip" class:on={pip <= level}></span>
        {/each}
      </span>
    </span>
  </div>
  <p class="briefing">{briefing}</p>

  <div class="timer">
    <Meter value={remaining / timeLimit} critical={remaining <= 30} />
    <span class="time" class:critical={remaining <= 30}>{timeLabel}</span>
  </div>
  <div class="mistakes">
    <span>{LABEL.mistakes}</span>
    <span class="pips">
      {#each pips as i (i)}
        <span class="pip" class:used={i < mistakes}></span>
      {/each}
    </span>
  </div>

  <ol class="steps" aria-label={LABEL.checklist}>
    {#each steps as step (step.id)}
      <li class="step" class:done={step.done} class:current={step.id === current}>
        <span class="mark">
          {#if step.done}
            <Icon name="check" size={12} />
          {/if}
        </span>
        <span class="text">{STEP_TEXT[step.id]}</span>
        {#if step.progress && !step.done}
          <span class="count">{step.progress[0]}/{step.progress[1]}</span>
        {/if}
      </li>
    {/each}
  </ol>
</Panel>

<style>
  .heading {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 10px;
  }

  .title {
    font-size: var(--esx-h4);
    font-weight: 600;
  }

  .grade {
    display: inline-flex;
    align-items: center;
    gap: 7px;
    padding: 3px 9px;
    border-radius: 12px;
    background: var(--esx-brand-soft);
    color: var(--esx-brand);
    font-size: 12px;
    font-weight: 600;
  }

  .grade-pips {
    display: inline-flex;
    gap: 3px;
  }

  .grade-pip {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: rgba(251, 155, 4, 0.3);
  }

  .grade-pip.on {
    background: var(--esx-brand);
  }

  .briefing {
    margin-top: 4px;
    font-size: 13px;
    color: var(--esx-light);
  }

  .timer {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-top: 14px;
  }

  .timer :global(.meter) {
    flex: 1;
  }

  .time {
    min-width: 40px;
    font-weight: 600;
    text-align: right;
  }

  .time.critical {
    color: var(--esx-danger);
  }

  .mistakes {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-top: 8px;
    font-size: 13px;
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

  .steps {
    margin: 14px 0 0;
    padding: 12px 0 0;
    border-top: 1px solid var(--esx-line);
    list-style: none;
  }

  .step {
    display: flex;
    align-items: center;
    gap: 9px;
    padding: 3px 0;
    font-size: 13px;
    color: var(--esx-light);
    transition: color 200ms var(--esx-ease);
  }

  .mark {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    flex: none;
    width: 16px;
    height: 16px;
    border: 2px solid var(--esx-mid);
    border-radius: 50%;
  }

  .step.done {
    color: rgba(150, 150, 150, 0.7);
  }

  .step.done .text {
    text-decoration: line-through;
    text-decoration-color: rgba(150, 150, 150, 0.6);
  }

  .step.done .mark {
    border-color: var(--esx-brand);
    background: var(--esx-brand);
    color: var(--esx-darkest);
  }

  .step.current {
    color: var(--esx-lightest);
    font-weight: 600;
  }

  .step.current .mark {
    border-color: var(--esx-brand);
    box-shadow: 0 0 0 3px var(--esx-brand-soft);
  }

  .count {
    margin-left: auto;
    font-size: 12px;
    font-weight: 600;
    color: var(--esx-brand);
  }
</style>
