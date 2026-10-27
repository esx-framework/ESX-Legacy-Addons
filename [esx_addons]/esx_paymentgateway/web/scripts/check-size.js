/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

// @ts-check

/**
 * Keeps source files small enough to read and review in one go: any file in src, tests or
 * scripts over MAX_LINES lines, doc comments included, fails the check. A file that grows past
 * it wants to be split by what it does, not trimmed.
 */

import { readdir, readFile } from 'node:fs/promises';
import { extname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

/** Longest a source file may be, in lines. */
const MAX_LINES = 400;
/** Extensions that count as source. */
const SOURCE = new Set(['.ts', '.js', '.svelte', '.css']);
/** Folders that are checked, relative to the web root. */
const FOLDERS = ['src', 'tests', 'scripts'];

const root = fileURLToPath(new URL('..', import.meta.url));

/**
 * Recursively collects all files below a directory; a folder that does not exist yet has none.
 * @param {string} dir Directory to walk
 * @returns {Promise<string[]>} Absolute file paths
 */
async function walk(dir) {
  const entries = await readdir(dir, { withFileTypes: true }).catch((error) => {
    if (error?.code === 'ENOENT') return [];
    throw error;
  });
  const nested = await Promise.all(
    entries.map((entry) => {
      const path = join(dir, entry.name);
      return entry.isDirectory() ? walk(path) : Promise.resolve([path]);
    }),
  );
  return nested.flat();
}

const files = (await Promise.all(FOLDERS.map((folder) => walk(join(root, folder)))))
  .flat()
  .filter((file) => SOURCE.has(extname(file)));
/** @type {string[]} */
const oversized = [];

for (const file of files) {
  const source = await readFile(file, 'utf8');
  const lines = source.endsWith('\n') ? source.split('\n').length - 1 : source.split('\n').length;
  if (lines > MAX_LINES) oversized.push(`${relative(root, file)}: ${lines} lines`);
}

if (oversized.length > 0) {
  console.error(`check-size: ${oversized.length} file(s) over ${MAX_LINES} lines`);
  for (const entry of oversized) console.error(`  ${entry}`);
  process.exit(1);
}

console.log(`check-size: ${files.length} files within ${MAX_LINES} lines`);
