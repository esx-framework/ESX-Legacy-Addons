/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/vite-plugin-svelte').SvelteConfig} */
export default {
  preprocess: vitePreprocess(),
  compilerOptions: {
    // Runes for the page; libraries such as lucide-svelte are still written in Svelte 4 syntax.
    runes: ({ filename }) => (filename.split(/[/\\]/).includes('node_modules') ? undefined : true),
  },
};
