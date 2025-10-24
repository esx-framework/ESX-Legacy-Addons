import type { NotificationData, QueuedNotification } from '../types/nui';

/**
 * Notification queue manager using Svelte 5 runes
 * Handles displaying notifications one at a time with auto-dismiss
 */
class NotificationManager {
  /**
   * Queue of pending notifications
   * @private
   */
  private queue = $state<QueuedNotification[]>([]);

  /**
   * Currently displayed notification (null if none)
   * @private
   */
  private current = $state<QueuedNotification | null>(null);

  /**
   * Timeout ID for current notification auto-dismiss
   * @private
   */
  private dismissTimeout: number | null = null;

  /**
   * Counter for generating unique notification IDs
   * @private
   */
  private idCounter = 0;

  /**
   * Get the currently displayed notification
   * @returns {QueuedNotification | null} Current notification or null
   */
  get currentNotification(): QueuedNotification | null {
    return this.current;
  }

  /**
   * Get the number of pending notifications in queue
   * @returns {number} Queue length
   */
  get queueLength(): number {
    return this.queue.length;
  }

  /**
   * Add a new notification to the queue
   * If no notification is currently showing, display it immediately
   * @param {NotificationData} data - Notification configuration
   * @returns {void}
   * @example
   * notificationManager.show({
   *   size: 'small',
   *   position: 'top-right',
   *   header: 'Success',
   *   description: 'Item purchased successfully',
   *   duration: 3000
   * });
   */
  show(data: NotificationData): void {
    const notification: QueuedNotification = {
      ...data,
      id: `notification-${++this.idCounter}`,
      duration: data.duration ?? 5000,
    };

    this.queue.push(notification);

    if (!this.current) {
      this.processQueue();
    }
  }

  /**
   * Process the next notification in queue
   * Sets up auto-dismiss timer based on notification duration
   * @private
   */
  private processQueue(): void {
    if (this.queue.length === 0) {
      this.current = null;
      return;
    }

    this.current = this.queue.shift()!;

    if (this.dismissTimeout) {
      clearTimeout(this.dismissTimeout);
    }

    this.dismissTimeout = window.setTimeout(() => {
      this.dismiss();
    }, this.current.duration);
  }

  /**
   * Dismiss the current notification and show next in queue
   * Clears any pending auto-dismiss timeout
   * @returns {void}
   */
  dismiss(): void {
    if (this.dismissTimeout) {
      clearTimeout(this.dismissTimeout);
      this.dismissTimeout = null;
    }

    this.current = null;

    setTimeout(() => {
      this.processQueue();
    }, 300);
  }

  /**
   * Clear all pending notifications and dismiss current
   * @returns {void}
   */
  clearAll(): void {
    this.queue = [];
    if (this.dismissTimeout) {
      clearTimeout(this.dismissTimeout);
      this.dismissTimeout = null;
    }
    this.current = null;
  }
}

/**
 * Global notification manager instance
 * @example
 * import { notificationManager } from './stores/NotificationManager.svelte';
 *
 * notificationManager.show({
 *   size: 'large',
 *   position: 'bottom-center',
 *   header: 'Achievement Unlocked',
 *   description: 'You found a rare Halloween item!',
 *   duration: 4000
 * });
 */
export const notificationManager = new NotificationManager();
