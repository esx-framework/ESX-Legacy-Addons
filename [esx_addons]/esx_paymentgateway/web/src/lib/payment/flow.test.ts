/**
 * Tests for the payment flow: choosing, paying, the server's answer and closing.
 *
 * @see PaymentFlow
 */

import { beforeEach, describe, expect, it } from 'vitest';
import type { OpenMessage } from '../nui/messages';
import { PaymentFlow } from './flow.svelte';

function openMessage(cash: number, card: number): OpenMessage {
  return {
    action: 'open',
    payment: {
      id: 42,
      amount: 1000,
      currency: '$',
      title: 'Vehicle repair',
      methods: ['cash', 'card'],
      balances: { cash, card },
    },
  };
}

describe('PaymentFlow', (): void => {
  let flow: PaymentFlow;

  beforeEach((): void => {
    flow = new PaymentFlow();
  });

  it('should preselect the first method the player can afford', (): void => {
    flow.open(openMessage(200, 5000));
    expect(flow.method).toBe('card');
    expect(flow.affordable).toEqual(['card']);
  });

  it('should preselect nothing when no balance covers the payment', (): void => {
    flow.open(openMessage(10, 20));
    expect(flow.method).toBeNull();
    expect(flow.pay()).toBeNull();
  });

  it('should refuse a method the player cannot afford', (): void => {
    flow.open(openMessage(200, 5000));
    expect(flow.choose('cash')).toBe(false);
    expect(flow.method).toBe('card');
  });

  it('should send only the payment id and the method', (): void => {
    flow.open(openMessage(5000, 5000));
    flow.choose('card');
    expect(flow.pay()).toEqual({ id: 42, method: 'card' });
    expect(flow.phase).toBe('paying');
    expect(flow.choose('cash')).toBe(false);
  });

  it('should show the receipt when the server took the money', (): void => {
    flow.open(openMessage(5000, 5000));
    flow.pay();
    flow.answer({ id: 42, ok: true, method: 'cash', balances: { cash: 4000, card: 5000 } });
    expect(flow.phase).toBe('paid');
    expect(flow.receipt).toEqual({ method: 'cash', balance: 4000, reference: '#000042' });
  });

  it('should go back to choosing with the reason when the server refused', (): void => {
    flow.open(openMessage(5000, 5000));
    flow.pay();
    flow.answer({
      id: 42,
      ok: false,
      message: 'Not enough money in cash.',
      balances: { cash: 300, card: 5000 },
    });
    expect(flow.phase).toBe('choosing');
    expect(flow.error).toBe('Not enough money in cash.');
    expect(flow.refusals).toBe(1);
    expect(flow.method).toBe('card');
  });

  it('should ignore an answer for another payment', (): void => {
    flow.open(openMessage(5000, 5000));
    flow.pay();
    expect(flow.answer({ id: 7, ok: true, method: 'cash' })).toBe(false);
    expect(flow.phase).toBe('paying');
  });

  it('should hand back the id when the player closes an open payment', (): void => {
    flow.open(openMessage(5000, 5000));
    expect(flow.close()).toEqual({ id: 42 });
    expect(flow.payment).toBeNull();
    expect(flow.close()).toBeNull();
  });
});
