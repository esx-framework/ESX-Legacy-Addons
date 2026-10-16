<script module lang="ts">
  import type { IconName } from '../../../ui/Icon.svelte';

  /** What the badge next to the cursor says. */
  export interface Badge {
    /** Icon in front of the text */
    icon: IconName;
    /** Main text */
    text: string;
    /** Second line, e.g. a usage hint */
    hint: string | null;
    /** Coloring: action possible, blocked, warning, live voltage or neutral info */
    tone: 'action' | 'blocked' | 'warning' | 'danger' | 'info';
  }
</script>

<script lang="ts">
  /**
   * Small label that follows the pointer and says what a click or drop would do.
   */
  import Icon from '../../../ui/Icon.svelte';

  interface Props {
    /** Badge content */
    badge: Badge;
    /** Pointer x in CSS pixels */
    x: number;
    /** Pointer y in CSS pixels */
    y: number;
    /** HUD scale factor */
    scale: number;
  }

  let { badge, x, y, scale }: Props = $props();
</script>

<div
  class="badge {badge.tone}"
  style="transform: translate({x + 22 * scale}px, {y + 20 * scale}px) scale({scale})"
>
  <span class="line"><Icon name={badge.icon} size={15} />{badge.text}</span>
  {#if badge.hint}
    <span class="hint">{badge.hint}</span>
  {/if}
</div>

<style>
  .badge {
    position: absolute;
    left: 0;
    top: 0;
    display: flex;
    flex-direction: column;
    gap: 1px;
    max-width: 260px;
    padding: 6px 10px;
    border: 1px solid var(--esx-line);
    border-radius: var(--esx-radius);
    background: var(--esx-darkest-glass);
    box-shadow: 0 6px 18px rgba(0, 0, 0, 0.4);
    transform-origin: 0 0;
    pointer-events: none;
    white-space: nowrap;
  }

  .line {
    display: inline-flex;
    align-items: center;
    gap: 7px;
    font-size: 13px;
    font-weight: 600;
  }

  .hint {
    padding-left: 22px;
    font-size: 11px;
    color: var(--esx-light);
    white-space: normal;
  }

  .action {
    border-color: var(--esx-brand);
  }

  .action .line {
    color: var(--esx-brand);
  }

  .blocked {
    border-color: var(--esx-danger);
  }

  .blocked .line {
    color: #ff8d90;
  }

  .warning .line {
    color: #f5c451;
  }

  .danger {
    border-color: var(--esx-danger);
    background: rgba(120, 18, 20, 0.92);
  }
</style>
