/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

// @ts-check

import { settle } from './harness.js';

/**
 * Payments for the CEF scenarios, as the Lua client script sends them, and the steps the
 * scenarios share.
 */

/** @typedef {import('./harness.js').NuiHarness} NuiHarness */
/** @typedef {import('puppeteer-core').Page} Page */

/** Payment every scenario starts from. */
export const PAYMENT = {
  id: 42,
  amount: 1250,
  currency: '$',
  title: 'Vehicle repair',
  description: 'Los Santos Customs',
  methods: ['cash', 'card'],
  balances: { cash: 4820, card: 18500 },
};

/**
 * Builds an open message.
 * @param {Record<string, unknown>} [payment] Fields that differ from {@link PAYMENT}
 * @param {Record<string, unknown>} [extra] Further fields of the message, e.g. theme or labels
 * @returns {object} Message as Lua would send it
 */
export function openMessage(payment = {}, extra = {}) {
  return { action: 'open', payment: { ...PAYMENT, ...payment }, ...extra };
}

/**
 * Opens a payment at a screen size and waits until the dialog has come in.
 * @param {Page} page Browser page
 * @param {NuiHarness} nui Harness
 * @param {{ width: number, height: number }} viewport Screen size
 * @param {object} message Open message
 * @returns {Promise<void>}
 */
export async function openPayment(page, nui, viewport, message) {
  await page.setViewport({ width: viewport.width, height: viewport.height, deviceScaleFactor: 1 });
  await nui.send(message);
  await page.waitForSelector('[role="dialog"]', { timeout: 5_000 });
  // Lets the entrance and the staggered tiles finish.
  await new Promise((resolve) => setTimeout(resolve, 600));
  await settle(page);
}

/**
 * Clicks the tile of a method.
 * @param {Page} page Browser page
 * @param {number} index Position of the method in the dialog, from 0
 * @returns {Promise<void>}
 */
export async function chooseTile(page, index) {
  const tiles = await page.$$('[role="radio"]');
  const tile = tiles[index];
  if (!tile) throw new Error(`no method tile at ${index}`);
  await tile.click();
}

/**
 * Clicks the pay button and returns the body of the `pay` callback.
 * @param {Page} page Browser page
 * @param {NuiHarness} nui Harness
 * @returns {Promise<{ id: number, method: string }>} Body Lua receives
 */
export async function clickPay(page, nui) {
  await page.click('button.pay');
  return /** @type {{ id: number, method: string }} */ (await nui.waitForCallback('pay'));
}

/**
 * Reads the phase the dialog shows.
 * @param {Page} page Browser page
 * @returns {Promise<string | null>} choosing, paying or paid
 */
export function phaseOf(page) {
  return page.$eval('[role="dialog"]', (dialog) => dialog.getAttribute('data-phase'));
}
