/**
 * The payment on screen and where the player is with it: choosing a method, waiting for the
 * server, or looking at the receipt. The flow has no side effects; it returns the callback
 * bodies to send, and the page sends them.
 *
 * @see flow
 */

import type { ClosePayload, OpenMessage, PayPayload } from '../nui/messages';
import { resolveLabels, type DialogLabels } from './labels';
import type { Balances, Payment, PaymentMethod, PaymentResult } from './types';

/** Where the player is with the payment. */
export type Phase = 'choosing' | 'paying' | 'paid';

/** What the receipt shows once the seller took the money. */
export interface Receipt {
  /** Method that paid */
  method: PaymentMethod;
  /** Balance of that method afterwards */
  balance: number;
  /** Reference the seller gave, e.g. an invoice number; null leaves the line out */
  reference: string | null;
}

/** The dialog's state. */
export class PaymentFlow {
  /** Payment on screen, null while the dialog is closed */
  payment: Payment | null = $state(null);
  /** Where the player is with it */
  phase: Phase = $state('choosing');
  /** Chosen method, null when none can pay */
  method: PaymentMethod | null = $state(null);
  /** Latest balances the server reported */
  balances: Balances = $state({ cash: 0, card: 0 });
  /** Why the last attempt failed, from the server's locale */
  error: string | null = $state(null);
  /** Counts refused attempts, so the dialog can replay its refusal cue on every one */
  refusals: number = $state(0);
  /** Set once the server took the money */
  receipt: Receipt | null = $state(null);
  /** Texts of the dialog */
  labels: DialogLabels = $state(resolveLabels(undefined));
  /** Locale money is grouped by */
  locale: string = $state('en');

  /** Methods the payment offers that the player can afford. */
  affordable: PaymentMethod[] = $derived(
    this.payment?.methods.filter((method: PaymentMethod): boolean => this.canAfford(method)) ?? [],
  );

  /**
   * Shows a payment, replacing whatever was open.
   *
   * @param message - Open message from Lua
   */
  open(message: OpenMessage): void {
    this.payment = message.payment;
    this.balances = message.payment.balances;
    this.labels = resolveLabels(message.labels);
    this.locale = message.locale ?? 'en';
    this.phase = 'choosing';
    this.error = null;
    this.refusals = 0;
    this.receipt = null;
    this.method = this.affordable[0] ?? null;
  }

  /**
   * @param method - Method to check
   * @returns Whether that balance covers the payment
   */
  canAfford(method: PaymentMethod): boolean {
    return this.payment !== null && this.balances[method] >= this.payment.amount;
  }

  /**
   * Picks a method while the player is still choosing.
   *
   * @param method - Method to use
   * @returns Whether the choice was taken
   */
  choose(method: PaymentMethod): boolean {
    if (this.phase !== 'choosing' || !this.payment?.methods.includes(method)) return false;
    if (!this.canAfford(method)) return false;
    this.method = method;
    this.error = null;
    return true;
  }

  /**
   * Starts paying with the chosen method.
   *
   * @returns Body of the `pay` callback, or null when nothing can be paid right now
   */
  pay(): PayPayload | null {
    if (this.phase !== 'choosing' || !this.payment || !this.method) return null;
    if (!this.canAfford(this.method)) return null;
    this.phase = 'paying';
    this.error = null;
    return { id: this.payment.id, method: this.method };
  }

  /**
   * Takes the server's answer. Answers for another payment are ignored.
   *
   * @param result - Result message from Lua
   * @returns Whether the answer belonged to the payment on screen
   */
  answer(result: PaymentResult): boolean {
    if (!this.payment || result.id !== this.payment.id || this.phase !== 'paying') return false;
    if (result.balances) this.balances = result.balances;

    const method = result.method ?? this.method;
    if (result.ok && method) {
      this.phase = 'paid';
      this.receipt = {
        method,
        balance: this.balances[method],
        reference: result.reference ?? null,
      };
      return true;
    }

    this.phase = 'choosing';
    this.error = result.message ?? null;
    this.refusals += 1;
    if (!this.method || !this.canAfford(this.method)) this.method = this.affordable[0] ?? null;
    return true;
  }

  /**
   * Closes the dialog.
   *
   * @returns Body of the `close` callback while a payment was open, otherwise null
   */
  close(): ClosePayload | null {
    const payment = this.payment;
    this.payment = null;
    this.receipt = null;
    this.error = null;
    return payment ? { id: payment.id } : null;
  }
}

/** The dialog's state. */
export const flow = new PaymentFlow();
