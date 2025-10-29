import { useCallback } from 'react';
import { useNuiContext } from '@/providers/NuiProvider';
import { useNotifications } from '@/providers/NotificationProvider';
import { useLocale } from '@/providers/LocaleProvider';

/**
 * Hook providing access to NUI functionality with automatic error handling and notifications.
 *
 * @returns {Object} NUI utilities and state
 * @property {boolean} isVisible - Whether the NUI is currently visible
 * @property {boolean} hasFocus - Whether the NUI has input focus
 * @property {boolean} isInGame - Whether running in FiveM (vs browser)
 * @property {function(boolean): void} setVisible - Set NUI visibility
 * @property {function(boolean, boolean): void} setFocus - Set NUI focus state
 * @property {function} sendCallback - Send a callback to the game client with error handling
 * @property {function(): void} close - Close the NUI
 *
 * @example
 * ```typescript
 * const { sendCallback, close } = useNui();
 *
 * const handleRetrieve = async () => {
 *   const result = await sendCallback('garage:retrieveVehicle', { vehicleId: '1' }, {
 *     showSuccess: true,
 *     successMessage: 'Vehicle retrieved!'
 *   });
 * };
 * ```
 */
export const useNui = () => {
  const { isVisible, hasFocus, isInGame, setVisible, setFocus, sendCallback } = useNuiContext();
  const { showNotification } = useNotifications();
  const { t } = useLocale();

  /**
   * Send a callback to the game client with automatic error handling and notifications.
   *
   * @template T - Expected response type
   * @param {string} event - NUI callback event name
   * @param {unknown} data - Data to send to the callback
   * @param {Object} options - Configuration options
   * @param {boolean} options.showSuccess - Show success notification
   * @param {boolean} options.showError - Show error notification
   * @param {string} options.successMessage - Custom success message
   * @param {string} options.errorMessage - Custom error message
   * @returns {Promise<T|null>} Response data or null on error
   */
  const safeCallback = useCallback(
    async <T = unknown>(
      event: string,
      data?: unknown,
      options?: {
        showSuccess?: boolean;
        showError?: boolean;
        successMessage?: string;
        errorMessage?: string;
      }
    ): Promise<T | null> => {
      try {
        const result = await sendCallback<T>(event, data);

        if (options?.showSuccess) {
          showNotification(options.successMessage ?? t('notifications.success'), {
            type: 'success',
          });
        }

        return result;
      } catch (error) {
        if (options?.showError) {
          const message = error instanceof Error ? error.message : t('notifications.error');
          showNotification(options.errorMessage ?? message, { type: 'error' });
        }
        return null;
      }
    },
    [sendCallback, showNotification, t]
  );

  /**
   * Closes the NUI and removes focus.
   */
  const close = useCallback(() => {
    setVisible(false);
  }, [setVisible]);

  return {
    isVisible,
    hasFocus,
    isInGame,
    setVisible,
    setFocus,
    sendCallback: safeCallback,
    close,
  };
};
