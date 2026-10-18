/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

// @ts-check

/**
 * Scans the production bundle for CSS and JS features that Chromium 103 (FiveM's CEF build)
 * does not ship. Lightning CSS and the bundler lower most syntax, but neither can polyfill
 * selectors, color functions or runtime APIs, so anything that slips through fails the build.
 *
 * Features that only work in FiveM because of --enable-experimental-web-platform-features
 * (:has, container queries, dvh, individual transforms) are rejected as well: they are
 * pre-release implementations and not present in a stock Chromium 103.
 */

import { readdir, readFile } from 'node:fs/promises';
import { extname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

/**
 * @typedef {object} Rule
 * @property {string} name Human readable feature name
 * @property {number} since First Chrome version that ships the feature
 * @property {RegExp} pattern Pattern matched against the minified output
 */

/** @type {Rule[]} */
const CSS_RULES = [
  {
    name: 'individual transform property',
    since: 104,
    pattern: /[;{](?:translate|rotate|scale):/g,
  },
  {
    name: 'media query range syntax',
    since: 104,
    pattern: /@media[^{]*\((?:width|height)\s*[<>]/g,
  },
  { name: ':has()', since: 105, pattern: /:has\(/g },
  { name: 'container query', since: 105, pattern: /@container\b/g },
  { name: 'container query unit', since: 105, pattern: /\d(?:cqw|cqh|cqi|cqb|cqmin|cqmax)\b/g },
  { name: 'dynamic viewport unit', since: 108, pattern: /\d(?:dvh|svh|lvh|dvw|svw|lvw)\b/g },
  { name: 'lh unit', since: 109, pattern: /\d(?:r?lh)\b/g },
  { name: 'color-mix()', since: 111, pattern: /color-mix\(/g },
  { name: 'lab/lch/oklab/oklch color', since: 111, pattern: /\b(?:ok)?l(?:ab|ch)\(/g },
  { name: 'trigonometric function', since: 111, pattern: /\b(?:sin|cos|tan|asin|acos|atan2?)\(/g },
  { name: 'native nesting', since: 112, pattern: /{[^{}]*&[^{}]*{/g },
  { name: 'text-wrap', since: 114, pattern: /text-wrap:/g },
  { name: 'subgrid', since: 117, pattern: /\bsubgrid\b/g },
  { name: '@starting-style', since: 117, pattern: /@starting-style\b/g },
  { name: '@scope', since: 118, pattern: /@scope\b/g },
  { name: 'light-dark()', since: 123, pattern: /light-dark\(/g },
  { name: 'anchor positioning', since: 125, pattern: /\banchor(?:-name)?[(:]/g },
  { name: 'field-sizing', since: 123, pattern: /field-sizing:/g },
];

/** @type {Rule[]} */
const JS_RULES = [
  {
    name: 'Array change-by-copy methods',
    since: 110,
    pattern: /\.(?:toSorted|toReversed|toSpliced)\(/g,
  },
  { name: 'String well-formed methods', since: 111, pattern: /\.(?:isWellFormed|toWellFormed)\(/g },
  { name: 'popover API', since: 114, pattern: /\.(?:showPopover|hidePopover|togglePopover)\(/g },
  { name: 'view transitions', since: 111, pattern: /\.startViewTransition\(/g },
  { name: 'AbortSignal.any', since: 116, pattern: /AbortSignal\.any\(/g },
  { name: 'Object/Map.groupBy', since: 117, pattern: /\b(?:Object|Map)\.groupBy\(/g },
  { name: 'Promise.withResolvers', since: 119, pattern: /Promise\.withResolvers\(/g },
  { name: 'URL.canParse', since: 120, pattern: /URL\.canParse\(/g },
  { name: 'Array.fromAsync', since: 121, pattern: /Array\.fromAsync\(/g },
  {
    name: 'Set composition methods',
    since: 122,
    pattern: /\.(?:symmetricDifference|isSubsetOf|isSupersetOf|isDisjointFrom)\(/g,
  },
  { name: 'Promise.try', since: 128, pattern: /Promise\.try\(/g },
  { name: 'WebAssembly (disabled by --jitless)', since: Infinity, pattern: /\bWebAssembly\./g },
];

const distDir = fileURLToPath(new URL('../dist', import.meta.url));

/**
 * Recursively collects all files below a directory.
 * @param {string} dir Directory to walk
 * @returns {Promise<string[]>} Absolute file paths
 */
async function walk(dir) {
  const entries = await readdir(dir, { withFileTypes: true });
  const nested = await Promise.all(
    entries.map((entry) => {
      const path = join(dir, entry.name);
      return entry.isDirectory() ? walk(path) : Promise.resolve([path]);
    }),
  );
  return nested.flat();
}

/**
 * Returns a short excerpt around a match for the report.
 * @param {string} source Full file contents
 * @param {number} index Match offset
 * @returns {string} Excerpt with surrounding context
 */
function excerpt(source, index) {
  const start = Math.max(0, index - 40);
  return source.slice(start, index + 60).replace(/\s+/g, ' ');
}

const files = await walk(distDir);
/** @type {string[]} */
const violations = [];

for (const file of files) {
  const ext = extname(file);
  const rules = ext === '.css' ? CSS_RULES : ext === '.js' ? JS_RULES : undefined;
  if (!rules) continue;

  const source = await readFile(file, 'utf8');
  for (const rule of rules) {
    for (const match of source.matchAll(rule.pattern)) {
      violations.push(
        `${relative(distDir, file)}: ${rule.name} (Chrome ${rule.since}) near "${excerpt(source, match.index)}"`,
      );
    }
  }
}

if (violations.length > 0) {
  console.error(`check-compat: ${violations.length} feature(s) unavailable in Chromium 103`);
  for (const violation of violations) console.error(`  ${violation}`);
  process.exit(1);
}

console.log(`check-compat: ${files.length} files clean for Chromium 103`);
