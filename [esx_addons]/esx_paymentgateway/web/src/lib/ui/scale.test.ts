/**
 * Tests for sizing the dialog by screen height.
 *
 * @see zoomFor
 */

import { describe, expect, it } from 'vitest';
import { zoomFor } from './scale.svelte';

describe('zoomFor', (): void => {
  it.each([
    [1080, 1],
    [1440, 4 / 3],
    [2160, 2],
    [720, 0.8],
    [4320, 2],
  ])('should zoom a %ipx high screen by %f', (height: number, zoom: number): void => {
    expect(zoomFor(height)).toBeCloseTo(zoom);
  });
});
