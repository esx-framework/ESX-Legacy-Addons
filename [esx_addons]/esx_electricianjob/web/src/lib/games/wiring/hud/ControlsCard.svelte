<script lang="ts">
  /**
   * Panel breaker, wall switch and what the loads are doing. The control the current
   * checklist step needs is outlined.
   */
  import Panel from '../../../ui/Panel.svelte';
  import type { LoadState } from '../electrical';
  import type { BreakerAmps } from '../model';
  import { spriteUrl } from '../scene/assets';
  import { LABEL } from '../strings';

  interface Props {
    /** Breaker position */
    breakerOn: boolean;
    /** Breaker rating */
    amps: BreakerAmps;
    /** Whether the round has a wall switch */
    hasSwitch: boolean;
    /** Switch position */
    switchOn: boolean;
    /** Ceiling light state, null when there is no light */
    fixture: LoadState | null;
    /** Downstream outlets with their state */
    outlets: readonly { id: string; state: LoadState }[];
    /** Control to draw attention to */
    attention: 'breaker' | 'switch' | null;
    /** Toggles the breaker */
    ontogglebreaker: () => void;
    /** Toggles the wall switch */
    ontoggleswitch: () => void;
  }

  let {
    breakerOn,
    amps,
    hasSwitch,
    switchOn,
    fixture,
    outlets,
    attention,
    ontogglebreaker,
    ontoggleswitch,
  }: Props = $props();
</script>

<Panel caption={LABEL.panel}>
  <div class="controls">
    <button
      type="button"
      class="control"
      class:attention={attention === 'breaker'}
      onclick={ontogglebreaker}
    >
      <img src={spriteUrl(breakerOn ? 'breakerOn' : 'breakerOff')} alt="" class="breaker" />
      <span class="control-text">
        <span class="control-label">{LABEL.breaker} {amps} A</span>
        <span class="state" class:on={breakerOn}>{breakerOn ? LABEL.on : LABEL.off}</span>
      </span>
    </button>
    {#if hasSwitch}
      <button
        type="button"
        class="control"
        class:attention={attention === 'switch'}
        onclick={ontoggleswitch}
      >
        <img src={spriteUrl(switchOn ? 'switchOn' : 'switchOff')} alt="" class="switch" />
        <span class="control-text">
          <span class="control-label">{LABEL.wallSwitch}</span>
          <span class="state" class:on={switchOn}>{switchOn ? LABEL.on : LABEL.off}</span>
        </span>
      </button>
    {/if}
  </div>

  <div class="loads">
    {#if fixture !== null}
      <span class="load">
        <span class="bulb" class:lit={fixture === 'on' || fixture === 'reversed'}>
          <img src={spriteUrl('bulb')} alt="" />
        </span>
        {LABEL.fixture}
      </span>
    {/if}
    {#each outlets as outlet, i (outlet.id)}
      <span class="load">
        <span class="led" class:on={outlet.state === 'on'}></span>
        {LABEL.outlet}
        {i + 1}
      </span>
    {/each}
  </div>
</Panel>

<style>
  .controls {
    display: flex;
    gap: 10px;
  }

  .control {
    display: flex;
    flex: 1;
    align-items: center;
    gap: 10px;
    padding: 5px 10px;
    border: 2px solid transparent;
    border-radius: var(--esx-radius);
    background: var(--esx-dark);
    text-align: left;
    cursor: pointer;
    transition: border-color 140ms var(--esx-ease);
  }

  .control:hover {
    border-color: var(--esx-brand);
  }

  .control.attention {
    border-color: var(--esx-brand);
    /* A few pulses, then a steady outline: endless animations repaint the NUI every frame. */
    animation: attention 1.4s var(--esx-ease) 3;
    box-shadow: 0 0 0 3px var(--esx-brand-soft);
  }

  @keyframes attention {
    0%,
    100% {
      box-shadow: 0 0 0 0 rgba(251, 155, 4, 0.55);
    }
    60% {
      box-shadow: 0 0 0 8px rgba(251, 155, 4, 0);
    }
  }

  .breaker {
    height: 48px;
  }

  .switch {
    height: 44px;
  }

  .control-text {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .control-label {
    font-size: 12px;
    color: var(--esx-light);
  }

  .state {
    font-weight: 700;
    color: var(--esx-light);
  }

  .state.on {
    color: var(--esx-brand);
  }

  .loads {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 6px 16px;
    margin-top: 10px;
    font-size: 13px;
  }

  .load {
    display: inline-flex;
    align-items: center;
    gap: 8px;
  }

  .bulb {
    position: relative;
    display: inline-flex;
    width: 40px;
  }

  .bulb img {
    width: 100%;
    filter: grayscale(0.25) brightness(0.8);
    transition: filter 200ms var(--esx-ease);
  }

  .bulb::after {
    content: '';
    position: absolute;
    right: -6px;
    top: 50%;
    width: 32px;
    height: 32px;
    margin-top: -16px;
    border-radius: 50%;
    background: radial-gradient(circle, rgba(255, 214, 140, 0.95) 0%, rgba(255, 190, 90, 0) 70%);
    opacity: 0;
    transition: opacity 200ms var(--esx-ease);
  }

  .bulb.lit img {
    filter: none;
  }

  .bulb.lit::after {
    opacity: 1;
  }

  .led {
    width: 10px;
    height: 10px;
    border-radius: 50%;
    background: var(--esx-mid);
  }

  .led.on {
    background: var(--esx-success);
    box-shadow: 0 0 10px rgba(70, 167, 88, 0.8);
  }
</style>
