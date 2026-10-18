/**
 * Runs a payment between Lua and the dialog: takes the messages Lua sends, sends the player's
 * choices back and owns the timers around them (the shortest working time of the pay button,
 * the wait for the server's answer and the receipt's own close).
 *
 * @see controller
 */

import { postNui } from '../nui/bridge';
import type { NuiMessage } from '../nui/messages';
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
        flow.open(message);
        break;
      case 'result': {
        const { result } = message;
        clearTimeout(this.answerTimer);
        const wait = Math.max(0, this.payingSince + MIN_PAYING_MS - Date.now());
        this.answerTimer = setTimeout((): void => {
          if (!flow.answer(result) || flow.phase !== 'paid' || this.closeDelay === 0) return;
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
   * Chooses a method.
   *
   * @param method - Method the player picked
   */
  choose(method: PaymentMethod): void {
    flow.choose(method);
  }

  /** Pays with the chosen method and waits for the server's answer. */
  async pay(): Promise<void> {
    const body = flow.pay();
    if (!body) return;
    this.payingSince = Date.now();
    const giveUp = (): void => {
      flow.answer({ id: body.id, ok: false, message: flow.labels.unreachable });
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
    try {
      await postNui('close', body);
    } catch (err: unknown) {
      console.error('[esx_paymentgateway] close callback failed', err);
    }
  }

  private clearTimers(): void {
    clearTimeout(this.answerTimer);
    clearTimeout(this.closeTimer);
  }
}

/** The page's payment controller. */
export const controller = new PaymentController();
