/**
 * Deterministic pseudo random numbers for puzzle generation.
 *
 * sfc32, seeded through splitmix32. Generators should not share one stream: {@link Random.fork}
 * derives an independent stream from a label, so adding a draw to one part of a generator
 * does not shift the numbers every later part sees. Rounds stay reproducible across versions
 * as long as each part keeps its label.
 *
 * Not suitable for anything security related.
 */

const UINT32 = 0x1_0000_0000;

function splitmix32(state: number): () => number {
  let s = state >>> 0;
  return (): number => {
    s = (s + 0x9e3779b9) >>> 0;
    let z = s;
    z = Math.imul(z ^ (z >>> 16), 0x85ebca6b);
    z = Math.imul(z ^ (z >>> 13), 0xc2b2ae35);
    return (z ^ (z >>> 16)) >>> 0;
  };
}

/**
 * 32-bit FNV-1a hash, used to turn fork labels into seeds.
 *
 * @param text - Input string
 * @returns Unsigned 32-bit hash
 */
export function hashString(text: string): number {
  let hash = 0x811c9dc5;
  for (let i = 0; i < text.length; i++) {
    hash = Math.imul(hash ^ text.charCodeAt(i), 0x01000193);
  }
  return hash >>> 0;
}

/** Entry for {@link Random.weighted}. */
export interface Weighted<T> {
  /** Candidate value */
  value: T;
  /** Relative weight, must be positive */
  weight: number;
}

/** Seeded random number generator with the helpers puzzle generators need. */
export class Random {
  private a: number;
  private b: number;
  private c: number;
  private d: number;

  /**
   * @param seed - Unsigned 32-bit seed; other numbers are truncated to 32 bits
   */
  constructor(readonly seed: number) {
    const init = splitmix32(seed);
    this.a = init();
    this.b = init();
    this.c = init();
    this.d = init();
    // Warm up so that seeds differing in few bits diverge immediately.
    for (let i = 0; i < 12; i++) this.nextUint32();
  }

  /**
   * Derives an independent generator for one part of a puzzle.
   *
   * @param label - Stable name of the part, e.g. "cables" or "faults"
   * @returns New generator; forking the same seed with the same label always matches
   */
  fork(label: string): Random {
    return new Random((this.seed ^ hashString(label)) >>> 0);
  }

  /**
   * @returns Next unsigned 32-bit integer
   */
  nextUint32(): number {
    const t = (((this.a + this.b) >>> 0) + this.d) >>> 0;
    this.d = (this.d + 1) >>> 0;
    this.a = this.b ^ (this.b >>> 9);
    this.b = (this.c + (this.c << 3)) >>> 0;
    this.c = ((this.c << 21) | (this.c >>> 11)) >>> 0;
    this.c = (this.c + t) >>> 0;
    return t;
  }

  /**
   * @returns Float in [0, 1)
   */
  next(): number {
    return this.nextUint32() / UINT32;
  }

  /**
   * @param min - Lower bound, inclusive
   * @param max - Upper bound, exclusive
   * @returns Float in [min, max)
   */
  float(min: number, max: number): number {
    return min + (max - min) * this.next();
  }

  /**
   * @param min - Lower bound, inclusive integer
   * @param max - Upper bound, inclusive integer
   * @returns Integer in [min, max]
   * @throws {RangeError} When the bounds are not integers or max < min
   */
  int(min: number, max: number): number {
    if (!Number.isInteger(min) || !Number.isInteger(max) || max < min) {
      throw new RangeError(`invalid integer range [${min}, ${max}]`);
    }
    return min + Math.floor(this.next() * (max - min + 1));
  }

  /**
   * @param probability - Chance of returning true, between 0 and 1
   * @returns True with the given probability
   */
  chance(probability: number): boolean {
    return this.next() < probability;
  }

  /**
   * @param items - Non-empty list
   * @returns One element, uniformly chosen
   * @throws {RangeError} When the list is empty
   */
  pick<T>(items: readonly T[]): T {
    if (items.length === 0) throw new RangeError('cannot pick from an empty list');
    return items[Math.floor(this.next() * items.length)] as T;
  }

  /**
   * @param entries - Non-empty list of weighted values
   * @returns One value, chosen proportionally to its weight
   * @throws {RangeError} When the list is empty or a weight is not positive
   */
  weighted<T>(entries: readonly Weighted<T>[]): T {
    let total = 0;
    for (const entry of entries) {
      if (!(entry.weight > 0)) throw new RangeError('weights must be positive');
      total += entry.weight;
    }
    if (entries.length === 0) throw new RangeError('cannot pick from an empty list');

    let roll = this.next() * total;
    for (const entry of entries) {
      roll -= entry.weight;
      if (roll < 0) return entry.value;
    }
    return (entries[entries.length - 1] as Weighted<T>).value;
  }

  /**
   * @param items - Source list, left untouched
   * @returns Shuffled copy (Fisher-Yates)
   */
  shuffle<T>(items: readonly T[]): T[] {
    const result = items.slice();
    for (let i = result.length - 1; i > 0; i--) {
      const j = Math.floor(this.next() * (i + 1));
      const swap = result[i] as T;
      result[i] = result[j] as T;
      result[j] = swap;
    }
    return result;
  }

  /**
   * @param items - Source list
   * @param count - Number of distinct elements to draw
   * @returns `count` distinct elements in random order
   * @throws {RangeError} When count exceeds the list length
   */
  sample<T>(items: readonly T[], count: number): T[] {
    if (count > items.length) throw new RangeError(`cannot sample ${count} of ${items.length}`);
    return this.shuffle(items).slice(0, count);
  }
}
