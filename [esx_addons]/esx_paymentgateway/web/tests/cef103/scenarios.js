/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

// @ts-check

import { RESOLUTIONS, settle } from './harness.js';
import {
  acceptPayment,
  chooseTile,
  clickPay,
  expectReceipt,
  openMessage,
  openPayment,
  phaseOf,
} from './payment.js';

/**
 * Scenarios for scripts/cef103.js. Each one gets a page that already has the production
 * build loaded and a harness that stands in for the Lua side of the resource.
 */

/** @typedef {import('./harness.js').Scenario} Scenario */

const FULL_HD = { width: 1920, height: 1080 };

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
      await nui.send({ action: 'open', payment: { id: 9, amount: -5 } });
      await settle(page);
      const shown = await page.$eval('.app', (app) => app.childElementCount);
      if (shown !== 0) throw new Error('a broken open message showed the dialog');
      const closed = /** @type {{ id: number }} */ (await nui.waitForCallback('close'));
      if (closed.id !== 9) throw new Error(`the refused payment was closed as ${closed.id}`);
    },
  },
  ...RESOLUTIONS.map(
    (viewport) =>
      /** @type {Scenario} */ ({
        name: `open-${viewport.label}`,
        async run(page, nui) {
          await openPayment(page, nui, viewport, openMessage());
          const shown = /** @type {{ id: number }} */ (await nui.waitForCallback('shown'));
          if (shown.id !== 42) throw new Error(`the page reported ${shown.id} as shown`);
          await nui.screenshot('open');
        },
      }),
  ),
  {
    name: 'pay-by-card',
    async run(page, nui) {
      await openPayment(page, nui, FULL_HD, openMessage());
      await chooseTile(page, 1);
      await nui.screenshot('chosen');
      const body = await clickPay(page, nui);
      if (body.id !== 42 || body.method !== 'card')
        throw new Error(`pay sent ${JSON.stringify(body)}`);
      await nui.screenshot('paying');
      await nui.send({
        action: 'result',
        result: { id: 42, ok: true, method: 'card', balances: { cash: 4820, card: 17250 } },
      });
      await expectReceipt(page, 'card');
      await new Promise((resolve) => setTimeout(resolve, 900));
      await nui.screenshot('receipt');
      const closed = /** @type {{ id: number }} */ (await nui.waitForCallback('close'));
      if (closed.id !== 42) throw new Error('the receipt did not close itself');
    },
  },
  {
    name: 'pay-in-cash',
    async run(page, nui) {
      await openPayment(page, nui, FULL_HD, openMessage());
      const body = await clickPay(page, nui);
      if (body.method !== 'cash') throw new Error(`the preselected method paid ${body.method}`);
      await acceptPayment(nui, 'cash');
      await expectReceipt(page, 'cash');
      await new Promise((resolve) => setTimeout(resolve, 900));
      await nui.screenshot('receipt');
    },
  },
  {
    name: 'keys-pick-cash',
    async run(page, nui) {
      await openPayment(page, nui, FULL_HD, openMessage());
      await page.keyboard.press('2');
      await page.keyboard.press('1');
      await page.keyboard.press('ArrowRight');
      await page.keyboard.press('ArrowLeft');
      await page.keyboard.press('Enter');
      const body = /** @type {{ method: string }} */ (await nui.waitForCallback('pay'));
      if (body.method !== 'cash') throw new Error(`the keys paid ${body.method}`);
      // A server that leaves the method out still gets the chosen one on the receipt.
      await acceptPayment(nui, undefined);
      await expectReceipt(page, 'cash');
    },
  },
  {
    name: 'hold-in-cash',
    async run(page, nui) {
      await openPayment(
        page,
        nui,
        FULL_HD,
        openMessage({ amount: 60000, hold: true, balances: { cash: 90000, card: 412000 } }),
      );
      await page.keyboard.down(' ');
      const body = /** @type {{ method: string }} */ (await nui.waitForCallback('pay'));
      await page.keyboard.up(' ');
      if (body.method !== 'cash') throw new Error(`the held payment used ${body.method}`);
      await acceptPayment(nui, 'cash');
      await expectReceipt(page, 'cash');
    },
  },
  {
    name: 'refused',
    async run(page, nui) {
      await openPayment(page, nui, FULL_HD, openMessage());
      await clickPay(page, nui);
      await nui.send({
        action: 'result',
        result: {
          id: 42,
          ok: false,
          message: 'You do not have enough cash.',
          balances: { cash: 900, card: 18500 },
        },
      });
      await page.waitForSelector('[role="alert"]', { timeout: 3_000 });
      await new Promise((resolve) => setTimeout(resolve, 450));
      await nui.screenshot('refused');
      if ((await phaseOf(page)) !== 'choosing')
        throw new Error('a refusal did not reopen the choice');
    },
  },
  {
    name: 'unaffordable',
    async run(page, nui) {
      await openPayment(page, nui, FULL_HD, openMessage({ balances: { cash: 120, card: 300 } }));
      await nui.screenshot('unaffordable');
      const disabled = await page.$eval('button.pay', (button) => button.hasAttribute('disabled'));
      if (!disabled) throw new Error('the pay button works without money');
    },
  },
  {
    name: 'server-theme',
    async run(page, nui) {
      await openPayment(
        page,
        nui,
        FULL_HD,
        openMessage(
          { methods: ['card'], title: 'Apartment rent', description: 'Dynasty 8 Real Estate' },
          {
            theme: {
              primaryColor: '#2F80ED',
              secondaryColor: '#1B2330',
              backgroundColor: '#0E141C',
            },
            labels: { heading: 'Zahlung', choose: 'Zahlungsart wählen', card: 'Karte' },
            locale: 'de',
          },
        ),
      );
      await nui.screenshot('theme');
    },
  },
  {
    name: 'browser-demo',
    async run(page) {
      // A page without GetParentResourceName is a plain browser: the demo has to take over.
      const browserPage = await page.browser().newPage();
      try {
        await browserPage.setViewport(FULL_HD);
        await browserPage.goto(page.url(), { waitUntil: 'networkidle0' });
        await browserPage.waitForSelector('[role="dialog"]', { timeout: 5_000 });
        await browserPage.waitForSelector('.demo', { timeout: 1_000 });
        await new Promise((resolve) => setTimeout(resolve, 600));
        await browserPage.screenshot({ path: 'test-results/cef103/browser-demo-open.png' });
        await browserPage.click('button.pay');
        await expectReceipt(browserPage, 'cash');
      } finally {
        await browserPage.close();
      }
    },
  },
  {
    name: 'sounds-decode',
    async run(page, nui) {
      await openPayment(page, nui, FULL_HD, openMessage({}, { volume: 0.4 }));
      const decoded = await page.evaluate(async () => {
        const urls = performance
          .getEntriesByType('resource')
          .map((entry) => entry.name)
          .filter((name) => name.endsWith('.ogg'));
        const context = new AudioContext();
        const lengths = await Promise.all(
          urls.map(async (url) => {
            const data = await (await fetch(url)).arrayBuffer();
            return (await context.decodeAudioData(data)).duration;
          }),
        );
        return { count: urls.length, shortest: Math.min(...lengths) };
      });
      if (decoded.count !== 7) throw new Error(`loaded ${decoded.count} of 7 sounds`);
      if (!(decoded.shortest > 0.05)) throw new Error('a sound decoded empty');
    },
  },
  {
    name: 'hold-large-payment',
    async run(page, nui) {
      const large = { amount: 185000, title: 'Pegassi Zentorno', hold: true };
      await openPayment(
        page,
        nui,
        FULL_HD,
        openMessage({ ...large, balances: { cash: 2400, card: 412000 } }),
      );
      const button = await page.$('button.pay');
      const box = await button?.boundingBox();
      if (!box) throw new Error('no pay button');
      await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
      await page.mouse.down();
      await new Promise((resolve) => setTimeout(resolve, 450));
      await nui.screenshot('holding');
      await page.mouse.up();
      await new Promise((resolve) => setTimeout(resolve, 300));
      if ((await phaseOf(page)) !== 'choosing') throw new Error('a short press paid');
      await page.mouse.down();
      const body = /** @type {{ method: string }} */ (await nui.waitForCallback('pay'));
      await page.mouse.up();
      if (body.method !== 'card') throw new Error(`held payment used ${body.method}`);
    },
  },
];
