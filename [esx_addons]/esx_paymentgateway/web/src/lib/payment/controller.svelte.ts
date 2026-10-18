/**
 * Runs a payment between Lua and the dialog: takes the messages Lua sends, sends the player's
 * choices back, plays the cues that go with them and owns the timers around them (the shortest
 * working time of the pay button, the wait for the server's answer and the receipt's own close).
 *
 * @see controller
 */

import { DEFAULT_VOLUME, sounds } from '../audio/sounds';
import { postNui } from '../nui/bridge';
import {
  refusedPaymentId,
  type ClosePayload,
  type NuiMessage,
  type ShownPayload,
} from '../nui/messages';
import { applyTheme } from '../ui/theme';
import { flow } from './flow.svelte';
import { hold } from './hold.svelte';
import type { PaymentMethod } from './types';

/** How long the receipt stays when Lua does not say, in milliseconds. */
const DEFAULT_CLOSE_DELAY = 2600;
/** Shortest time the pay button shows that it is working, so an instant answer reads as one. */
const MIN_PAYING_MS = 650;
/** Longest the page waits for the server's answer before it lets the player try again. */
const ANSWER_TIMEOUT_MS = 10_000;

/** Glue between Lua, the flow and the dialog. */
class PaymentController {
  /** Server logo URL, null for the ESX mark */
  logo: string | null = $state(null);
  /** Milliseconds the receipt stays, 0 to wait for Done */
  closeDelay: number = $state(DEFAULT_CLOSE_DELAY);

  private payingSince = 0;
  private answerTimer: ReturnType<typeof setTimeout> | undefined;
  private closeTimer: ReturnType<typeof setTimeout> | undefined;

  /**
   * Takes a message from Lua.
   *
   * @param message - Validated NUI message
   */
  handle(message: NuiMessage): void {
    switch (message.action) {
      case 'open':
        this.clearTimers();
        hold.cancel();
        this.logo = applyTheme(message.theme);
        this.closeDelay = message.closeDelay ?? DEFAULT_CLOSE_DELAY;
        sounds.setVolume(message.volume ?? DEFAULT_VOLUME);
        flow.open(message);
        sounds.play('open');
        void this.notify('shown', { id: message.payment.id });
        break;
      case 'result': {
        const { result } = message;
        clearTimeout(this.answerTimer);
        const wait = Math.max(0, this.payingSince + MIN_PAYING_MS - Date.now());
        this.answerTimer = setTimeout((): void => {
          if (!flow.answer(result)) return;
          if (flow.phase !== 'paid') {
            sounds.play('refuse');
            return;
          }
          sounds.play(flow.receipt?.method === 'cash' ? 'cash' : 'card');
          if (this.closeDelay === 0) return;
          this.closeTimer = setTimeout((): void => void this.close(), this.closeDelay);
        }, wait);
        break;
      }
      case 'close':
        this.clearTimers();
        flow.close();
        break;
      default:
        break;
    }
  }

  /**
   * Ends a payment the page cannot show, e.g. after Lua and the page got out of step, so the
   * server cancels it right away instead of the player waiting for nothing until it expires.
   *
   * @param data - Raw data of a message the page refused
   */
  refuse(data: unknown): void {
    const id = refusedPaymentId(data);
    if (id === undefined) return;
    console.warn(`[esx_paymentgateway] cannot show payment ${id}, cancelling it`);
    void this.notify('close', { id });
  }

  /**
   * Chooses a method.
   *
   * @param method - Method the player picked
   */
  choose(method: PaymentMethod): void {
    const changed = flow.method !== method;
    if (flow.choose(method) && changed) sounds.play('select');
  }

  /** Pays with the chosen method and waits for the server's answer. */
  async pay(): Promise<void> {
    const body = flow.pay();
    if (!body) return;
    this.payingSince = Date.now();
    sounds.play('press');
    const giveUp = (): void => {
      if (flow.answer({ id: body.id, ok: false, message: flow.labels.unreachable })) {
        sounds.play('refuse');
      }
    };
    this.answerTimer = setTimeout(giveUp, ANSWER_TIMEOUT_MS);
    try {
      await postNui('pay', body);
    } catch (err: unknown) {
      console.error('[esx_paymentgateway] pay callback failed', err);
      clearTimeout(this.answerTimer);
      giveUp();
    }
  }

  /** Closes the dialog, before or after paying; not while the server answers. */
  async close(): Promise<void> {
    if (flow.phase === 'paying') return;
    this.clearTimers();
    const body = flow.close();
    if (!body) return;
    sounds.play('close');
    try {
      await postNui('close', body);
    } catch (err: unknown) {
      console.error('[esx_paymentgateway] close callback failed', err);
    }
  }

  /**
   * Sends a callback whose answer the page does not wait for.
   *
   * @param callback - Name of the NUI callback
   * @param body - Payment it is about
   */
  private async notify(
    callback: 'shown' | 'close',
    body: ShownPayload | ClosePayload,
  ): Promise<void> {
    try {
      await postNui(callback, body);
    } catch (err: unknown) {
      console.error(`[esx_paymentgateway] ${callback} callback failed`, err);
    }
  }

  private clearTimers(): void {
    clearTimeout(this.answerTimer);
    clearTimeout(this.closeTimer);
  }
}

/** The page's payment controller. */
export const controller = new PaymentController();
