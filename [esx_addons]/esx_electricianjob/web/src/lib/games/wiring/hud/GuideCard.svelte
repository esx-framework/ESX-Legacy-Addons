<script module lang="ts">
  import type { BundleRole } from '../guide';
  import type { CableRole, Insulation } from '../model';

  /** A conductor as listed in the wiring plan. */
  export interface PlanChip {
    /** Conductor id */
    id: string;
    /** Label of its cable, null when the cable has no tag */
    label: string | null;
    /** Insulation color */
    insulation: Insulation;
  }

  /** One bundle of the wiring plan. */
  export interface PlanRow {
    /** Number on the wire markers of this bundle */
    number: number;
    /** Bundle role */
    role: BundleRole;
    /** Conductors that go into it */
    chips: readonly PlanChip[];
  }

  /** A cable as listed on the middle tier. */
  export interface CableRow {
    /** Cable id */
    id: string;
    /** Tag text, null when unlabeled */
    label: string | null;
    /** What the cable connects to */
    role: CableRole;
  }
</script>

<script lang="ts">
  /**
   * Guidance card. The first tier sees every bundle of the job, the second tier only where
   * each cable goes, the third tier only the color rules. The rules are a tab on every tier.
   */
  import type { Difficulty } from '../../../nui/messages';
  import Panel from '../../../ui/Panel.svelte';
  import { CABLE_ROLE_TEXT } from '../guide';
  import { markerStyle } from '../markers';
  import { BUNDLE_TEXT, LABEL, RULES, RULES_NOTE } from '../strings';

  interface Props {
    /** Difficulty tier of the round */
    tier: Difficulty;
    /** Bundles, shown on tier 1 */
    plan: readonly PlanRow[];
    /** Cables, shown on tier 2 */
    cables: readonly CableRow[];
    /** Highlights conductors in the scene while a plan row is hovered, null to clear */
    onhighlight: (ids: readonly string[] | null) => void;
  }

  let { tier, plan, cables, onhighlight }: Props = $props();

  type Tab = 'plan' | 'rules';

  let tab: Tab = $state('plan');
  let hasPlan: boolean = $derived(tier < 3);
  let shown: Tab = $derived(hasPlan ? tab : 'rules');

  const SWATCH: Readonly<Record<Insulation, string>> = {
    black: '#1e1f22',
    red: '#b0221d',
    white: '#e6e2d7',
    green: '#2c7a37',
    bare: '#c27744',
  };
</script>

<Panel>
  <div class="tabs" role="tablist">
    {#if hasPlan}
      <button
        type="button"
        role="tab"
        class="tab"
        class:active={shown === 'plan'}
        aria-selected={shown === 'plan'}
        onclick={(): void => {
          tab = 'plan';
        }}
      >
        {tier === 1 ? LABEL.plan : LABEL.cables}
      </button>
    {/if}
    <button
      type="button"
      role="tab"
      class="tab"
      class:active={shown === 'rules'}
      aria-selected={shown === 'rules'}
      onclick={(): void => {
        tab = 'rules';
      }}
    >
      {LABEL.rules}
    </button>
  </div>

  {#if shown === 'plan' && tier === 1}
    <ul class="rows">
      {#each plan as row (row.role)}
        <li
          class="row"
          onmouseenter={(): void => onhighlight(row.chips.map((chip: PlanChip): string => chip.id))}
          onmouseleave={(): void => onhighlight(null)}
        >
          <span class="row-head">
            <span
              class="number"
              style="background: {markerStyle(row.number).fill}; color: {markerStyle(row.number)
                .text}"
            >
              {row.number}
            </span>
            <span class="row-name">{BUNDLE_TEXT[row.role][0]}</span>
            <span class="row-hint">{BUNDLE_TEXT[row.role][1]}</span>
          </span>
          <span class="chips">
            {#each row.chips as chip (chip.id)}
              <span class="chip">
                <span
                  class="swatch"
                  class:outlined={chip.insulation === 'white'}
                  style="background: {SWATCH[chip.insulation]}"
                ></span>
                {chip.label ?? '?'}
              </span>
            {/each}
          </span>
        </li>
      {/each}
    </ul>
  {:else if shown === 'plan'}
    <ul class="rows">
      {#each cables as cable (cable.id)}
        <li class="cable">
          <span class="tag" class:missing={cable.label === null}>
            {cable.label ?? LABEL.unlabeled}
          </span>
          <span class="row-hint">
            {cable.label === null ? LABEL.unlabeledHint : CABLE_ROLE_TEXT[cable.role]}
          </span>
        </li>
      {/each}
    </ul>
  {:else}
    <ul class="rules">
      {#each RULES as [color, meaning] (color)}
        <li class="rule"><span class="rule-color">{color}</span>{meaning}</li>
      {/each}
    </ul>
    <p class="note">{RULES_NOTE}</p>
  {/if}
</Panel>

<style>
  .tabs {
    display: flex;
    gap: 4px;
    margin: -4px 0 12px;
  }

  .tab {
    padding: 4px 10px;
    border: 0;
    border-radius: var(--esx-radius-sm);
    background: transparent;
    font-size: var(--esx-caption);
    font-weight: 600;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    color: var(--esx-light);
    cursor: pointer;
  }

  .tab.active {
    background: var(--esx-brand-soft);
    color: var(--esx-brand);
  }

  .rows,
  .rules {
    margin: 0;
    padding: 0;
    list-style: none;
  }

  .row {
    padding: 7px 8px;
    border-radius: var(--esx-radius);
    transition: background-color 140ms var(--esx-ease);
  }

  .row:hover {
    background: var(--esx-dark);
  }

  .row-head {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .number {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    flex: none;
    width: 20px;
    height: 20px;
    border-radius: 50%;
    font-size: 12px;
    font-weight: 700;
    box-shadow: 0 0 0 2px rgba(22, 22, 22, 0.9);
  }

  .row-name {
    font-size: 13px;
    font-weight: 600;
  }

  .row-hint {
    font-size: 12px;
    color: var(--esx-light);
  }

  .chips {
    display: flex;
    flex-wrap: wrap;
    gap: 5px;
    margin-top: 5px;
  }

  .chip {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    padding: 2px 8px 2px 4px;
    border-radius: 10px;
    background: var(--esx-mid);
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.04em;
  }

  .swatch {
    width: 11px;
    height: 11px;
    border-radius: 50%;
  }

  .swatch.outlined {
    box-shadow: inset 0 0 0 1px rgba(0, 0, 0, 0.35);
  }

  .cable {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 5px 0;
  }

  .tag {
    min-width: 64px;
    padding: 2px 8px;
    border-radius: 3px;
    background: #d9c9a3;
    color: #1a1c24;
    font-family: 'Permanent Marker', var(--esx-font);
    font-size: 13px;
    text-align: center;
  }

  .tag.missing {
    background: var(--esx-mid);
    color: var(--esx-light);
    font-family: var(--esx-font);
    font-size: 11px;
  }

  .rule {
    display: flex;
    gap: 10px;
    padding: 3px 0;
    font-size: 13px;
    color: var(--esx-light);
  }

  .rule-color {
    min-width: 118px;
    font-weight: 600;
    color: var(--esx-lightest);
  }

  .note {
    margin-top: 10px;
    font-size: 12px;
    line-height: 1.5;
    color: var(--esx-light);
  }
</style>
