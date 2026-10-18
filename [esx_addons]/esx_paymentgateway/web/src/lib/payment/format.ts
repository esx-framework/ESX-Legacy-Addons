/**
 * Money on the page: whole units grouped the way the server's locale writes them, the currency
 * symbol in front as GTA shows it ("$1,250", "$1.250").
 *
 * @see formatMoney
 */

const FALLBACK_LOCALE = 'en-US';

/** Number formats by locale, built once each. */
const formats = new Map<string, Intl.NumberFormat>();

function numberFormat(locale: string): Intl.NumberFormat {
  let format = formats.get(locale);
  if (!format) {
    try {
      format = new Intl.NumberFormat(locale, { maximumFractionDigits: 0 });
    } catch (err: unknown) {
      // An unknown locale tag throws a RangeError; fall back rather than break the dialog.
      if (!(err instanceof RangeError)) throw err;
      format = new Intl.NumberFormat(FALLBACK_LOCALE, { maximumFractionDigits: 0 });
    }
    formats.set(locale, format);
  }
  return format;
}

/**
 * @param amount - Money in whole units; fractions are cut off, never rounded up
 * @param locale - BCP 47 tag of the server's locale, English when left out
 * @returns The number grouped the way the locale writes it, without a currency
 */
export function formatNumber(amount: number, locale: string = FALLBACK_LOCALE): string {
  return numberFormat(locale).format(Math.floor(amount));
}

/**
 * @param amount - Money in whole units; fractions are cut off, never rounded up
 * @param currency - Symbol shown before the number
 * @param locale - BCP 47 tag of the server's locale, English when left out
 * @returns The amount as the dialog shows it
 */
export function formatMoney(
  amount: number,
  currency: string,
  locale: string = FALLBACK_LOCALE,
): string {
  return `${currency}${formatNumber(amount, locale)}`;
}

/**
 * @param ms - Time left in milliseconds
 * @returns The time as minutes and seconds ("1:05"), rounded up so 0:00 means it is over
 */
export function formatClock(ms: number): string {
  const seconds = Math.max(0, Math.ceil(ms / 1000));
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;
}

/**
 * @param id - Server id of the payment
 * @returns The id as the player sees it on the bill and the receipt, e.g. "#000042"
 */
export function formatReference(id: number): string {
  return `#${String(id).padStart(6, '0')}`;
}
