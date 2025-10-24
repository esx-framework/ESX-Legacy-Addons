/**
 * UI Constants - Centralized configuration values
 *
 * This file contains all magic numbers and hard-coded values used across the UI.
 * Centralizing these values improves maintainability and follows DRY principles.
 */

/** Base font size in pixels for scaling calculations */
export const BASE_FONT_SIZE = 16;

/** Debounce delay in milliseconds for resize and search input handlers */
export const DEBOUNCE_DELAY_MS = 150;

/**
 * Tax rate for price calculations (default to 19% VAT)
 */
export const TAX_RATE = 0.19;

/** Number of columns in the shop item grid layout */
export const GRID_COLUMNS = 5;

/**
 * RGB values for error/danger color
 * Used for remove buttons and error states
 */
export const ERROR_COLOR = {
  r: 244,
  g: 91,
  b: 105
} as const;

/** Color for placeholder/secondary icons (search icon, etc.) */
export const SEARCH_ICON_COLOR = '#aaa';

/**
 * Scaling breakpoints for different screen resolutions
 */
export const SCALING_BREAKPOINTS = {
  HD: { width: 1280, height: 720, scale: 0.65 },
  FHD: { width: 1920, height: 1080, scale: 1.0 },
  QHD: { width: 2560, height: 1440, scale: 1.15 },
  UHD: { width: 3840, height: 2160, scale: 1.25 },
  _5K: { width: 5120, height: 2880, scale: 1.35 }
} as const;

/** Array of breakpoint keys sorted by resolution (ascending) */
export const BREAKPOINT_KEYS = ['HD', 'FHD', 'QHD', 'UHD', '_5K'] as const;
