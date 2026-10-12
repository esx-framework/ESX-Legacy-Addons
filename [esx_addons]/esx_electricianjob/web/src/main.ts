/**
 * NUI entry point. Mounts the root component into the page shell from index.html.
 *
 * @see App
 */

import { mount } from 'svelte';
import App from './App.svelte';

const target: HTMLElement | null = document.getElementById('app');
if (!target) {
  throw new Error('Mount point #app is missing from index.html');
}

mount(App, { target });
