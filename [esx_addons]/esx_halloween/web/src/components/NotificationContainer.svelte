<script lang="ts">
  import type { NotificationPosition } from '../types/nui';
  import Notification from './Notification.svelte';
  import { notificationManager } from '../stores/NotificationManager.svelte';

  /**
   * Get current notification from manager
   * Reactively updates when notification changes
   */
  const notification = $derived(notificationManager.currentNotification);

  /**
   * Visibility state for triggering slide-in animation
   */
  let isVisible = $state(false);

  /**
   * Trigger slide-in animation when new notification appears
   */
  $effect(() => {
    if (notification) {
      // Start hidden
      isVisible = false;
      // Double RAF ensures DOM is ready before animation
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          isVisible = true;
        });
      });
    } else {
      isVisible = false;
    }
  });

  /**
   * Determine container positioning class based on notification position
   * @param {NotificationPosition | undefined} position - Current notification position
   * @returns {NotificationPosition | ''} Position class or empty string
   */
  function getPositionClass(position: NotificationPosition | undefined): NotificationPosition | '' {
    if (!position) return '';
    return position;
  }
</script>

{#if notification}
  <div class="notification-container notification-container--{getPositionClass(notification.position)}">
    <Notification
      size={notification.size}
      position={notification.position}
      header={notification.header}
      description={notification.description}
      visible={isVisible}
    />
  </div>
{/if}

<style>
  .notification-container {
    position: fixed;
    z-index: var(--z-notification);
    pointer-events: none;
  }

  .notification-container > :global(*) {
    pointer-events: auto;
  }

  /* Top-left positioning */
  .notification-container--top-left {
    top: 8rem;
    left: var(--space-xl);
  }

  /* Top-right positioning */
  .notification-container--top-right {
    top: 8rem;
    right: var(--space-xl);
  }

  /* Top-center positioning */
  .notification-container--top-center {
    top: var(--space-xl);
    left: 50%;
    transform: translateX(-50%);
  }

  /* Bottom-center positioning */
  .notification-container--bottom-center {
    bottom: var(--space-xl);
    left: 50%;
    transform: translateX(-50%);
  }

  /* Responsive spacing adjustments */
  @media (max-width: 768px) {
    .notification-container--top-left,
    .notification-container--top-right,
    .notification-container--top-center,
    .notification-container--bottom-center {
      left: var(--space-md);
      right: var(--space-md);
    }

    .notification-container--top-center,
    .notification-container--bottom-center {
      left: 50%;
      right: auto;
    }
  }
</style>
