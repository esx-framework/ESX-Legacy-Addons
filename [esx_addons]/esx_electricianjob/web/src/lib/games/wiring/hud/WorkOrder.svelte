<script module lang="ts">
  import type { BundleRole } from '../guide';
  import type { CableRole, Insulation } from '../model';

  /** A conductor as listed under connections. */
  export interface PlanChip {
    /** Conductor id */
    id: string;
    /** Label of its cable, null when the cable has no tag */
    label: string | null;
    /** Insulation color */
    insulation: Insulation;
  }

  /** One bundle of the connection list. */
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
   * The job as a printed service order on a clipboard: customer, site, what was reported,
   * the procedure with hand-drawn ticks and, depending on the tier, the connection list or
   * the cables in the box. The step in progress is marked with a highlighter.
   *
   * Everything on the sheet uses the ESX palette; only wire swatches and bundle numbers
   * show the colors of the things they stand for in the scene.
   */
  import type { Difficulty } from '../../../nui/messages';
  import Icon from '../../../ui/Icon.svelte';
  import { CABLE_ROLE_TEXT, type ChecklistStep } from '../guide';
  import { markerStyle } from '../markers';
  import { BUNDLE_TEXT, LABEL, RULES, RULES_NOTE, STEP_TEXT, type RuleSwatch } from '../strings';
  import type { WorkOrder } from '../work-order';

  interface Props {
    /** Customer and site details */
    order: WorkOrder;
    /** What the job is about */
    briefing: string;
    /** Job grade of the difficulty tier, e.g. Apprentice */
    grade: string;
    /** Difficulty tier of the round */
    tier: Difficulty;
    /** Procedure steps in order */
    steps: readonly ChecklistStep[];
    /** Bundles, listed on tier 1 */
    plan: readonly PlanRow[];
    /** Cables, listed on tier 2 */
    cables: readonly CableRow[];
    /** Highlights conductors in the scene while a bundle is hovered, null to clear */
    onhighlight: (ids: readonly string[] | null) => void;
  }

  let { order, briefing, grade, tier, steps, plan, cables, onhighlight }: Props = $props();

  /** One bar of the decorative barcode. */
  interface Bar {
    /** Left edge in barcode units */
    x: number;
    /** Width in barcode units */
    width: number;
  }

  const SWATCH: Readonly<Record<Insulation, string>> = {
    black: '#1e1f22',
    red: '#b0221d',
    white: '#ffffff',
    green: '#2c7a37',
    bare: '#c27744',
  };

  /** White with a band of black tape around it. */
  const TAPED = [
    `linear-gradient(90deg, ${SWATCH.white} 28%, ${SWATCH.black} 28%,`,
    `${SWATCH.black} 72%, ${SWATCH.white} 72%)`,
  ].join(' ');

  const RULE_SWATCH: Readonly<Record<RuleSwatch, string>> = {
    black: SWATCH.black,
    red: SWATCH.red,
    white: SWATCH.white,
    taped: TAPED,
    bare: SWATCH.bare,
  };

  let current: string | undefined = $derived(
    steps.find((step: ChecklistStep): boolean => !step.done)?.id,
  );

  /** Bars encode the order number, four bits per hex digit, between guard bars. */
  let bars: Bar[] = $derived.by((): Bar[] => {
    const widths: number[] = [1, 1, 1, 1];
    for (const digit of order.number) {
      const value = parseInt(digit, 16);
      for (let bit = 0; bit < 4; bit++) widths.push(1 + ((value >> bit) & 1));
    }
    widths.push(1, 1, 1);
    const result: Bar[] = [];
    let x = 0;
    widths.forEach((width: number, index: number): void => {
      if (index % 2 === 0) result.push({ x, width });
      x += width;
    });
    return result;
  });
  let barcodeWidth: number = $derived(
    bars.reduce((end: number, bar: Bar): number => Math.max(end, bar.x + bar.width), 0),
  );
</script>

