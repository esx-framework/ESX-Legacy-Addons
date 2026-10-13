/**
 * Tests for the seeded random number generator.
 */

import { describe, expect, it } from 'vitest';
import { Random, hashString } from './random';

function draw(random: Random, count: number): number[] {
  return Array.from({ length: count }, (): number => random.nextUint32());
}

describe('Random', () => {
  it('should produce the same sequence for the same seed', () => {
    expect(draw(new Random(42), 16)).toEqual(draw(new Random(42), 16));
  });

  it('should produce different sequences for neighbouring seeds', () => {
    expect(draw(new Random(42), 4)).not.toEqual(draw(new Random(43), 4));
  });

  it('should keep a stable sequence across versions', () => {
    // If this fails, every existing seed now generates a different round.
    expect(draw(new Random(1), 3)).toEqual([1828152527, 3394835397, 2967886022]);
  });

  it('should give forks with the same label the same stream', () => {
    const root = new Random(99);
    expect(draw(root.fork('cables'), 8)).toEqual(draw(new Random(99).fork('cables'), 8));
  });

  it('should keep fork streams independent of draws on the parent', () => {
    const untouched = new Random(7);
    const used = new Random(7);
    draw(used, 50);
    expect(draw(used.fork('faults'), 8)).toEqual(draw(untouched.fork('faults'), 8));
  });

  it('should give different labels different streams', () => {
    const root = new Random(5);
    expect(draw(root.fork('a'), 4)).not.toEqual(draw(root.fork('b'), 4));
  });

  it('should keep next() within [0, 1)', () => {
    const random = new Random(123);
    for (let i = 0; i < 10_000; i++) {
      const value = random.next();
      expect(value).toBeGreaterThanOrEqual(0);
      expect(value).toBeLessThan(1);
    }
  });

  it('should cover both ends of an inclusive integer range', () => {
    const random = new Random(321);
    const seen = new Set<number>();
    for (let i = 0; i < 2_000; i++) seen.add(random.int(1, 6));
    expect([...seen].sort()).toEqual([1, 2, 3, 4, 5, 6]);
  });

  it('should reject invalid integer ranges', () => {
    expect(() => new Random(1).int(5, 2)).toThrow(RangeError);
    expect(() => new Random(1).int(0.5, 2)).toThrow(RangeError);
  });

  it('should shuffle without losing or duplicating elements', () => {
    const items = [1, 2, 3, 4, 5, 6, 7, 8];
    const shuffled = new Random(8).shuffle(items);
    expect([...shuffled].sort()).toEqual(items);
    expect(items).toEqual([1, 2, 3, 4, 5, 6, 7, 8]);
  });

  it('should sample distinct elements', () => {
    const sample = new Random(9).sample(['a', 'b', 'c', 'd', 'e'], 3);
    expect(new Set(sample).size).toBe(3);
  });

  it('should honour weights roughly', () => {
    const random = new Random(10);
    let heavy = 0;
    for (let i = 0; i < 10_000; i++) {
      if (
        random.weighted([
          { value: 'heavy', weight: 9 },
          { value: 'light', weight: 1 },
        ]) === 'heavy'
      ) {
        heavy += 1;
      }
    }
    expect(heavy / 10_000).toBeGreaterThan(0.87);
    expect(heavy / 10_000).toBeLessThan(0.93);
  });

  it('should throw when picking from an empty list', () => {
    expect(() => new Random(1).pick([])).toThrow(RangeError);
  });
});

describe('hashString', () => {
  it('should match the FNV-1a reference values', () => {
    expect(hashString('')).toBe(0x811c9dc5);
    expect(hashString('a')).toBe(0xe40c292c);
    expect(hashString('foobar')).toBe(0xbf9cf968);
  });
});
