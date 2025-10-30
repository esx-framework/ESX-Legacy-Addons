import { fetchNui } from './fetchNui';

/**
 * Visibility store using Svelte 5 runes
 * Manages UI visibility state and communicates with game client
 */
class VisibilityStore {
  private _visible = $state(false);

  /**
   * Get current visibility state
   * @returns {boolean}
   */
  get visible(): boolean {
    return this._visible;
  }

  /**
   * Show the UI
   * @returns {void}
   */
  show(): void {
    this._visible = true;
  }

  /**
   * Hide the UI and notify game client
   * @returns {Promise<void>}
   */
  async hide(): Promise<void> {
    this._visible = false;

    try {
      await fetchNui('hideUI');
    } catch (error) {
      console.error('[visibility] Error hiding UI:', error);
    }
  }

  /**
   * Toggle visibility
   * @returns {void}
   */
  toggle(): void {
    if (this._visible) {
      this.hide();
    } else {
      this.show();
    }
  }

  /**
   * Set visibility state directly
   * @param {boolean} value - Visibility state
   * @returns {void}
   */
  set(value: boolean): void {
    if (value) {
      this.show();
    } else {
      this.hide();
    }
  }
}

/**
 * Global visibility store instance
 * @example
 * import { visibility } from './utils/visibility';
 *
 * // In component
 * {#if visibility.visible}
 *   <div>UI Content</div>
 * {/if}
 *
 * // To hide
 * visibility.hide();
 */
export const visibility = new VisibilityStore();
