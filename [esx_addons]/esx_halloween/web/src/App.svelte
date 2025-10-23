<script lang="ts">
  import { onMount } from 'svelte';
  import { useNuiEvent } from './utils/useNuiEvent';
  import { fetchNui } from './utils/fetchNui';
  import type { NotificationData } from './types/nui';
  import { notificationManager } from './stores/NotificationManager.svelte';
  import { ghostManager } from './stores/GhostManager.svelte';
  import NotificationContainer from './components/NotificationContainer.svelte';
  import GhostChoice from './components/GhostChoice.svelte';
  import GhostHUD from './components/GhostHUD.svelte';
  import JumpscareEffect from './components/JumpscareEffect.svelte';
  import './styles/global.css';

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
</script>

<NotificationContainer />

<GhostChoice bind:visible={ghostManager.state.choiceVisible} bind:forced={ghostManager.state.forced} />
<GhostHUD bind:visible={ghostManager.state.hudVisible} bind:maxDuration={ghostManager.state.maxDuration} bind:exitKey={ghostManager.state.exitKey} bind:scareKey={ghostManager.state.scareKey} />
<JumpscareEffect bind:visible={ghostManager.state.jumpscareVisible} bind:soundVolume={ghostManager.state.soundVolume} />
