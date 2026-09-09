/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

const DOCS_IMAGE_PREFIX = 'https://docs-backend.fivem.net/weapons/';

/**
 * Builds the FiveM docs weapon image URL
 * @param weaponName - Weapon spawn name
 * @returns Image URL
 */
export function getDocsWeaponImage(weaponName: string): string {
  return `${DOCS_IMAGE_PREFIX}${weaponName}.png`;
}

/**
 * Probes whether an image URL can be loaded by the browser
 * @param url - Image URL
 */
function canLoadImage(url: string): Promise<boolean> {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => resolve(true);
    img.onerror = () => resolve(false);
    img.src = url;
  });
}

function getUniqueImageCandidates(candidates: string[]): string[] {
  const uniqueCandidates: string[] = [];
  const seen = new Set<string>();

  for (const candidate of candidates) {
    const url = candidate.trim();

    if (!url || seen.has(url)) {
      continue;
    }

    seen.add(url);
    uniqueCandidates.push(url);
  }

  return uniqueCandidates;
}

/**
 * Resolves the best display URL for a weapon image
 * Prefers inventory images, then FiveM docs images, then the configured fallback image
 * @param weaponName - Weapon spawn name
 * @param image - Preferred image URL from Lua
 * @param fallbackImage - Configured fallback image URL/path
 */
export async function resolveWeaponImage(
  weaponName: string,
  image: string,
  fallbackImage = ''
): Promise<string | null> {
  const docsUrl = getDocsWeaponImage(weaponName);
  const candidates = getUniqueImageCandidates([
    image,
    docsUrl,
    fallbackImage
  ]);

  for (const candidate of candidates) {
    if (await canLoadImage(candidate)) {
      return candidate;
    }
  }

  return null;
}
