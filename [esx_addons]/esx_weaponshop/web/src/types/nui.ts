/**
 * NUI Event Type Definitions for Backend Communication
 */

import type { ThemeConvars } from './shop';

/**
 * NUI Event Names - Type-safe event name constants
 */
export const NUI_EVENTS = {
  /** Purchase a weapon from the shop */
  BUY_WEAPON: 'buyWeapon',
  /** Purchase a weapon license */
  BUY_LICENSE: 'buyLicense',
  /** Close the UI */
  CLOSE_UI: 'closeUI',
} as const;

/**
 * Type helper for NUI event names
 */
export type NuiEventName = typeof NUI_EVENTS[keyof typeof NUI_EVENTS];

/**
 * Response from ready callback
 */
export interface ReadyResponse {
  theme: ThemeConvars;
}
