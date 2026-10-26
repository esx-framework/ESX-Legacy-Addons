/**
 * The server's UI theme on the page. Lua reads the `esx:ui:*` convars with
 * `xLib.colors.getESXTheme()` and sends them with every payment. The colors replace the ESX UI
 * kit's custom properties, so kit components and the page's own styles follow them alike. Every
 * color also gets an RGB channel variable (`--brand-color-rgb: 251, 155, 4`) for tints: CEF 103
 * has no color-mix(), but `rgba(var(--brand-color-rgb), 0.2)` works.
 *
 * @see applyTheme
 */

import type { Theme } from '../nui/messages';
import { isLogoUrl, isThemeColor } from '../nui/validate';

/** Theme colors the convars can set. */
type ThemeColor = Exclude<keyof Theme, 'logoUrl'>;

/** ESX UI kit colors used when the server sets none. */
const KIT: Readonly<Record<ThemeColor, string>> = {
  primaryColor: '#fb9b04',
  secondaryColor: '#252525',
  backgroundColor: '#161616',
  accentColor: '#383838',
};

/** Kit custom property each theme color drives. */
const PROPERTY: Readonly<Record<ThemeColor, string>> = {
  primaryColor: '--brand-color',
  secondaryColor: '--dark-color',
  backgroundColor: '--darkest-color',
  accentColor: '--mid-color',
};

/**
 * @param hex - Color as #rgb or #rrggbb
 * @returns The color's channels as "r, g, b"
 */
export function toRgbChannels(hex: string): string {
  const digits =
    hex.length === 4
      ? hex
          .slice(1)
          .split('')
          .map((digit: string): string => digit + digit)
          .join('')
      : hex.slice(1);
  const value = Number.parseInt(digits, 16);
  return `${(value >> 16) & 255}, ${(value >> 8) & 255}, ${value & 255}`;
}

/**
 * Works out the custom properties of a theme. Missing or invalid colors use the kit's.
 *
 * @param theme - Theme from the open message, undefined for the kit defaults
 * @returns Custom property names and their values
 */
export function themeVariables(theme: Theme | undefined): Record<string, string> {
  const variables: Record<string, string> = {};
  for (const key of Object.keys(PROPERTY) as ThemeColor[]) {
    const value = theme?.[key];
    const color = isThemeColor(value) ? value : KIT[key];
    variables[PROPERTY[key]] = color;
    variables[`${PROPERTY[key]}-rgb`] = toRgbChannels(color);
  }
  return variables;
}

/**
 * Applies a theme to the page, replacing the previous one.
 *
 * @param theme - Theme from the open message, undefined for the kit defaults
 * @param root - Element that carries the custom properties
 * @returns The server's logo URL, or null for the ESX mark
 */
export function applyTheme(
  theme: Theme | undefined,
  root: HTMLElement = document.documentElement,
): string | null {
  for (const [property, value] of Object.entries(themeVariables(theme))) {
    root.style.setProperty(property, value);
  }
  return isLogoUrl(theme?.logoUrl) ? theme.logoUrl : null;
}
