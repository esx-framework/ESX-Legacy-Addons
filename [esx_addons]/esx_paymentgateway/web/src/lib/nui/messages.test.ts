/**
 * Tests for the validation of messages from Lua.
 *
 * @see parseNuiMessage
 */

import { describe, expect, it } from 'vitest';
import { parseNuiMessage } from './messages';

const payment = {
  id: 7,
  amount: 1250,
  currency: '$',
  title: 'Vehicle repair',
  description: 'Los Santos Customs',
  methods: ['cash', 'card'],
  balances: { cash: 4820, card: 18500 },
};

describe('parseNuiMessage', (): void => {
  it('should accept an open message as Lua sends it', (): void => {
    expect(parseNuiMessage({ action: 'open', payment })).toEqual({ action: 'open', payment });
  });

  it('should drop an optional description that is not text', (): void => {
    const message = parseNuiMessage({ action: 'open', payment: { ...payment, description: 3 } });
    expect(message?.action === 'open' && message.payment.description).toBeUndefined();
  });

  it.each([
    ['a missing id', { id: undefined }],
    ['a fractional amount', { amount: 12.5 }],
    ['a zero amount', { amount: 0 }],
    ['a negative amount', { amount: -1 }],
    ['an empty title', { title: '   ' }],
    ['a long currency', { currency: 'DOLLAR' }],
    ['no known method', { methods: ['crypto'] }],
    ['methods that are not a list', { methods: 'cash' }],
    ['a negative balance', { balances: { cash: -1, card: 0 } }],
    ['a missing balance', { balances: { cash: 10 } }],
  ])('should refuse an open message with %s', (_label: string, change: object): void => {
    expect(parseNuiMessage({ action: 'open', payment: { ...payment, ...change } })).toBeUndefined();
  });

  it('should keep the known methods once and in dialog order', (): void => {
    const message = parseNuiMessage({
      action: 'open',
      payment: { ...payment, methods: ['card', 'crypto', 'cash', 'card'] },
    });
    expect(message?.action === 'open' && message.payment.methods).toEqual(['cash', 'card']);
  });

  it('should keep valid theme fields and drop the rest', (): void => {
    const message = parseNuiMessage({
      action: 'open',
      payment,
      theme: {
        primaryColor: '#2F80ED',
        secondaryColor: 'red',
        backgroundColor: '#111',
        logoUrl: 'https://cdn.example.com/logo.png',
      },
    });
    expect(message?.action === 'open' && message.theme).toEqual({
      primaryColor: '#2F80ED',
      backgroundColor: '#111',
      logoUrl: 'https://cdn.example.com/logo.png',
    });
  });

  it.each([
    ['a script URL', 'javascript:alert(1)'],
    ['quotes', 'https://cdn.example.com/a".png'],
    ['a data URL', 'data:image/png;base64,AAAA'],
  ])('should refuse a logo URL with %s', (_label: string, logoUrl: string): void => {
    const message = parseNuiMessage({ action: 'open', payment, theme: { logoUrl } });
    expect(message?.action === 'open' && message.theme).toBeUndefined();
  });

  it('should keep labels with plain keys and short texts', (): void => {
    const message = parseNuiMessage({
      action: 'open',
      payment,
      labels: { pay: 'Bezahlen', 'Bad Key': 'x', cancel: '', long: 'x'.repeat(200), done: 5 },
    });
    expect(message?.action === 'open' && message.labels).toEqual({ pay: 'Bezahlen' });
  });

  it.each([
    ['de', 'de'],
    ['pt_BR', 'pt-BR'],
    ['<b>', undefined],
  ])('should read the locale %s as %s', (locale: string, expected: string | undefined): void => {
    const message = parseNuiMessage({ action: 'open', payment, locale });
    expect(message?.action === 'open' && message.locale).toBe(expected);
  });

  it('should accept a result and drop its invalid fields', (): void => {
    expect(
      parseNuiMessage({
        action: 'result',
        result: { id: 7, ok: true, method: 'card', message: 'Paid.', balances: { cash: 1 } },
      }),
    ).toEqual({ action: 'result', result: { id: 7, ok: true, method: 'card', message: 'Paid.' } });
  });

  it('should refuse a result without an outcome', (): void => {
    expect(parseNuiMessage({ action: 'result', result: { id: 7 } })).toBeUndefined();
  });

  it('should accept a close message', (): void => {
    expect(parseNuiMessage({ action: 'close' })).toEqual({ action: 'close' });
  });

  it.each([null, 'open', 42, { action: 'unknown' }, { action: 'open' }])(
    'should refuse %j',
    (data: unknown): void => {
      expect(parseNuiMessage(data)).toBeUndefined();
    },
  );
});
