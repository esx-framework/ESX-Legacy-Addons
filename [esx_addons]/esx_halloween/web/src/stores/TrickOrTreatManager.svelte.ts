/**
 * Trick-or-Treat State Manager
 * Manages all UI state for the trick-or-treating feature
 * Provides reactive state and methods for component communication
 */

/**
 * Trick-or-Treat UI state
 */
interface TrickOrTreatUIState {
  // HUD State
  hudVisible: boolean;
  currentHouses: number;
  totalHouses: number;
  timeRemaining: number;

  // Reward Popup State
  rewardVisible: boolean;
  rewardType: 'treat' | 'trick';
  rewardItem: string;
  rewardAmount: number;
}

/**
 * Trick-or-Treat State Manager Class
 * Reactive state container using Svelte 5 runes ($state, $effect)
 */
class TrickOrTreatManager {
  /**
   * Reactive state object
   * Contains all UI-related state for trick-or-treating
   */
  state = $state<TrickOrTreatUIState>({
    hudVisible: false,
    currentHouses: 0,
    totalHouses: 0,
    timeRemaining: 0,
    rewardVisible: false,
    rewardType: 'treat',
    rewardItem: '',
    rewardAmount: 0,
  });

  /**
   * Start a new trick-or-treat round
   * Initializes HUD with round data
   *
   * @param total - Total houses available in this round
   * @param duration - Round duration in milliseconds
   */
  startRound(total: number, duration: number): void {
    this.state.hudVisible = true;
    this.state.currentHouses = 0;
    this.state.totalHouses = total;
    this.state.timeRemaining = duration;
  }

  /**
   * Update round progress
   * Called when player collects from a house or when timer ticks
   *
   * @param current - Current houses collected
   * @param remaining - Time remaining in milliseconds
   */
  updateProgress(current: number, remaining: number): void {
    this.state.currentHouses = current;
    this.state.timeRemaining = remaining;
  }

  /**
   * End the current trick-or-treat round
   * Hides HUD and resets state
   */
  endRound(): void {
    this.state.hudVisible = false;
    this.state.currentHouses = 0;
    this.state.totalHouses = 0;
    this.state.timeRemaining = 0;
  }

  /**
   * Show reward popup for collected candy
   * Triggers animation and auto-dismiss
   *
   * @param type - Type of reward ('treat' or 'trick')
   * @param item - Item name collected
   * @param amount - Amount of item collected
   */
  showReward(type: 'treat' | 'trick', item: string, amount: number): void {
    this.state.rewardType = type;
    this.state.rewardItem = item;
    this.state.rewardAmount = amount;
    this.state.rewardVisible = true;
  }

  /**
   * Hide reward popup
   * Called after reward animation completes
   */
  hideReward(): void {
    this.state.rewardVisible = false;
  }

  /**
   * Hide HUD (used if round ends unexpectedly)
   */
  hideHUD(): void {
    this.state.hudVisible = false;
  }
}

/**
 * Singleton instance of Trick-or-Treat Manager
 * Exported for use throughout the application
 */
export const trickOrTreatManager = new TrickOrTreatManager();
