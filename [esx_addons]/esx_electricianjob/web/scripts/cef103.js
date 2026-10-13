/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

// @ts-check

/**
 * Runs the production build inside Chromium 103, the engine behind FiveM's CEF, with the
 * flags FiveM passes to it. The script plays the game client: it serves dist/, stubs
 * GetParentResourceName, answers NUI callbacks and posts NUI messages. A console error,
 * an uncaught exception or a failing scenario fails the run. Every scenario can store
 * screenshots in test-results/cef103/.
 *
 * usage: node scripts/cef103.js [scenario ...]
 *
 * Set CHROMIUM_103_PATH to use an existing binary instead of the cached download.
 */

import { access, mkdir } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Browser, computeExecutablePath, install } from '@puppeteer/browsers';
import puppeteer from 'puppeteer-core';
import { preview } from 'vite';
import { scenarios } from '../tests/cef103/scenarios.js';

/** @typedef {import('../tests/cef103/scenarios.js').NuiHarness} NuiHarness */
/** @typedef {import('puppeteer-core').Page} Page */
/** @typedef {import('puppeteer-core').HTTPRequest} HTTPRequest */

/**
 * @typedef {object} RecordedCallback
 * @property {string} name Callback name, the path after the resource origin
 * @property {unknown} body Parsed JSON body sent by the page
 */

const ROOT = fileURLToPath(new URL('..', import.meta.url));
const CACHE_DIR = join(ROOT, 'node_modules', '.cache', 'chromium');
const RESULTS_DIR = join(ROOT, 'test-results', 'cef103');

/** Last trunk revision before the M103 branch point. FiveM ships 103.0.5060.141. */
const CHROMIUM_BUILD = '1002910';
const RESOURCE_NAME = 'esx_electricianjob';
const CALLBACK_ORIGIN = `https://${RESOURCE_NAME}/`;
const CALLBACK_TIMEOUT_MS = 5_000;
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

/** Switches FiveM passes to its CEF 103 build (NUIApp.cpp). */
const FIVEM_FLAGS = ['--enable-experimental-web-platform-features', '--js-flags=--jitless'];
const VIEWPORT = { width: 1920, height: 1080 };

/** Stand-in for the game world behind the transparent NUI page. */
const BACKDROP_CSS =
  'html { background: radial-gradient(ellipse at 30% 20%, #4a5560 0%, #1d2226 70%) fixed; }';

/**
 * Returns the Chromium 103 executable, downloading it into node_modules/.cache on first use.
 * @returns {Promise<string>} Absolute path to the browser binary
 */
async function resolveChromium() {
  const override = process.env.CHROMIUM_103_PATH;
  if (override) return override;

  const options = { browser: Browser.CHROMIUM, buildId: CHROMIUM_BUILD, cacheDir: CACHE_DIR };
  const executablePath = computeExecutablePath(options);
  try {
    await access(executablePath);
    return executablePath;
  } catch {
    // Not cached yet, fall through to the download.
  }

  console.log(`cef103: downloading Chromium build ${CHROMIUM_BUILD}, about 150 MB`);
  const installed = await install(options);
  return installed.executablePath;
}

/**
 * Wires a page up like FiveM would: resource name global, callback endpoint and error capture.
 * @param {Page} page Fresh browser page
 * @param {string} scenario Scenario name, used for screenshot file names
 * @param {string[]} errors Collector for console errors and uncaught exceptions
 * @returns {Promise<NuiHarness>} Harness handed to the scenario
 */
