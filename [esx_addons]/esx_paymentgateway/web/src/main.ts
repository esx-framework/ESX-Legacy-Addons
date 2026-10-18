/**
 * NUI entry point. Mounts the root component into the page shell from index.html.
 *
 * @see App
 */

import { mount } from 'svelte';
import 'esx-ui-kit-svelte/style.css';
import App from './App.svelte';
import './styles/fonts.css';
import './styles/global.css';

const target: HTMLElement | null = document.getElementById('app');
if (!target) {
  throw new Error('Mount point #app is missing from index.html');
}

mount(App, { target });
