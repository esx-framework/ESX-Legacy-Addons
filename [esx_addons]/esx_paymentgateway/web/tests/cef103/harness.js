/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

// @ts-check

/**
 * What the CEF scenarios share: the page harness types and the screen sizes FiveM players run.
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

/** Resolutions FiveM players commonly run, from 720p up to 4K. */
export const RESOLUTIONS = [
  { label: '720p', width: 1280, height: 720 },
  { label: '1080p', width: 1920, height: 1080 },
  { label: '1440p', width: 2560, height: 1440 },
  { label: '4k', width: 3840, height: 2160 },
];

/**
 * Waits two animation frames: one for layout, one for the first paint.
 * @param {import('puppeteer-core').Page} page Browser page
 * @returns {Promise<void>}
 */
export async function settle(page) {
  await page.evaluate(
    () => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))),
  );
}
