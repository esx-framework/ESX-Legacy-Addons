/**
 * Tests for the NUI message validation.
 */

import { describe, expect, it } from 'vitest';
import { parseNuiMessage } from './messages';

const validSession = { id: 'job-42', game: 'wiring', seed: 1234, difficulty: 2 };

describe('parseNuiMessage', () => {
  it('should accept a valid open message', () => {
    expect(parseNuiMessage({ action: 'open', session: validSession })).toEqual({
      action: 'open',
      session: validSession,
    });
  });

  it('should accept a close message', () => {
    expect(parseNuiMessage({ action: 'close' })).toEqual({ action: 'close' });
  });

  it('should drop extra session fields', () => {
    const result = parseNuiMessage({ action: 'open', session: { ...validSession, debug: true } });
    expect(result).toEqual({ action: 'open', session: validSession });
  });

  it.each([
    ['unknown action', { action: 'explode' }],
    ['non-object', 'open'],
    ['missing session', { action: 'open' }],
    ['unknown game', { action: 'open', session: { ...validSession, game: 'plumbing' } }],
    ['fractional seed', { action: 'open', session: { ...validSession, seed: 1.5 } }],
    ['negative seed', { action: 'open', session: { ...validSession, seed: -1 } }],
    ['seed above 32 bit', { action: 'open', session: { ...validSession, seed: 2 ** 32 } }],
    ['difficulty out of range', { action: 'open', session: { ...validSession, difficulty: 4 } }],
    ['id with markup', { action: 'open', session: { ...validSession, id: '<img src=x>' } }],
    ['empty id', { action: 'open', session: { ...validSession, id: '' } }],
  ])('should reject %s', (_label: string, data: unknown) => {
    expect(parseNuiMessage(data)).toBeUndefined();
  });
});