<div class="clipboard">
  <article class="sheet" aria-label="{LABEL.serviceOrder} {order.number}">
    <header class="head">
      <span class="logo"><Icon name="zap" size={18} /></span>
      <span class="head-text">
        <span class="kind">{LABEL.serviceOrder}</span>
        <h4 class="title">{LABEL.title}</h4>
      </span>
      <span class="ref">
        <svg
          class="barcode"
          viewBox="0 0 {barcodeWidth} 10"
          preserveAspectRatio="none"
          aria-hidden="true"
        >
          {#each bars as bar (bar.x)}
            <rect x={bar.x} width={bar.width} height="10" />
          {/each}
        </svg>
        <span class="number">{LABEL.orderNumber} {order.number}</span>
      </span>
    </header>

    <dl class="fields">
      <div class="field">
        <dt>{LABEL.customer}</dt>
        <dd>{order.customer}</dd>
      </div>
      <div class="field">
        <dt>{LABEL.site}</dt>
        <dd>{order.address}</dd>
      </div>
      <div class="field">
        <dt>{LABEL.location}</dt>
        <dd>{order.location}</dd>
      </div>
      <div class="field">
        <dt>{LABEL.grade}</dt>
        <dd class="grade">
          {grade}
          <span class="grade-pips" aria-label="{tier} / 3">
            {#each [1, 2, 3] as pip (pip)}
              <span class="grade-pip" class:on={pip <= tier}></span>
            {/each}
          </span>
        </dd>
      </div>
    </dl>

    <section class="block brief">
      <p class="complaint">
        <span class="label inline">{LABEL.reported}</span>“{order.complaint}”
      </p>
      <p class="job"><span class="label inline">{LABEL.job}</span>{briefing}</p>
    </section>

    <section class="block">
      <h6 class="label">{LABEL.procedure}</h6>
      <ol class="steps">
        {#each steps as step (step.id)}
          <li class="step" class:done={step.done} class:current={step.id === current}>
            <span class="box">
              {#if step.done}
                <svg class="tick" viewBox="0 0 24 24" aria-hidden="true">
                  <path d="M3.5 13.2c2.4 1.3 4.1 3.3 5.6 6.1C11.9 12.4 16 7.2 22 3.2" />
                </svg>
              {/if}
            </span>
            <span class="text"><span class="ink">{STEP_TEXT[step.id]}</span></span>
            {#if step.progress && !step.done}
              <span class="count">{step.progress[0]}/{step.progress[1]}</span>
            {/if}
          </li>
        {/each}
      </ol>
    </section>

    {#if tier === 1}
      <section class="block">
        <h6 class="label">{LABEL.connections}</h6>
        <ul class="bundles">
          {#each plan as row (row.role)}
            <li
              class="bundle"
              onmouseenter={(): void =>
                onhighlight(row.chips.map((chip: PlanChip): string => chip.id))}
              onmouseleave={(): void => onhighlight(null)}
            >
              <span
                class="bundle-number"
                style="background: {markerStyle(row.number).fill}; color: {markerStyle(row.number)
                  .text}"
              >
                {row.number}
              </span>
              <span class="bundle-name">{BUNDLE_TEXT[row.role]}</span>
              <span class="chips">
                {#each row.chips as chip (chip.id)}
                  <span class="chip">
                    <span
                      class="swatch"
                      class:light={chip.insulation === 'white'}
                      style="background: {SWATCH[chip.insulation]}"
                    ></span>
                    {chip.label ?? '?'}
                  </span>
                {/each}
              </span>
            </li>
          {/each}
        </ul>
      </section>
    {:else if tier === 2}
      <section class="block">
        <h6 class="label">{LABEL.cables}</h6>
        <ul class="cables">
          {#each cables as cable (cable.id)}
            <li class="cable">
              <span class="tag" class:missing={cable.label === null}>
                {cable.label ?? LABEL.unlabeled}
              </span>
              <span class="cable-role">
                {cable.label === null ? LABEL.unlabeledHint : CABLE_ROLE_TEXT[cable.role]}
              </span>
            </li>
          {/each}
        </ul>
      </section>
    {/if}

    <footer class="block legend">
      <h6 class="label">{LABEL.colorCode}</h6>
      <ul class="rules">
        {#each RULES as rule (rule.colors)}
          <li class="rule">
            <span class="rule-swatches">
              {#each rule.swatches as swatch (swatch)}
                <span
                  class="swatch"
                  class:light={swatch === 'white' || swatch === 'taped'}
                  style="background: {RULE_SWATCH[swatch]}"
                ></span>
              {/each}
            </span>
            <span><strong>{rule.colors}</strong> {rule.role}</span>
          </li>
        {/each}
      </ul>
      {#if tier === 3}
        <p class="note">{RULES_NOTE}</p>
      {/if}
    </footer>
  </article>
  <span class="clip" aria-hidden="true"></span>
</div>

<style>
  .clipboard {
    position: relative;
    width: 380px;
    border-style: solid;
    border-width: 70px 14px 16px;
    border-image: url('../../../../assets/order/clipboard.webp') 140 28 32 fill / 70px 14px 16px
      stretch;
    filter: drop-shadow(0 16px 26px rgba(0, 0, 0, 0.45)) drop-shadow(0 2px 4px rgba(0, 0, 0, 0.4));
  }

  .clip {
    position: absolute;
    left: 65px;
    top: -72px;
    width: 223px;
    height: 63px;
    background: url('../../../../assets/order/clipboard-clip.webp') 0 0 / 100% 100% no-repeat;
    filter: drop-shadow(0 3px 2px rgba(0, 0, 0, 0.35));
  }

  .sheet {
    position: relative;
    margin-top: -38px;
    padding: 40px 18px 16px;
    border-radius: 2px;
    background: var(--esx-lightest) url('../../../../assets/order/paper.webp') 0 0 / 128px 128px;
    box-shadow:
      0 1px 0 rgba(0, 0, 0, 0.3),
      0 4px 10px rgba(0, 0, 0, 0.35);
    color: var(--esx-darkest);
  }

  .head {
    display: flex;
    align-items: center;
    gap: 10px;
    padding-bottom: 10px;
    border-bottom: 2px solid var(--esx-brand);
  }

  .logo {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    flex: none;
    width: 34px;
    height: 34px;
    border-radius: var(--esx-radius-sm);
    background: var(--esx-brand);
    color: var(--esx-darkest);
  }

  .head-text {
    display: flex;
    flex-direction: column;
    min-width: 0;
    line-height: 1.2;
  }

  .kind {
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.14em;
    text-transform: uppercase;
    color: var(--esx-mid);
  }

  .title {
    font-size: var(--esx-h4);
    font-weight: 700;
  }

  .ref {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 3px;
    margin-left: auto;
  }

  .barcode {
    display: block;
    width: 84px;
    height: 22px;
    fill: var(--esx-darkest);
    shape-rendering: crispEdges;
  }

  .number {
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.06em;
    color: var(--esx-mid);
    font-variant-numeric: tabular-nums;
  }

  .fields {
    display: grid;
    grid-template-columns: 1fr 1.25fr;
    gap: 6px 14px;
    margin: 0;
    padding: 8px 0;
    border-bottom: 1px solid rgba(22, 22, 22, 0.14);
  }

  .field {
    min-width: 0;
  }

  .field dt,
  .label {
    margin: 0;
    font-size: 10.5px;
    font-weight: 600;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    color: var(--esx-mid);
    opacity: 0.8;
  }

  .field dt {
    line-height: 1.3;
  }

  .field dd {
    margin: 0;
    overflow: hidden;
    font-size: 13px;
    font-weight: 500;
    white-space: nowrap;
    text-overflow: ellipsis;
  }

  .grade {
    display: flex;
    align-items: center;
    gap: 7px;
  }

  .grade-pips {
    display: inline-flex;
    gap: 3px;
  }

  .grade-pip {
    width: 7px;
    height: 7px;
    border: 1.5px solid var(--esx-light);
    border-radius: 50%;
  }

  .grade-pip.on {
    border-color: var(--esx-brand);
    background: var(--esx-brand);
  }

  .block {
    padding-top: 9px;
  }

  .complaint,
  .job {
    font-size: 13px;
    line-height: 1.4;
  }

  .job {
    margin-top: 3px;
  }

  .complaint {
    font-style: italic;
    color: var(--esx-mid);
  }

  .label.inline {
    display: inline;
    margin-right: 7px;
    font-style: normal;
  }

  .steps,
  .bundles,
  .cables,
  .rules {
    margin: 0;
    padding: 0;
    list-style: none;
  }

  .steps {
    margin-top: 4px;
  }

  .step {
    display: flex;
    align-items: center;
    gap: 9px;
    padding: 1px 0;
    font-size: 13px;
    line-height: 1.4;
  }

  .box {
    position: relative;
    flex: none;
    width: 14px;
    height: 14px;
    border: 1.5px solid var(--esx-mid);
    border-radius: 2px;
  }

  .tick {
    position: absolute;
    left: -3px;
    top: -7px;
    width: 22px;
    height: 22px;
    overflow: visible;
    fill: none;
    stroke: var(--esx-brand);
    stroke-width: 3.2;
    stroke-linecap: round;
    stroke-linejoin: round;
    stroke-dasharray: 32;
    animation: draw-tick 260ms ease-out both;
  }

  @keyframes draw-tick {
    from {
      stroke-dashoffset: 32;
    }
    to {
      stroke-dashoffset: 0;
    }
  }

  .text {
    min-width: 0;
  }

  .step.done .text {
    color: var(--esx-light);
  }

  .step.current .ink {
    padding: 0 3px;
    margin: 0 -3px;
    border-radius: 2px;
    background: linear-gradient(
      transparent 10%,
      rgba(251, 155, 4, 0.42) 10%,
      rgba(251, 155, 4, 0.42) 90%,
      transparent 90%
    );
    font-weight: 600;
    box-decoration-break: clone;
  }

  .count {
    margin-left: auto;
    padding-left: 8px;
    font-size: 12px;
    font-weight: 600;
    color: var(--esx-mid);
    font-variant-numeric: tabular-nums;
  }

  .bundles {
    margin: 3px -6px 0;
  }

  .bundle {
    display: grid;
    grid-template-columns: 20px 66px 1fr;
    align-items: center;
    gap: 8px;
    padding: 3px 6px;
    border-radius: var(--esx-radius-sm);
    transition: background-color 140ms var(--esx-ease);
  }

  .bundle:hover {
    background: rgba(251, 155, 4, 0.16);
  }

  .bundle-number {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    flex: none;
    width: 20px;
    height: 20px;
    border-radius: 50%;
    font-size: 12px;
    font-weight: 700;
    box-shadow: 0 0 0 1.5px var(--esx-darkest);
  }

  .bundle-name {
    font-size: 13px;
    font-weight: 600;
    white-space: nowrap;
  }

  .chips {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
  }

  .chip {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 0 5px 0 3px;
    border: 1px solid rgba(22, 22, 22, 0.22);
    border-radius: 10px;
    font-family: 'Permanent Marker', var(--esx-font);
    font-size: 10px;
    line-height: 1.6;
    white-space: nowrap;
  }

  .chip .swatch {
    width: 9px;
    height: 9px;
  }

  .swatch {
    display: inline-block;
    width: 11px;
    height: 11px;
    border-radius: 50%;
  }

  .swatch.light {
    box-shadow: inset 0 0 0 1px rgba(22, 22, 22, 0.45);
  }

  .cables {
    margin-top: 4px;
  }

  .cable {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 2px 0;
  }

  .tag {
    min-width: 70px;
    padding: 0 8px;
    border: 1px solid rgba(22, 22, 22, 0.22);
    border-radius: var(--esx-radius-sm);
    font-family: 'Permanent Marker', var(--esx-font);
    font-size: 13px;
    text-align: center;
  }

  .tag.missing {
    border-style: dashed;
    font-family: var(--esx-font);
    font-size: 11px;
    color: var(--esx-mid);
  }

  .cable-role {
    font-size: 12px;
    color: var(--esx-mid);
  }

  .legend {
    margin-top: 9px;
    border-top: 1px solid rgba(22, 22, 22, 0.14);
  }

  .rules {
    display: grid;
    grid-template-columns: max-content max-content;
    justify-content: space-between;
    gap: 2px 16px;
    margin-top: 4px;
  }

  .rule {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 12px;
    color: var(--esx-mid);
    white-space: nowrap;
  }

  .rule strong {
    font-weight: 600;
    color: var(--esx-darkest);
  }

  .rule-swatches {
    display: inline-flex;
    flex: none;
    gap: 2px;
    width: 24px;
  }

  .note {
    margin-top: 6px;
    font-size: 11.5px;
    line-height: 1.45;
    color: var(--esx-mid);
  }
</style>
