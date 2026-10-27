/// <reference types="vitest/config" />
/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';

/**
 * FiveM renders NUI pages with CEF 103. Syntax is lowered by the bundler and CSS by
 * Lightning CSS during minification; runtime APIs are kept in check by the TypeScript lib
 * setting and scripts/check-compat.js.
 */
const NUI_TARGET = 'chrome103';

export default defineConfig({
  plugins: [svelte()],
  base: './',
  build: {
    target: NUI_TARGET,
    cssTarget: NUI_TARGET,
    outDir: 'dist',
    emptyOutDir: true,
    assetsDir: 'assets',
    assetsInlineLimit: 0,
    sourcemap: false,
  },
  server: {
    port: 3000,
  },
  test: {
    include: ['src/**/*.test.ts'],
  },
});
