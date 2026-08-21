import { isEnvBrowser } from '@utils/nui';

const DOCS_IMAGE_PREFIX = 'https://docs-backend.fivem.net/weapons/';
const WHITE_CUTOFF = 248;
const WHITE_FADE = 232;

/**
 * Builds the FiveM docs weapon image URL
 * @param weaponName - Weapon spawn name
 * @returns Image URL
 */
export function getDocsWeaponImage(weaponName: string): string {
  return `${DOCS_IMAGE_PREFIX}${weaponName}.png`;
}

/**
 * Checks whether a URL points at the FiveM docs weapon image host
 * @param url - Image URL
 */
function isDocsImage(url: string): boolean {
  return url.startsWith(DOCS_IMAGE_PREFIX);
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

/**
 * Loads an HTML image element from a URL
 * @param url - Image URL
 */
function loadHtmlImage(url: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error('Failed to load image'));
    img.src = url;
  });
}

/**
 * Makes near-white pixels transparent so docs images sit on dark UI
 * @param imageData - Canvas image data
 */
function knockoutWhite(imageData: ImageData): void {
  const data = imageData.data;

  for (let i = 0; i < data.length; i += 4) {
    const r = data[i] ?? 0;
    const g = data[i + 1] ?? 0;
    const b = data[i + 2] ?? 0;
    const isNeutral = Math.abs(r - g) < 10 && Math.abs(g - b) < 10;

    if (!isNeutral) {
      continue;
    }

    const brightness = (r + g + b) / 3;

    if (brightness >= WHITE_CUTOFF) {
      data[i + 3] = 0;
    } else if (brightness >= WHITE_FADE) {
      const alpha = (WHITE_CUTOFF - brightness) / (WHITE_CUTOFF - WHITE_FADE);
      data[i + 3] = Math.round((data[i + 3] ?? 255) * alpha);
    }
  }
}

/**
 * Fetches an image and returns a processed data URL with white knocked out
 * @param url - Source image URL
 * @returns Processed data URL, or null when the image cannot be loaded
 */
async function knockoutWhiteFromUrl(url: string): Promise<string | null> {
  const response = await fetch(url);
  if (!response.ok) {
    return null;
  }

  const blob = await response.blob();
  const objectUrl = URL.createObjectURL(blob);

  try {
    const img = await loadHtmlImage(objectUrl);
    const canvas = document.createElement('canvas');
    canvas.width = img.naturalWidth;
    canvas.height = img.naturalHeight;

    const ctx = canvas.getContext('2d');
    if (!ctx) {
      return url;
    }

    ctx.drawImage(img, 0, 0);
    const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
    knockoutWhite(imageData);
    ctx.putImageData(imageData, 0, 0);

    return canvas.toDataURL('image/png');
  } finally {
    URL.revokeObjectURL(objectUrl);
  }
}

const processedCache = new Map<string, Promise<string | null>>();

/**
 * Resolves the best display URL for a weapon image
 * Prefers inventory images in-game, otherwise uses processed docs images
 * Browser development always uses FiveM docs images
 * @param weaponName - Weapon spawn name
 * @param image - Preferred image URL from Lua
 */
export async function resolveWeaponImage(weaponName: string, image: string): Promise<string | null> {
  const docsUrl = getDocsWeaponImage(weaponName);

  if (isEnvBrowser()) {
    return (await canLoadImage(docsUrl)) ? docsUrl : null;
  }

  const primary = image || docsUrl;

  if (!isDocsImage(primary) && await canLoadImage(primary)) {
    return primary;
  }

  const cached = processedCache.get(docsUrl);
  if (cached) {
    return cached;
  }

  const processed = knockoutWhiteFromUrl(docsUrl).catch(() => null);
  processedCache.set(docsUrl, processed);
  return processed;
}
