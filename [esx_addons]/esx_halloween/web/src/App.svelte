<script lang="ts">
  import { useNuiEvent } from './utils/useNuiEvent';
  import type { NotificationData } from './types/nui';
  import { notificationManager } from './stores/NotificationManager.svelte';
  import { ghostManager } from './stores/GhostManager.svelte';
  import NotificationContainer from './components/NotificationContainer.svelte';
  import GhostChoice from './components/GhostChoice.svelte';
  import GhostHUD from './components/GhostHUD.svelte';
  import JumpscareEffect from './components/JumpscareEffect.svelte';
  import './styles/global.css';

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

  useNuiEvent<{ colors: Record<string, string> }>('setThemeColors', (data) => {
    const root = document.documentElement;
    if (data.colors.primary) root.style.setProperty('--primary-color', data.colors.primary);
    if (data.colors.secondary) root.style.setProperty('--secondary-color', data.colors.secondary);
    if (data.colors.background) root.style.setProperty('--background-color', data.colors.background);
    if (data.colors.accent) root.style.setProperty('--accent-color', data.colors.accent);
    if (data.colors.logoUrl) root.style.setProperty('--logo-url', data.colors.logoUrl);
  });
</script>

<NotificationContainer />

<GhostChoice bind:visible={ghostManager.state.choiceVisible} bind:forced={ghostManager.state.forced} />
<GhostHUD bind:visible={ghostManager.state.hudVisible} bind:maxDuration={ghostManager.state.maxDuration} bind:exitKey={ghostManager.state.exitKey} bind:scareKey={ghostManager.state.scareKey} />
<JumpscareEffect bind:visible={ghostManager.state.jumpscareVisible} bind:soundVolume={ghostManager.state.soundVolume} />
