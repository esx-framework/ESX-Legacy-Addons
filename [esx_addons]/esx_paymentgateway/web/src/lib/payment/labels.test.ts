/**
 * Tests for the dialog texts.
 *
 * @see resolveLabels
 * @see fill
 */

import { describe, expect, it } from 'vitest';
import { DEFAULT_LABELS, fill, fillParts, resolveLabels } from './labels';

describe('resolveLabels', (): void => {
  it('should use the English texts without overrides', (): void => {
    expect(resolveLabels(undefined)).toEqual(DEFAULT_LABELS);
  });

  it('should take the locale texts and ignore unknown keys', (): void => {
    const labels = resolveLabels({ cancel: 'Abbrechen', unknown: 'x' });
    expect(labels.cancel).toBe('Abbrechen');
    expect(labels.done).toBe('Done');
    expect('unknown' in labels).toBe(false);
  });
});

describe('fillParts', (): void => {
  it('should keep the filled-in value as its own piece', (): void => {
    expect(fillParts('After paying {amount}', { amount: '$3,570' })).toEqual([
      { text: 'After paying ', value: false },
      { text: '$3,570', value: true },
    ]);
  });

  it('should leave an unknown placeholder in the text', (): void => {
    expect(fillParts('{amount} of {total}', { amount: '$5' })).toEqual([
      { text: '$5', value: true },
      { text: ' of {total}', value: false },
    ]);
  });
});

describe('fill', (): void => {
  it('should replace a placeholder', (): void => {
    expect(fill('Pay {amount} by card', { amount: '$1,250' })).toBe('Pay $1,250 by card');
  });

  it('should keep a placeholder it has no value for', (): void => {
    expect(fill('{amount} left', {})).toBe('{amount} left');
  });
});
