import './global.css';
import App from './App.svelte';
import { mount } from 'svelte';
import { fetchNui } from './utils/nui';
import { applyConvarTheme } from './lib/theme';
import type { ReadyResponse } from './types/nui';

const app = mount(App, {
  target: document.getElementById('app')!
});

// Send ready event and receive theme
fetchNui<ReadyResponse>('ready', {})
  .then(response => {
    if (response.ok && response.data?.theme) {
      applyConvarTheme(response.data.theme);
    } else {
      console.warn('[esx_shops] Failed to load theme from server, using defaults', response.error);
    }
  })
  .catch(error => {
    console.error('[esx_shops] Critical error loading theme:', error);
    // Theme defaults are already in CSS, so UI will still work
  });

export default app;
