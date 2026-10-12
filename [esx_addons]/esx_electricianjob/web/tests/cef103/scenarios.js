/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

// @ts-check

/**
 * Scenarios for scripts/cef103.js. Each one gets a page that already has the production
 * build loaded and a harness that stands in for the Lua side of the resource.
 */

/**
 * @typedef {object} NuiHarness
 * @property {(message: unknown) => Promise<void>} send Posts a message the way SendNUIMessage does
 * @property {(name: string) => Promise<unknown>} waitForCallback Resolves with the body of the
 *   next NUI callback with that name
 * @property {(label: string) => Promise<void>} screenshot Saves a full-page screenshot
 */

/**
 * @typedef {object} Scenario
 * @property {string} name Unique name, also accepted as CLI filter
 * @property {(page: import('puppeteer-core').Page, nui: NuiHarness) => Promise<void>} run
 *   Scenario body, throws on failure
 */

/** @type {Scenario[]} */
export const scenarios = [
  {
    name: 'boot',
    async run(page, nui) {
      await page.waitForSelector('#app main');
      await nui.screenshot('idle');
    },
  },
];
