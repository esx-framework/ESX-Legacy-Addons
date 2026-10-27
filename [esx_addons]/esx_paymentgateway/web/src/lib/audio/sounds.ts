/**
 * Sounds of the dialog: short, muted thocks like a well damped key, kept quiet so they sit under
 * the game. They are Opus files rendered once ahead of time, decoded into memory on first use and
 * played through Web Audio, so a cue starts without delay. Sound is a nicety: if the page cannot
 * decode or play it, the dialog works the same in silence.
 *
 * @see sounds
 */

import cardUrl from '../../assets/sounds/card.ogg';
import cashUrl from '../../assets/sounds/cash.ogg';
import closeUrl from '../../assets/sounds/close.ogg';
import openUrl from '../../assets/sounds/open.ogg';
import pressUrl from '../../assets/sounds/press.ogg';
import refuseUrl from '../../assets/sounds/refuse.ogg';
import selectUrl from '../../assets/sounds/select.ogg';

/** Files of the cues. */
const FILES = {
  /** The dialog comes in */
  open: openUrl,
  /** A method is chosen */
  select: selectUrl,
  /** The pay button is pressed */
  press: pressUrl,
  /** A card payment went through: two quick thocks stepping up */
  card: cardUrl,
  /** A cash payment went through: a deep drawer thock, notes sliding in, two coin taps */
  cash: cashUrl,
  /** The server refused the payment: two dull thocks stepping down */
  refuse: refuseUrl,
  /** The player closes the dialog */
  close: closeUrl,
} as const;

/** Name of a cue. */
export type Cue = keyof typeof FILES;

/** Volume when Lua sends none. */
export const DEFAULT_VOLUME = 0.5;

/** Decoded cues and the output they play on. */
class SoundBoard {
  private context: AudioContext | null = null;
  private output: GainNode | null = null;
  private buffers = new Map<Cue, AudioBuffer>();
  private loading: Promise<void> | null = null;
  private volume = DEFAULT_VOLUME;

  /**
   * @param volume - Loudness from 0, silent, to 1
   */
  setVolume(volume: number): void {
    this.volume = Math.min(1, Math.max(0, volume));
    if (this.output) this.output.gain.value = this.volume;
  }

  /**
   * Decodes every cue once. Later calls wait for the same work.
   *
   * @returns Resolves when the cues are ready or failed to load
   */
  load(): Promise<void> {
    this.loading ??= this.decodeAll();
    return this.loading;
  }

  /**
   * Plays a cue. A cue that is not decoded yet is skipped rather than played late.
   *
   * @param cue - Cue to play
   */
  play(cue: Cue): void {
    void this.load();
    const buffer = this.buffers.get(cue);
    if (!this.context || !this.output || !buffer || this.volume === 0) return;
    if (this.context.state === 'suspended') void this.context.resume();
    const source = this.context.createBufferSource();
    source.buffer = buffer;
    source.connect(this.output);
    source.start();
  }

  private async decodeAll(): Promise<void> {
    if (typeof AudioContext !== 'function') return;
    const context = new AudioContext();
    const output = context.createGain();
    output.gain.value = this.volume;
    output.connect(context.destination);
    this.context = context;
    this.output = output;

    await Promise.all(
      (Object.entries(FILES) as [Cue, string][]).map(
        async ([cue, url]: [Cue, string]): Promise<void> => {
          try {
            const response = await fetch(url);
            const data = await response.arrayBuffer();
            this.buffers.set(cue, await context.decodeAudioData(data));
          } catch (err: unknown) {
            console.warn(`[esx_paymentgateway] sound ${cue} could not be loaded`, err);
          }
        },
      ),
    );
  }
}

/** The dialog's sounds. */
export const sounds = new SoundBoard();
