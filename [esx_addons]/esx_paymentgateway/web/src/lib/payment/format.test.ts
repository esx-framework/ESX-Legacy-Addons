/**
 * Tests for how money is written in the dialog.
 *
 * @see formatMoney
 */

import { describe, expect, it } from 'vitest';
import { formatMoney } from './format';

describe('formatMoney', (): void => {
  it('should group thousands in English by default', (): void => {
    expect(formatMoney(1250, '$')).toBe('$1,250');
  });

  it('should group the way the server locale does', (): void => {
    expect(formatMoney(1250000, '$', 'de')).toBe('$1.250.000');
  });

  it('should cut fractions of a balance instead of rounding them up', (): void => {
    expect(formatMoney(99.99, '$')).toBe('$99');
  });

  it('should fall back to English for a tag Intl does not accept', (): void => {
    expect(formatMoney(1250, '$', 'not a locale')).toBe('$1,250');
  });
});