async function prepare(page, scenario, errors) {
  /** @type {RecordedCallback[]} */
  const pending = [];
  /** @type {Map<string, (body: unknown) => void>} */
  const waiters = new Map();

  await page.evaluateOnNewDocument((/** @type {string} */ name) => {
    Object.defineProperty(window, 'GetParentResourceName', { value: () => name });
  }, RESOURCE_NAME);

  await page.setRequestInterception(true);
  page.on('request', (/** @type {HTTPRequest} */ request) => {
    const url = request.url();
    if (!url.startsWith(CALLBACK_ORIGIN)) {
      void request.continue();
      return;
    }

    // The callback origin differs from the page origin, so JSON posts are preflighted. FiveM
    // currently runs CEF with web security off, but the UI must not depend on that.
    if (request.method() === 'OPTIONS') {
      void request.respond({ status: 204, headers: CORS_HEADERS });
      return;
    }

    const name = url.slice(CALLBACK_ORIGIN.length);
    const raw = request.postData();
    const body = raw ? JSON.parse(raw) : undefined;
    const waiter = waiters.get(name);
    if (waiter) {
      waiters.delete(name);
      waiter(body);
    } else {
      pending.push({ name, body });
    }
    void request.respond({
      status: 200,
      contentType: 'application/json',
      headers: CORS_HEADERS,
      body: '{}',
    });
  });

  page.on('console', (message) => {
    if (message.type() === 'error') errors.push(`console: ${message.text()}`);
  });
  page.on('pageerror', (error) => errors.push(`exception: ${error.message}`));
  page.on('requestfailed', (request) => {
    errors.push(`request failed: ${request.url()} ${request.failure()?.errorText ?? ''}`);
  });

  return {
    async send(message) {
      await page.evaluate((data) => window.postMessage(data, '*'), /** @type {never} */ (message));
    },
    waitForCallback(name) {
      const index = pending.findIndex((entry) => entry.name === name);
      if (index !== -1) {
        const [entry] = pending.splice(index, 1);
        return Promise.resolve(entry?.body);
      }
      return new Promise((resolve, reject) => {
        const timer = setTimeout(() => {
          waiters.delete(name);
          reject(new Error(`NUI callback "${name}" not received within ${CALLBACK_TIMEOUT_MS} ms`));
        }, CALLBACK_TIMEOUT_MS);
        waiters.set(name, (body) => {
          clearTimeout(timer);
          resolve(body);
        });
      });
    },
    async screenshot(label) {
      await page.addStyleTag({ content: BACKDROP_CSS });
      await page.screenshot({ path: join(RESULTS_DIR, `${scenario}-${label}.png`) });
    },
  };
}

const selected = process.argv.slice(2);
const queue = selected.length
  ? scenarios.filter((scenario) => selected.includes(scenario.name))
  : scenarios;

if (queue.length === 0) {
  console.error(`cef103: no scenario matches ${selected.join(', ')}`);
  process.exit(1);
}

await mkdir(RESULTS_DIR, { recursive: true });
const executablePath = await resolveChromium();
const server = await preview({ root: ROOT, logLevel: 'warn', preview: { port: 4319 } });
const baseUrl = server.resolvedUrls?.local[0];
if (!baseUrl) throw new Error('vite preview did not report a local URL');

const browser = await puppeteer.launch({
  executablePath,
  headless: true,
  args: [...FIVEM_FLAGS, `--window-size=${VIEWPORT.width},${VIEWPORT.height}`],
  defaultViewport: VIEWPORT,
});

let failed = 0;
try {
  const version = await browser.version();
  if (!version.includes('/103.')) throw new Error(`expected Chromium 103, got ${version}`);
  console.log(`cef103: ${version}, ${queue.length} scenario(s)`);

  for (const scenario of queue) {
    const page = await browser.newPage();
    /** @type {string[]} */
    const errors = [];
    const started = Date.now();
    try {
      const nui = await prepare(page, scenario.name, errors);
      await page.goto(baseUrl, { waitUntil: 'networkidle0' });
      await scenario.run(page, nui);
      if (errors.length > 0) throw new Error(errors.join('\n    '));
      console.log(`  ok   ${scenario.name} (${Date.now() - started} ms)`);
    } catch (error) {
      failed += 1;
      const message = error instanceof Error ? error.message : String(error);
      console.error(`  FAIL ${scenario.name}\n    ${message}`);
    } finally {
      await page.close();
    }
  }
} finally {
  await browser.close();
  await server.close();
}

process.exit(failed > 0 ? 1 : 0);
