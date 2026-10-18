/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

// @ts-check

import { settle } from './harness.js';

/**
 * Scenarios for scripts/cef103.js. Each one gets a page that already has the production
 * build loaded and a harness that stands in for the Lua side of the resource.
 */

/** @typedef {import('./harness.js').Scenario} Scenario */

/** @type {Scenario[]} */
export const scenarios = [
  {
    name: 'boot',
    async run(page) {
      await settle(page);
      const shown = await page.$eval('.app', (app) => app.childElementCount);
      if (shown !== 0) throw new Error('the page shows something before a payment was opened');
      // The kit paints the body; over the game it has to stay see-through.
      const background = await page.$eval('body', (body) => getComputedStyle(body).backgroundColor);
      if (background !== 'rgba(0, 0, 0, 0)') throw new Error(`body background is ${background}`);
    },
  },
  {
    name: 'invalid-message-ignored',
    async run(page, nui) {
      await nui.send(null);
      await nui.send('open');
      await nui.send({ action: 'open' });
      await nui.send({ action: 'open', payment: { amount: -5 } });
      await settle(page);
      const shown = await page.$eval('.app', (app) => app.childElementCount);
      if (shown !== 0) throw new Error('a broken open message showed the dialog');
    },
  },
];
