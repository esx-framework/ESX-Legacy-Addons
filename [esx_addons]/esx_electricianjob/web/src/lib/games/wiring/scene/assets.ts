/**
 * Sprites of the junction box scene and their pre-rendered drop shadows.
 *
 * @see loadWiringSprites
 */

const SOURCES = {
  box: new URL('../../../../assets/wiring/box.webp', import.meta.url).href,
  drywall: new URL('../../../../assets/wiring/drywall.webp', import.meta.url).href,
  groundScrew: new URL('../../../../assets/wiring/ground-screw.webp', import.meta.url).href,
  nutOrange: new URL('../../../../assets/wiring/nut-orange.webp', import.meta.url).href,
  nutYellow: new URL('../../../../assets/wiring/nut-yellow.webp', import.meta.url).href,
  nutRed: new URL('../../../../assets/wiring/nut-red.webp', import.meta.url).href,
  tester: new URL('../../../../assets/wiring/tester.webp', import.meta.url).href,
  stripper: new URL('../../../../assets/wiring/stripper.webp', import.meta.url).href,
  tapeRoll: new URL('../../../../assets/wiring/tape-roll.webp', import.meta.url).href,
  tray: new URL('../../../../assets/wiring/tray.webp', import.meta.url).href,
  maskingTape: new URL('../../../../assets/wiring/masking-tape.webp', import.meta.url).href,
  breakerOn: new URL('../../../../assets/wiring/breaker-on.webp', import.meta.url).href,
  breakerOff: new URL('../../../../assets/wiring/breaker-off.webp', import.meta.url).href,
  switchOn: new URL('../../../../assets/wiring/switch-on.webp', import.meta.url).href,
  switchOff: new URL('../../../../assets/wiring/switch-off.webp', import.meta.url).href,
  bulb: new URL('../../../../assets/wiring/bulb.webp', import.meta.url).href,
  canopy: new URL('../../../../assets/wiring/canopy.webp', import.meta.url).href,
} as const;

/** Name of a scene sprite. */
export type SpriteName = keyof typeof SOURCES;

/** Sprites that are carried around and therefore need a shadow. */
const SHADOWED = [
  'box',
  'canopy',
  'nutOrange',
  'nutYellow',
  'nutRed',
  'tester',
  'stripper',
  'tapeRoll',
  'tray',
] as const;

/** Name of a sprite with a pre-rendered shadow. */
export type ShadowedSprite = (typeof SHADOWED)[number];

/** Decoded sprites plus blurred silhouettes for shadows. */
export interface WiringSprites {
  /** Decoded images */
  images: Readonly<Record<SpriteName, HTMLImageElement>>;
  /** Blurred black silhouettes with {@link SHADOW_PADDING} transparent margin */
  shadows: Readonly<Record<ShadowedSprite, HTMLCanvasElement>>;
}

/** Margin around shadow silhouettes, as a fraction of the sprite width. */
export const SHADOW_PADDING = 0.12;

/** Image URL for DOM use, e.g. in HUD cards. */
export function spriteUrl(name: SpriteName): string {
  return SOURCES[name];
}

async function loadImage(src: string): Promise<HTMLImageElement> {
  const image = new Image();
  image.decoding = 'async';
  image.src = src;
  await image.decode();
  return image;
}

function silhouette(image: HTMLImageElement): HTMLCanvasElement {
  const pad = Math.round(image.naturalWidth * SHADOW_PADDING);
  const canvas = document.createElement('canvas');
  canvas.width = image.naturalWidth + pad * 2;
  canvas.height = image.naturalHeight + pad * 2;
  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('2D canvas unavailable');

  // Runs once per sprite at load time, so the canvas blur filter is affordable here.
  ctx.filter = `blur(${Math.max(2, Math.round(image.naturalWidth * 0.018))}px)`;
  ctx.drawImage(image, pad, pad);
  ctx.filter = 'none';
  ctx.globalCompositeOperation = 'source-in';
  ctx.fillStyle = '#000';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  return canvas;
}

/**
 * Loads and decodes every sprite of the scene.
 *
 * @returns Images and shadows, ready for drawing
 * @throws {Error} When an image fails to load or decode
 */
export async function loadWiringSprites(): Promise<WiringSprites> {
  const names = Object.keys(SOURCES) as SpriteName[];
  const decoded = await Promise.all(
    names.map((name: SpriteName): Promise<HTMLImageElement> => loadImage(SOURCES[name])),
  );
  const images = Object.fromEntries(
    names.map((name: SpriteName, i: number): [SpriteName, HTMLImageElement] => [
      name,
      decoded[i] as HTMLImageElement,
    ]),
  ) as Record<SpriteName, HTMLImageElement>;
  const shadows = Object.fromEntries(
    SHADOWED.map((name: ShadowedSprite): [ShadowedSprite, HTMLCanvasElement] => [
      name,
      silhouette(images[name]),
    ]),
  ) as Record<ShadowedSprite, HTMLCanvasElement>;
  return { images, shadows };
}
