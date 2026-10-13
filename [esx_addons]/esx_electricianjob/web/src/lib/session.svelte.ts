/**
 * The round that is currently on screen, shared by the root component and the games.
 *
 * @see session
 */

import { postNui } from './nui/bridge';
import type { FinishPayload, GameOutcome, GameSession } from './nui/messages';

class SessionState {
  /** Running round, null while the UI is hidden */
  current = $state<GameSession | null>(null);

  private startedAt = 0;

  /**
   * Shows a new round, replacing whatever was running.
   *
   * @param next - Round handed out by the server
   */
  open(next: GameSession): void {
    this.current = next;
    this.startedAt = performance.now();
  }

  /** Hides the UI without reporting a result. */
  close(): void {
    this.current = null;
  }

  /**
   * Reports the result of the running round to Lua and hides the UI.
   *
   * @param outcome - How the round ended
   * @param actions - Player actions for server-side verification
   */
  async finish<TAction>(outcome: GameOutcome, actions: readonly TAction[] = []): Promise<void> {
    const round: GameSession | null = this.current;
    if (!round) return;

    this.current = null;
    const payload: FinishPayload<TAction> = {
      sessionId: round.id,
      outcome,
      durationMs: Math.round(performance.now() - this.startedAt),
      actions,
    };
    await postNui('finish', payload);
  }
}

/** Singleton session state; the NUI page only ever runs one round at a time. */
export const session = new SessionState();
