import { mount } from 'svelte';
import './app.css';
import App from './App.svelte';
import "./lib/shared/nui/handlers";
import { isChromium } from './lib/shared/util/util';
import testBackground from './assets/testbg.png';

const root = document.getElementById('app');

if (!isChromium() && root) {
  root.style.backgroundImage = `url(${testBackground})`;
  root.style.backgroundSize = 'cover';
  root.style.backgroundRepeat = 'no-repeat';
  root.style.backgroundPosition = 'center';
}

const app = mount(App, {
  target: document.getElementById('app')!,
})

export default app
