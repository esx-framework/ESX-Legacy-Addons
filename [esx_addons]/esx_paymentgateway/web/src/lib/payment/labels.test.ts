/**
 * Tests for the dialog texts.
 *
 * @see resolveLabels
 * @see fill
 */

import { describe, expect, it } from 'vitest';
import { DEFAULT_LABELS, fill, resolveLabels } from './labels';

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

describe('fill', (): void => {
  it('should replace a placeholder', (): void => {
    expect(fill('Pay {amount} by card', { amount: '$1,250' })).toBe('Pay $1,250 by card');
  });

  it('should keep a placeholder it has no value for', (): void => {
    expect(fill('{amount} left', {})).toBe('{amount} left');
  });
});
