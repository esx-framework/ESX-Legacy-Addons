/**
 * Hold to confirm. Large payments are not paid by a click: the player holds the pay button,
 * Enter or Space until the button has filled, and letting go early starts over. Everyday
 * payments stay one click, so the hold only guards the ones that would hurt to mistake.
 *
 * @see HoldGesture
 */

/** How long the player holds to confirm, in milliseconds. */
export const HOLD_MS = 900;

/** One hold-to-confirm gesture, driven by the button and the keyboard alike. */
export class HoldGesture {
  /** How far the hold is, 0 to 1 */
  progress: number = $state(0);
  /** Whether the player is holding right now */
  holding: boolean = $state(false);

  private startedAt = 0;
  private frame = 0;
  private done: (() => void) | null = null;

  /**
   * Starts holding. A start while already holding is ignored, so key repeat does no harm.
   *
   * @param oncomplete - Called once the hold has lasted {@link HOLD_MS}
   */
  start(oncomplete: () => void): void {
    if (this.holding) return;
    this.holding = true;
    this.done = oncomplete;
    this.startedAt = performance.now();
    this.frame = requestAnimationFrame(this.tick);
  }

  /** Lets go before the hold completed; the progress drops back to zero. */
  cancel(): void {
    cancelAnimationFrame(this.frame);
    this.holding = false;
    this.progress = 0;
    this.done = null;
  }

  private tick = (now: number): void => {
    this.progress = Math.min(1, (now - this.startedAt) / HOLD_MS);
    if (this.progress < 1) {
      this.frame = requestAnimationFrame(this.tick);
      return;
    }
    const done = this.done;
    this.holding = false;
    this.done = null;
    done?.();
  };
}

/** The pay button's hold, shared by the button and the keyboard. */
export const hold = new HoldGesture();
