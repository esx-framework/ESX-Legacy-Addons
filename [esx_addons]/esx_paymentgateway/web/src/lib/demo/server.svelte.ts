/**
 * The page plays both sides when it is opened in a normal browser: this stands in for the Lua
 * client and the server, opens sample payments, takes the money from demo balances and answers
 * the way the resource does. After a payment closes the next one opens, so the dialog always
 * shows. In game none of this runs.
 *
 * @see demo
 */

import { answerOffline, isInGame } from '../nui/bridge';
import { isId, isPaymentMethod, isRecord } from '../nui/validate';
import type { Balances } from '../payment/types';
import { BLUE_THEME, GERMAN_LABELS, SAMPLES } from './samples';

/** How long the stand-in server takes to answer, in milliseconds. */
const ANSWER_MS = 700;
/** Pause between one payment closing and the next opening, in milliseconds. */
const NEXT_MS = 900;
/** Balances the demo starts with and tops up to. */
const START_BALANCES: Balances = { cash: 4820, card: 412000 };

/** Stand-in for the Lua client and the server. */
class DemoServer {
  /** Whether the demo runs, that is whether the page is outside the game */
  active: boolean = $state(false);
  /** Whether payments use the blue sample theme instead of the ESX colors */
  blue: boolean = $state(false);
  /** Whether payments come with the German texts */
  german: boolean = $state(false);
  /** Index of the sample on screen */
  sample: number = $state(0);

  private balances: Balances = { ...START_BALANCES };
  private nextId = 1;
  private timer: ReturnType<typeof setTimeout> | undefined;

  /** Starts the demo when the page is not inside FiveM. */
  start(): void {
    if (isInGame() || this.active) return;
    this.active = true;
    answerOffline((callback: string, payload: unknown): void => this.answer(callback, payload));
    this.timer = setTimeout((): void => this.open(), 300);
  }

  /** Opens the next sample right away. */
  next(): void {
    this.sample = (this.sample + 1) % SAMPLES.length;
    this.open();
  }

  /** Reopens the current sample, e.g. after switching theme or language. */
  open(): void {
    clearTimeout(this.timer);
    const sample = SAMPLES[this.sample] ?? SAMPLES[0];
    if (!sample) return;
    if (this.balances.card < sample.amount) this.balances = { ...START_BALANCES };
    send({
      action: 'open',
      payment: {
        ...sample,
        id: this.nextId++,
        currency: '$',
        balances: { ...this.balances },
      },
      ...(this.blue ? { theme: BLUE_THEME } : {}),
      ...(this.german ? { labels: GERMAN_LABELS, locale: 'de' } : {}),
      volume: 0.5,
    });
  }

  private answer(callback: string, payload: unknown): void {
    if (callback === 'close') {
      this.sample = (this.sample + 1) % SAMPLES.length;
      this.timer = setTimeout((): void => this.open(), NEXT_MS);
      return;
    }
    if (callback !== 'pay' || !isRecord(payload)) return;
    const { id, method } = payload;
    if (!isId(id) || !isPaymentMethod(method)) return;
    const sample = SAMPLES[this.sample];
    this.timer = setTimeout((): void => {
      if (!sample || this.balances[method] < sample.amount) {
        const message = this.german ? 'Dafür reicht das Geld nicht.' : 'Not enough money for that.';
        send({ action: 'result', result: { id, ok: false, message, balances: this.balances } });
        return;
      }
      this.balances = { ...this.balances, [method]: this.balances[method] - sample.amount };
      send({ action: 'result', result: { id, ok: true, method, balances: { ...this.balances } } });
    }, ANSWER_MS);
  }
}

/** Posts a message the way SendNUIMessage does. */
function send(message: unknown): void {
  window.postMessage(message, '*');
}

/** The browser demo. */
export const demo = new DemoServer();
