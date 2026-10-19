/**
 * What a payment is on the page: the request the server opened and the answer it gave to a
 * chosen method. The server owns amount and balances; the page only shows them and sends back
 * the method the player picked.
 *
 * @see Payment
 * @see PaymentResult
 */

/** Ways to pay, in the order the dialog lists them. */
export const PAYMENT_METHODS = ['cash', 'card'] as const;

/** A way to pay: cash is the player's money, card their bank account. */
export type PaymentMethod = (typeof PAYMENT_METHODS)[number];

/** The player's money per method when the server last looked. */
export interface Balances {
  /** Cash on hand */
  cash: number;
  /** Bank account balance, paid by card */
  card: number;
}

/** A payment the server opened for this player. */
export interface Payment {
  /** Server id of the request; results and callbacks carry it so stale ones are ignored */
  id: number;
  /** Price in whole currency units */
  amount: number;
  /** Currency symbol shown before the amount */
  currency: string;
  /** What is being paid for, e.g. "Vehicle repair" */
  title: string;
  /** Who is paid or further detail, e.g. "Los Santos Customs" */
  description?: string;
  /** Methods the requesting script accepts, never empty */
  methods: PaymentMethod[];
  /** Balances at the time the dialog opened */
  balances: Balances;
  /** Whether the player has to hold the pay button, set by the server for large amounts */
  hold?: boolean;
}

/** The server's answer to a chosen method. */
export interface PaymentResult {
  /** Id of the payment this answers */
  id: number;
  /** Whether the money was taken */
  ok: boolean;
  /** Method that paid, set when {@link ok} is true */
  method?: PaymentMethod;
  /** Translated text for the player, from the resource's locale */
  message?: string;
  /** Balances after the attempt */
  balances?: Balances;
}
