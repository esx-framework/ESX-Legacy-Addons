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

/** Resolutions FiveM players commonly run, from 720p up to 4K. */
const RESOLUTIONS = [
  { label: '720p', width: 1280, height: 720 },
  { label: '1080p', width: 1920, height: 1080 },
  { label: '1440p', width: 2560, height: 1440 },
  { label: '4k', width: 3840, height: 2160 },
];

/**
 * Opens a wiring round at a resolution and waits until the scene is interactive.
 * @param {import('puppeteer-core').Page} page Browser page
 * @param {NuiHarness} nui Harness
 * @param {{ width: number, height: number }} viewport Screen size
 * @param {number} seed Puzzle seed
 * @param {number} difficulty Difficulty tier
 * @returns {Promise<void>}
 */
async function openWiring(page, nui, viewport, seed, difficulty) {
  await page.setViewport({ width: viewport.width, height: viewport.height, deviceScaleFactor: 1 });
  await nui.send(openMessage('wiring', seed, difficulty));
  await page.waitForSelector('.game[data-phase="playing"]', { timeout: 10_000 });
  // Two frames: one for the resize, one for the first paint.
  await page.evaluate(
    () => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))),
  );
}

/** @type {Scenario[]} */
export const scenarios = [
  ...RESOLUTIONS.map(
    (resolution) =>
      /** @type {Scenario} */ ({
        name: `wiring-${resolution.label}`,
        async run(page, nui) {
          await openWiring(page, nui, resolution, 0x2c4f81a3, 2);
          await nui.screenshot('start');
        },
      }),
  ),
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
