/**
 * Checks for values that arrive from Lua. Everything the page gets through SendNUIMessage is
 * treated as untrusted and narrowed here before it reaches state or markup.
 *
 * @see parseNuiMessage
 */

import { PAYMENT_METHODS, type Balances, type PaymentMethod } from '../payment/types';

/** Largest amount or balance the page accepts; above it doubles lose whole units. */
export const MAX_MONEY = Number.MAX_SAFE_INTEGER;

const HEX_COLOR = /^#(?:[0-9a-f]{3}|[0-9a-f]{6})$/i;
const LOGO_URL = /^(?:https?|nui):\/\/[^\s"'<>()\\]{1,500}$/i;

/**
 * @param value - Untrusted value
 * @returns Whether the value is a plain object or array
 */
export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

/**
 * @param value - Untrusted value
 * @param maxLength - Longest accepted length
 * @returns Whether the value is a non-empty string of at most `maxLength` characters
 */
export function isText(value: unknown, maxLength: number): value is string {
  return typeof value === 'string' && value.trim().length > 0 && value.length <= maxLength;
}

/**
 * @param value - Untrusted value
 * @returns Whether the value is a positive whole number id
 */
export function isId(value: unknown): value is number {
  return typeof value === 'number' && Number.isSafeInteger(value) && value > 0;
}

/**
 * @param value - Untrusted value
 * @returns Whether the value is a price: a whole number from 1 to {@link MAX_MONEY}
 */
export function isAmount(value: unknown): value is number {
  return typeof value === 'number' && Number.isSafeInteger(value) && value >= 1;
}

/**
 * @param value - Untrusted value
 * @returns Whether the value is a balance: a finite number from 0 to {@link MAX_MONEY}
 */
export function isBalance(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0 && value <= MAX_MONEY;
}

/**
 * @param value - Untrusted value
 * @returns Whether the value names a payment method
 */
export function isPaymentMethod(value: unknown): value is PaymentMethod {
  return typeof value === 'string' && (PAYMENT_METHODS as readonly string[]).includes(value);
}

/**
 * @param value - Untrusted value
 * @returns Whether the value is a #rgb or #rrggbb color
 */
export function isThemeColor(value: unknown): value is string {
  return typeof value === 'string' && HEX_COLOR.test(value);
}

/**
 * @param value - Untrusted value
 * @returns Whether the value is an http(s) or nui URL that is safe to put in an img src
 */
export function isLogoUrl(value: unknown): value is string {
  return typeof value === 'string' && LOGO_URL.test(value);
}

/**
 * @param value - Untrusted value
 * @returns Both balances, or undefined unless both are valid
 */
export function parseBalances(value: unknown): Balances | undefined {
  if (!isRecord(value) || !isBalance(value.cash) || !isBalance(value.card)) return undefined;
  return { cash: value.cash, card: value.card };
}

/**
 * Keeps the known methods of a list in the dialog's order, each once.
 *
 * @param value - Untrusted value
 * @returns The methods, or undefined when none is valid
 */
export function parseMethods(value: unknown): PaymentMethod[] | undefined {
  if (!Array.isArray(value)) return undefined;
  const methods = PAYMENT_METHODS.filter((method: PaymentMethod): boolean =>
    value.includes(method),
  );
  return methods.length > 0 ? methods : undefined;
}
