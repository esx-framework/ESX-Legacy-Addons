/**
 * Messages between the Lua client script and the page, and their validation. The page shows a
 * payment the server opened, sends back the method the player picked and shows the answer.
 *
 * @see parseNuiMessage
 */

import type { Payment, PaymentResult } from '../payment/types';
import {
  isAmount,
  isId,
  isLogoUrl,
  isPaymentMethod,
  isRecord,
  isText,
  isThemeColor,
  parseBalances,
  parseMethods,
} from './validate';

/**
 * The server's UI theme, read from the `esx:ui:*` convars with `xLib.colors.getESXTheme()`.
 * Every field is optional; anything missing or invalid falls back to the ESX UI kit.
 */
export interface Theme {
  /** Brand color as #rgb or #rrggbb: the pay button, the chosen method, highlights */
  primaryColor?: string;
  /** Raised surfaces: the dialog card */
  secondaryColor?: string;
  /** Deepest surface: the dim behind the dialog and the method tiles */
  backgroundColor?: string;
  /** Inactive controls, borders and fills */
  accentColor?: string;
  /** Logo in the dialog header, an http(s) or nui URL */
  logoUrl?: string;
}

/** Texts of the dialog by key, translated by the resource's locale. */
export type Labels = Record<string, string>;

/** Opens the dialog for a payment. */
export interface OpenMessage {
  /** Discriminator */
  action: 'open';
  /** The payment to show */
  payment: Payment;
  /** Server theme; the ESX UI kit when left out */
  theme?: Theme;
  /** Dialog texts from the resource's locale; English defaults fill the rest */
  labels?: Labels;
  /** The resource's locale as a BCP 47 tag ("en", "de"), used to group money */
  locale?: string;
  /** Milliseconds the receipt stays before the dialog closes itself, 0 to wait for Done */
  closeDelay?: number;
  /** Sound volume from the resource config, 0 silent to 1 full; the page default when left out */
  volume?: number;
}

/** The seller's answer to the method the player chose. */
export interface ResultMessage {
  /** Discriminator */
  action: 'result';
  /** The answer */
  result: PaymentResult;
}

/** Closes the dialog without an answer, e.g. after a plain pick or when the player died. */
export interface CloseMessage {
  /** Discriminator */
  action: 'close';
}

/** Any message Lua can send to the page. */
export type NuiMessage = OpenMessage | ResultMessage | CloseMessage;

/** Body of the `pay` NUI callback. */
export interface PayPayload {
  /** Id of the payment */
  id: number;
  /** Method the player chose */
  method: Payment['methods'][number];
}

/** Body of the `close` NUI callback. */
export interface ClosePayload {
  /** Id of the payment the player walked away from */
  id: number;
}

/** Body of the `shown` NUI callback. */
export interface ShownPayload {
  /** Id of the payment the dialog now shows */
  id: number;
}

/** Longest title, description and label the page shows, in characters. */
const MAX_TEXT = 120;
/** Longest currency symbol, e.g. "$" or "USD". */
const MAX_CURRENCY = 4;
const THEME_COLORS = ['primaryColor', 'secondaryColor', 'backgroundColor', 'accentColor'] as const;
const LABEL_KEY = /^[a-z][a-z_]{0,39}$/;
const LOCALE = /^[a-z]{2,3}(?:[-_][A-Za-z]{2})?$/;
/** Longest receipt reference, e.g. "LSC-004211". */
const MAX_REFERENCE = 40;
/** Longest the receipt may stay on its own, in milliseconds. */
const MAX_CLOSE_DELAY = 30_000;

/** Keeps the valid fields of a theme; an empty theme is dropped. */
function parseTheme(value: unknown): Theme | undefined {
  if (!isRecord(value)) return undefined;
  const theme: Theme = {};
  for (const key of THEME_COLORS) {
    const color = value[key];
    if (isThemeColor(color)) theme[key] = color;
  }
  if (isLogoUrl(value.logoUrl)) theme.logoUrl = value.logoUrl;
  return Object.keys(theme).length > 0 ? theme : undefined;
}

/** Keeps the labels with a plain key and a short text; an empty set is dropped. */
function parseLabels(value: unknown): Labels | undefined {
  if (!isRecord(value) || Array.isArray(value)) return undefined;
  const labels: Labels = {};
  for (const [key, text] of Object.entries(value)) {
    if (LABEL_KEY.test(key) && isText(text, MAX_TEXT)) labels[key] = text;
  }
  return Object.keys(labels).length > 0 ? labels : undefined;
}

function parsePayment(value: unknown): Payment | undefined {
  if (!isRecord(value)) return undefined;
  const { id, amount, currency, title, description } = value;
  const methods = parseMethods(value.methods);
  const balances = parseBalances(value.balances);
  if (!isId(id) || !isAmount(amount) || !methods || !balances) return undefined;
  if (!isText(currency, MAX_CURRENCY) || !isText(title, MAX_TEXT)) return undefined;
  const payment: Payment = { id, amount, currency, title, methods, balances };
  if (isText(description, MAX_TEXT)) payment.description = description;
  if (value.hold === true) payment.hold = true;
  return payment;
}

function parseResult(value: unknown): PaymentResult | undefined {
  if (!isRecord(value) || !isId(value.id) || typeof value.ok !== 'boolean') return undefined;
  const result: PaymentResult = { id: value.id, ok: value.ok };
  if (isPaymentMethod(value.method)) result.method = value.method;
  if (isText(value.message, MAX_TEXT)) result.message = value.message;
  const balances = parseBalances(value.balances);
  if (balances) result.balances = balances;
  if (isText(value.reference, MAX_REFERENCE)) result.reference = value.reference;
  return result;
}

/**
 * Finds the payment of an open message the page refused, so Lua can end that payment instead of
 * leaving it open with nothing on screen.
 *
 * @param data - `event.data` of a message {@link parseNuiMessage} refused
 * @returns The payment id, or undefined when the data is no open message with a usable id
 */
export function refusedPaymentId(data: unknown): number | undefined {
  if (!isRecord(data) || data.action !== 'open' || !isRecord(data.payment)) return undefined;
  const { id } = data.payment;
  return isId(id) ? id : undefined;
}

/**
 * Validates raw `message` event data.
 *
 * @param data - `event.data` of a window message event
 * @returns The typed message, or undefined if the data is not a valid message
 */
export function parseNuiMessage(data: unknown): NuiMessage | undefined {
  if (!isRecord(data)) return undefined;

  switch (data.action) {
    case 'open': {
      const payment = parsePayment(data.payment);
      if (!payment) return undefined;
      const message: OpenMessage = { action: 'open', payment };
      const theme = parseTheme(data.theme);
      if (theme) message.theme = theme;
      const labels = parseLabels(data.labels);
      if (labels) message.labels = labels;
      if (typeof data.locale === 'string' && LOCALE.test(data.locale)) {
        message.locale = data.locale.replace('_', '-');
      }
      const { closeDelay } = data;
      if (typeof closeDelay === 'number' && closeDelay >= 0 && closeDelay <= MAX_CLOSE_DELAY) {
        message.closeDelay = Math.round(closeDelay);
      }
      const { volume } = data;
      if (typeof volume === 'number' && volume >= 0 && volume <= 1) message.volume = volume;
      return message;
    }
    case 'result': {
      const result = parseResult(data.result);
      return result ? { action: 'result', result } : undefined;
    }
    case 'close':
      return { action: 'close' };
    default:
      return undefined;
  }
}
