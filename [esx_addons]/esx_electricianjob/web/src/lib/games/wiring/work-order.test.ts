/**
 * Tests for the generated work order details.
 */

import { describe, expect, it } from 'vitest';
import type { WiringTemplate } from './model';
import { workOrder } from './work-order';

const TEMPLATES: readonly WiringTemplate[] = [
  'splice-through',
  'switched-light',
  'switched-light-feed-through',
];

describe('workOrder', () => {
  it('should return the same order for the same seed', () => {
    expect(workOrder(1056, 'switched-light')).toEqual(workOrder(1056, 'switched-light'));
  });

  it('should print the seed as an eight digit order number', () => {
    expect(workOrder(0x2c4f81a3, 'splice-through').number).toBe('2C4F81A3');
    expect(workOrder(42, 'splice-through').number).toBe('0000002A');
  });

  it('should vary customers and addresses across seeds', () => {
    const customers = new Set<string>();
    const addresses = new Set<string>();
    for (let seed = 0; seed < 200; seed++) {
      const order = workOrder(seed, 'splice-through');
      customers.add(order.customer);
      addresses.add(order.address);
    }
    expect(customers.size).toBeGreaterThan(100);
    expect(addresses.size).toBeGreaterThan(150);
  });

  it('should fill in every field for every scenario', () => {
    for (const template of TEMPLATES) {
      for (let seed = 0; seed < 100; seed++) {
        const order = workOrder(seed, template);
        for (const value of Object.values(order)) {
          expect(value).not.toBe('');
          expect(value).not.toMatch(/undefined|\$\{/);
        }
        expect(order.complaint).toMatch(/^[A-Z].*\.$/);
      }
    }
  });

  it('should talk about the light only when the job has one', () => {
    for (let seed = 0; seed < 100; seed++) {
      expect(workOrder(seed, 'splice-through').complaint).not.toMatch(/light/);
      expect(workOrder(seed, 'switched-light').complaint).toMatch(/light/);
    }
  });
});
