/**
 * Tests for how money is written in the dialog.
 *
 * @see formatMoney
 */

import { describe, expect, it } from 'vitest';
import { formatClock, formatMoney, formatReference } from './format';

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

describe('formatClock', (): void => {
  it.each([
    [120_000, '2:00'],
    [65_000, '1:05'],
    [14_200, '0:15'],
    [400, '0:01'],
    [0, '0:00'],
    [-500, '0:00'],
  ])('should show %i ms as %s', (ms: number, clock: string): void => {
    expect(formatClock(ms)).toBe(clock);
  });
});

describe('formatReference', (): void => {
  it('should pad the id to six digits', (): void => {
    expect(formatReference(42)).toBe('#000042');
  });
});
