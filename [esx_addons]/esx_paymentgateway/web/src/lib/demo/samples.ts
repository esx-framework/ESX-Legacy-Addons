/**
 * What the browser demo shows: sample payments from around Los Santos, a second theme and the
 * German texts, so the dialog can be presented the way servers will run it.
 *
 * @see DemoServer
 */

import type { Labels, Theme } from '../nui/messages';
import type { PaymentMethod } from '../payment/types';

/** A payment the demo can open. */
export interface DemoPayment {
  /** What is paid for */
  title: string;
  /** Who is paid */
  description: string;
  /** Price */
  amount: number;
  /** Methods the shop accepts */
  methods: PaymentMethod[];
  /** Whether the amount is large enough to hold the pay button */
  hold?: boolean;
}

/** Payments the demo cycles through. */
export const SAMPLES: readonly DemoPayment[] = [
  {
    title: 'Vehicle repair',
    description: 'Los Santos Customs',
    amount: 1250,
    methods: ['cash', 'card'],
  },
  { title: 'Fuel', description: 'Globe Oil, Mirror Park', amount: 86, methods: ['cash', 'card'] },
  {
    title: 'Pegassi Zentorno',
    description: 'Premium Deluxe Motorsport',
    amount: 185000,
    methods: ['card'],
    hold: true,
  },
  { title: 'Burger Shot meal', description: 'Del Perro Pier', amount: 24, methods: ['cash'] },
  {
    title: 'Apartment rent',
    description: 'Dynasty 8 Real Estate',
    amount: 4200,
    methods: ['card'],
  },
];

/** A blue server theme, to show that the dialog follows the esx:ui convars. */
export const BLUE_THEME: Theme = {
  primaryColor: '#2F80ED',
  secondaryColor: '#1B2330',
  backgroundColor: '#0E141C',
  accentColor: '#2A3646',
};

/** The dialog in German, as the resource's de locale sends it. */
export const GERMAN_LABELS: Labels = {
  heading: 'Zahlung',
  choose: 'Bezahlen mit',
  total: 'Gesamt',
  cash: 'Bargeld',
  card: 'Karte',
  remaining: 'Danach {amount}',
  short: 'Es fehlen {amount}',
  pay_cash: '{amount} bar bezahlen',
  pay_card: '{amount} mit Karte bezahlen',
  hold_cash: 'Halten, um {amount} bar zu bezahlen',
  hold_card: 'Halten, um {amount} mit Karte zu bezahlen',
  unaffordable: 'Nicht genug Geld für diese Zahlung',
  unreachable: 'Die Zahlung ist nicht durchgegangen. Versuch es noch einmal.',
  processing: 'Wird bezahlt',
  cancel: 'Abbrechen',
  success: 'Zahlung erfolgreich',
  paid_with: 'Bezahlt mit',
  new_balance: 'Neues Guthaben',
  reference: 'Beleg',
  done: 'Fertig',
};
