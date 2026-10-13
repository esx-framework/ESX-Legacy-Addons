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

/**
 * Builds an open message for a round.
 * @param {string} game Game kind
 * @param {number} seed Puzzle seed
 * @param {number} difficulty Difficulty tier
 * @returns {object} Message as Lua would send it
 */
function openMessage(game, seed, difficulty) {
  return { action: 'open', session: { id: `cef-${game}-${seed}`, game, seed, difficulty } };
}

/** @type {Scenario[]} */
export const scenarios = [
  {
    name: 'boot',
    async run(page, nui) {
      await page.waitForSelector('#app main');
      await nui.screenshot('idle');
    },
  },
  {
    name: 'escape-aborts',
    async run(page, nui) {
      await nui.send(openMessage('wiring', 7, 1));
      await page.waitForSelector('main[data-game="wiring"]');
      await page.keyboard.press('Escape');

      const body = /** @type {{ sessionId?: unknown, outcome?: unknown }} */ (
        await nui.waitForCallback('finish')
      );
      if (body.sessionId !== 'cef-wiring-7' || body.outcome !== 'aborted') {
        throw new Error(`unexpected finish payload ${JSON.stringify(body)}`);
      }
      await page.waitForSelector('main:not([data-game])');
    },
  },
  {
    name: 'invalid-message-ignored',
    async run(page, nui) {
      await nui.send({ action: 'open', session: { id: 'x', game: 'wiring', seed: -5 } });
      await new Promise((resolve) => setTimeout(resolve, 200));
      if (await page.$('main[data-game]')) throw new Error('invalid open message was accepted');
    },
  },
];
