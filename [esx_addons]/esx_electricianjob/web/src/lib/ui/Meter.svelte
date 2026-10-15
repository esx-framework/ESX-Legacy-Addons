<script lang="ts">
  /**
   * Horizontal progress bar, used for the round timer.
   */

  interface Props {
    /** Fill from 0 to 1 */
    value: number;
    /** Switches the fill to the danger color, e.g. when time is running out */
    critical?: boolean;
  }

  let { value, critical = false }: Props = $props();

  let percent: number = $derived(Math.round(Math.min(1, Math.max(0, value)) * 1000) / 10);
</script>

<div class="meter" role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={percent}>
  <div class="fill" class:critical style="width: {percent}%"></div>
</div>

<style>
  .meter {
    height: 6px;
    overflow: hidden;
    border-radius: 3px;
    background: var(--esx-mid);
  }

  .fill {
    height: 100%;
    border-radius: 3px;
    background: var(--esx-brand);
    transition:
      width 250ms linear,
      background-color 300ms var(--esx-ease);
  }

  .critical {
    background: var(--esx-danger);
  }
</style>
