/**
 * Customer side of a junction box job: who called, where the box is and what they reported.
 *
 * Generated from the round seed, so a round always shows the same work order. The details
 * are flavor only; nothing in the puzzle depends on them.
 *
 * @see workOrder
 */

import { Random } from '../../core/random';
import type { WiringTemplate } from './model';
import { BOX_PLACES, ORDER_SCENARIOS } from './strings';

/** What the work order card shows about the customer and the site. */
export interface WorkOrder {
  /** Order number, the seed as eight hex digits */
  number: string;
  /** Customer name, initial and surname */
  customer: string;
  /** Street address of the site */
  address: string;
  /** Where in the building the box is */
  location: string;
  /** What the customer reported, in their words */
  complaint: string;
}

const INITIALS = 'ABCDEFGHJKLMNPRSTW';

const SURNAMES: readonly string[] = [
  'Alvarez',
  'Baptiste',
  'Brennan',
  'Castillo',
  'Delgado',
  'Fischer',
  'Haddad',
  'Harper',
  'Kowalski',
  'Lindqvist',
  'Mendoza',
  'Moreau',
  'Novak',
  'Nguyen',
  'Okafor',
  "O'Neill",
  'Patel',
  'Petrov',
  'Reyes',
  'Romero',
  'Sullivan',
  'Tanaka',
  'Whitaker',
  'Yilmaz',
];

/** Residential streets of Los Santos. */
const STREETS: readonly string[] = [
  'Mirror Park Blvd',
  'Grove Street',
  'Forum Drive',
  'Alta Street',
  'Hawick Ave',
  'Eclipse Blvd',
  'Strawberry Ave',
  'Davis Ave',
  'Carson Ave',
  'Bay City Ave',
  'Magellan Ave',
  'Palomino Ave',
  'Nikola Ave',
  'Didion Drive',
  'Jamestown Street',
  'Brouge Ave',
  'Covenant Ave',
  'Spanish Ave',
  'Fudge Lane',
  'West Mirror Drive',
];

/**
 * Work order for a round.
 *
 * @param seed - Round seed
 * @param template - Scenario of the round, decides what the customer complains about
 * @returns Work order details; the same seed and template always give the same order
 */
export function workOrder(seed: number, template: WiringTemplate): WorkOrder {
  const random = new Random(seed).fork('work-order');
  const scenario = ORDER_SCENARIOS[template];
  const room = random.pick(scenario.rooms);
  return {
    number: seed.toString(16).toUpperCase().padStart(8, '0'),
    customer: `${random.pick([...INITIALS])}. ${random.pick(SURNAMES)}`,
    address: `${random.int(100, 2999)} ${random.pick(STREETS)}`,
    location: scenario.location(room, random.pick(BOX_PLACES)),
    complaint: random.pick(scenario.complaints)(room),
  };
}
