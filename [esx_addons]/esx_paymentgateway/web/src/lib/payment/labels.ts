/**
 * Texts of the dialog. Lua sends them from the resource's locale with every payment; English
 * defaults stand in for anything a locale leaves out. `{amount}` in a text is replaced with the
 * formatted money it refers to.
 *
 * @see resolveLabels
 * @see fill
 */

import type { Labels } from '../nui/messages';

/** English texts, also the list of keys the dialog uses. */
export const DEFAULT_LABELS = {
  heading: 'Payment',
  choose: 'Pay with',
  total: 'Total',
  cash: 'Cash',
  card: 'Card',
  remaining: 'After paying {amount}',
  short: '{amount} short',
  pay_cash: 'Pay {amount} in cash',
  pay_card: 'Pay {amount} by card',
  hold_cash: 'Hold to pay {amount} in cash',
  hold_card: 'Hold to pay {amount} by card',
  unaffordable: 'Not enough money for this payment',
  unreachable: 'The payment did not go through. Try again.',
  processing: 'Processing',
  cancel: 'Cancel',
  success: 'Payment complete',
  paid_with: 'Paid with',
  new_balance: 'New balance',
  reference: 'Reference',
  done: 'Done',
} as const;

/** Key of a dialog text. */
export type LabelKey = keyof typeof DEFAULT_LABELS;

/** Every dialog text, resolved. */
export type DialogLabels = Record<LabelKey, string>;

/**
 * Merges the texts Lua sent over the English defaults. Unknown keys are ignored.
 *
 * @param overrides - Texts from the open message
 * @returns A text for every key
 */
export function resolveLabels(overrides: Labels | undefined): DialogLabels {
  const labels: DialogLabels = { ...DEFAULT_LABELS };
  if (!overrides) return labels;
  for (const key of Object.keys(DEFAULT_LABELS) as LabelKey[]) {
    const text = overrides[key];
    if (text !== undefined) labels[key] = text;
  }
  return labels;
}

/**
 * Replaces `{name}` placeholders. Placeholders without a value stay as they are.
 *
 * @param template - Text with placeholders
 * @param values - Replacement by placeholder name
 * @returns The filled text
 */
export function fill(template: string, values: Readonly<Record<string, string>>): string {
  return template.replace(
    /\{(\w+)\}/g,
    (match: string, name: string): string => values[name] ?? match,
  );
}

/** A piece of a filled text: plain text, or a value that was put in for a placeholder. */
export interface TextPart {
  /** The text of the piece */
  text: string;
  /** Whether the piece is a filled-in value, which the dialog can set apart */
  value: boolean;
}

/**
 * Fills `{name}` placeholders like {@link fill}, but keeps the filled-in values as their own
 * pieces, so the dialog can set them apart, e.g. in bold.
 *
 * @param template - Text with placeholders
 * @param values - Replacement by placeholder name
 * @returns The text in pieces, empty pieces left out
 */
export function fillParts(template: string, values: Readonly<Record<string, string>>): TextPart[] {
  const parts: TextPart[] = [];
  let rest = 0;
  for (const match of template.matchAll(/\{(\w+)\}/g)) {
    const value = values[match[1] ?? ''];
    if (value === undefined) continue;
    if (match.index > rest) parts.push({ text: template.slice(rest, match.index), value: false });
    parts.push({ text: value, value: true });
    rest = match.index + match[0].length;
  }
  if (rest < template.length) parts.push({ text: template.slice(rest), value: false });
  return parts;
}
