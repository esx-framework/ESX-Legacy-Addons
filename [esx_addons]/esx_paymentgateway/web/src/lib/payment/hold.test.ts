/**
 * Tests for hold to confirm.
 *
 * @see HoldGesture
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { HOLD_MS, HoldGesture } from './hold.svelte';

describe('HoldGesture', (): void => {
  beforeEach((): void => {
    vi.useFakeTimers();
    vi.stubGlobal('requestAnimationFrame', (callback: FrameRequestCallback): number =>
      Number(setTimeout((): void => callback(performance.now()), 16)),
    );
    vi.stubGlobal('cancelAnimationFrame', (handle: number): void => clearTimeout(handle));
  });

  afterEach((): void => {
    vi.useRealTimers();
    vi.unstubAllGlobals();
  });

  it('should confirm once the hold lasted long enough', (): void => {
    const gesture = new HoldGesture();
    const confirmed = vi.fn();
    gesture.start(confirmed);
    vi.advanceTimersByTime(HOLD_MS + 50);
    expect(confirmed).toHaveBeenCalledOnce();
    expect(gesture.holding).toBe(false);
  });

  it('should start over when the player lets go early', (): void => {
    const gesture = new HoldGesture();
    const confirmed = vi.fn();
    gesture.start(confirmed);
    vi.advanceTimersByTime(HOLD_MS / 2);
    expect(gesture.progress).toBeGreaterThan(0.3);
    gesture.cancel();
    vi.advanceTimersByTime(HOLD_MS);
    expect(confirmed).not.toHaveBeenCalled();
    expect(gesture.progress).toBe(0);
  });

  it('should ignore a second start while holding, as key repeat sends', (): void => {
    const gesture = new HoldGesture();
    const confirmed = vi.fn();
    gesture.start(confirmed);
    vi.advanceTimersByTime(HOLD_MS / 2);
    gesture.start(confirmed);
    vi.advanceTimersByTime(HOLD_MS / 2 + 50);
    expect(confirmed).toHaveBeenCalledOnce();
  });
});
