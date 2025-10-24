/**
 * NUI Event Type Definitions for Backend Communication
 */

import type { PaymentMethod, ThemeConvars } from './shop';

/**
 * Purchase request payload sent to backend
 */
export interface PurchaseRequest {
  items: Array<{
    name: string;
    quantity: number;
    price: number;
  }>;
  total: number;
  paymentMethod: PaymentMethod;
}

/**
 * Purchase response from backend
 */
export interface PurchaseResponse {
  success: boolean;
  message?: string;
}

/**
 * Generic success response structure
 */
export interface SuccessResponse {
  success: boolean;
  message?: string;
}

/**
 * Error response from backend
 */
export interface ErrorResponse {
  success: false;
  error: string;
  code?: string;
}

/**
 * NUI Event Names - Type-safe event name constants
 */
export const NUI_EVENTS = {
  /** Purchase items from shop */
  PURCHASE_ITEMS: 'purchaseItems',
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
