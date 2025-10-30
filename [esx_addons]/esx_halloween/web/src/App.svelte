<script lang="ts">
  import { onMount } from 'svelte';
  import { useNuiEvent } from './utils/useNuiEvent';
  import { fetchNui } from './utils/fetchNui';
  import type { NotificationData } from './types/nui';
  import { notificationManager } from './stores/NotificationManager.svelte';
  import { ghostManager } from './stores/GhostManager.svelte';
  import { trickOrTreatManager } from './stores/TrickOrTreatManager.svelte';
  import NotificationContainer from './components/NotificationContainer.svelte';
  import GhostChoice from './components/GhostChoice.svelte';
  import GhostHUD from './components/GhostHUD.svelte';
  import JumpscareEffect from './components/JumpscareEffect.svelte';
  import TrickOrTreatHUD from './components/TrickOrTreatHUD.svelte';
  import TrickOrTreatReward from './components/TrickOrTreatReward.svelte';
  import ParticleEffect from './components/ParticleEffect.svelte';
  import { soundManager, initializeSounds } from './utils/soundManager';
  import './styles/global.css';
  import './styles/animations.css';

  // Particle effect reference for triggering effects from event handlers
  let particleEffect: ParticleEffect;

  /**
   * Applies theme colors to CSS custom properties
   * @param colors - Theme color configuration from ESX convars
   */
  function applyThemeColors(colors: Record<string, string>) {
    const root = document.documentElement;
    if (colors.primary) root.style.setProperty('--primary-color', colors.primary);
    if (colors.secondary) root.style.setProperty('--secondary-color', colors.secondary);
    if (colors.background) root.style.setProperty('--background-color', colors.background);
    if (colors.accent) root.style.setProperty('--accent-color', colors.accent);
    if (colors.logoUrl) root.style.setProperty('--logo-url', colors.logoUrl);
  }

  /**
   * Fetches theme colors from Lua when component mounts
   * Prevents race conditions by waiting for NUI to be ready
   */
  onMount(async () => {
    try {
      const colors = await fetchNui<Record<string, string>>('ready');
      applyThemeColors(colors);

      // Initialize sound manager
      initializeSounds();
    } catch (error) {
      console.error('[ESX Halloween] Failed to fetch theme colors:', error);
    }
  });

  useNuiEvent<NotificationData>('showNotification', (data) => {
    notificationManager.show(data);
  });

  useNuiEvent<{ forced?: boolean }>('showGhostChoice', (data) => {
    ghostManager.showChoice(data?.forced || false);
  });

  useNuiEvent<{ maxDuration: number; exitKey: string; scareKey: string }>('showGhostHUD', (data) => {
    ghostManager.showHUD(data.maxDuration, data.exitKey, data.scareKey || 'E');
  });

  useNuiEvent('hideGhostHUD', () => {
    ghostManager.hideHUD();
  });

  useNuiEvent<{ soundVolume?: number }>('triggerJumpscare', (data) => {
    ghostManager.triggerJumpscare(data?.soundVolume || 0.8);
  });

  /**
   * =================================================================
   * TRICK-OR-TREAT EVENT HANDLERS
   * =================================================================
   */

  useNuiEvent<{ totalHouses: number; timeRemaining: number }>('trickOrTreatRoundStart', (data) => {
    trickOrTreatManager.startRound(data.totalHouses, data.timeRemaining);
    soundManager.play('trick-success');
  });

  useNuiEvent<{ collected: number; totalHouses: number }>('trickOrTreatRoundEnd', (data) => {
    trickOrTreatManager.endRound();
  });

  useNuiEvent<{ currentHouses: number; totalHouses: number; timeRemaining: number }>(
    'trickOrTreatProgress',
    (data) => {
      trickOrTreatManager.updateProgress(data.currentHouses, data.timeRemaining);
    }
  );

  useNuiEvent<{ rewardType: string; rewardItem: string; rewardAmount: number }>(
    'trickOrTreatCollect',
    (data) => {
      trickOrTreatManager.showReward(data.rewardType as 'treat' | 'trick', data.rewardItem, data.rewardAmount);

      // Play appropriate sound
      if (data.rewardType === 'trick') {
        soundManager.play('trick-trick');
      } else {
        soundManager.play('trick-success');
      }
    }
  );

</script>

<NotificationContainer />

<!-- Ghost Features (Halloween Base) -->
<GhostChoice bind:visible={ghostManager.state.choiceVisible} bind:forced={ghostManager.state.forced} />
<GhostHUD bind:visible={ghostManager.state.hudVisible} bind:maxDuration={ghostManager.state.maxDuration} bind:exitKey={ghostManager.state.exitKey} bind:scareKey={ghostManager.state.scareKey} />
<JumpscareEffect bind:visible={ghostManager.state.jumpscareVisible} bind:soundVolume={ghostManager.state.soundVolume} />

<!-- Trick-or-Treat Features -->
<TrickOrTreatHUD
  visible={trickOrTreatManager.state.hudVisible}
  current={trickOrTreatManager.state.currentHouses}
  total={trickOrTreatManager.state.totalHouses}
  timeRemaining={trickOrTreatManager.state.timeRemaining}
/>
<TrickOrTreatReward
  bind:visible={trickOrTreatManager.state.rewardVisible}
  rewardType={trickOrTreatManager.state.rewardType}
  item={trickOrTreatManager.state.rewardItem}
  amount={trickOrTreatManager.state.rewardAmount}
/>

<!-- Particle Effects -->
<ParticleEffect bind:this={particleEffect} />
