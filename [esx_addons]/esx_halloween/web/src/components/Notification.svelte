<script lang="ts">
  import type { NotificationSize, NotificationPosition } from '../types/nui';

  /**
   * Notification component props
   * @property {NotificationSize} size - Card size variant (small: 340x120, large: 620x165)
   * @property {NotificationPosition} position - Screen position
   * @property {string} header - Header/title text
   * @property {string} description - Description/body text
   * @property {boolean} [visible=true] - Visibility state for animations
   */
  interface Props {
    size: NotificationSize;
    position: NotificationPosition;
    header: string;
    description: string;
    visible?: boolean;
  }

  let {
    size,
    position,
    header,
    description,
    visible = true,
  }: Props = $props();
</script>

<div
  class="notification notification--{size} notification--{position}"
  class:notification--visible={visible}
>
  <img src="./assets/background.webp" alt="" class="notification__background" />
  <img src="./assets/pumpkin.webp" alt="" class="notification__pumpkin notification__pumpkin--{size}" />
  <div class="notification__content">
    <h3 class="notification__header">{header}</h3>
    <p class="notification__description">{description}</p>
  </div>
</div>

<style>
  .notification {
    position: relative;
    border-radius: var(--radius-lg);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.4);
    display: flex;
    flex-direction: column;
    opacity: 0;
    transition: all 400ms ease-out;
    overflow: hidden;
  }

  .notification--visible {
    opacity: 1;
  }

  /* Size variants - converted to REM (base 16px) */
  .notification--small {
    width: 21.25rem; /* 340px */
    min-height: 7.5rem; /* 120px */
    padding: var(--space-md);
  }

  .notification--large {
    width: 38.75rem; /* 620px */
    min-height: 10.3125rem; /* 165px */
    padding: var(--space-lg);
  }

  /* Slide IN animations (from side) */
  .notification--top-left {
    transform: translateX(-100%) scale(1);
  }

  .notification--top-left.notification--visible {
    transform: translateX(0) scale(1);
  }

  .notification--top-right {
    transform: translateX(100%) scale(1);
  }

  .notification--top-right.notification--visible {
    transform: translateX(0) scale(1);
  }

  .notification--top-center {
    transform: translateY(-100%) scale(1);
  }

  .notification--top-center.notification--visible {
    transform: translateY(0) scale(1);
  }

  .notification--bottom-center {
    transform: translateY(100%) scale(1);
  }

  .notification--bottom-center.notification--visible {
    transform: translateY(0) scale(1);
  }

  /* Background image layer */
  .notification__background {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    width: 120%;
    height: 120%;
    object-fit: cover;
    filter: brightness(0.7);
    z-index: 1;
  }

  /* Pumpkin overlay - positioned right, slightly center */
  .notification__pumpkin {
    position: absolute;
    right: 0;
    top: 50%;
    transform: translateY(-50%);
    z-index: 2;
    pointer-events: none;
    animation: pumpkinGlow 2s ease-in-out infinite;
  }

  .notification__pumpkin--small {
    height: 90%;
    width: auto;
    right: 0.5rem;
  }

  .notification__pumpkin--large {
    height: 85%;
    width: auto;
    right: 1rem;
  }

  @keyframes pumpkinGlow {
    0%, 100% {
      filter: brightness(1.1) saturate(1.2);
    }
    50% {
      filter: brightness(1.4) saturate(1.6);
    }
  }

  /* Content layout - positioned left with spacing from pumpkin */
  .notification__content {
    position: relative;
    z-index: 3;
    display: flex;
    flex-direction: column;
    gap: var(--space-sm);
    height: 100%;
    justify-content: center;
    max-width: 60%;
  }

  .notification__header {
    margin: 0;
    color: var(--color-brand);
    font-family: var(--font-family-halloween);
    font-size: 1.5rem;
    font-weight: var(--font-weight-normal);
    line-height: 1.2;
    letter-spacing: 0.02em;
  }

  .notification__description {
    margin: 0;
    color: var(--color-lightest);
    font-size: var(--font-size-body);
    font-weight: 300;
    line-height: 1.4;
  }

  /* Larger header + more horizontal space for large notifications */
  .notification--large .notification__header {
    font-size: 1.75rem;
  }

  .notification--large .notification__content {
    max-width: 70%;
  }

  /* Responsive scaling for smaller screens */
  @media (max-width: 768px) {
    .notification--small {
      width: 90vw;
      max-width: 21.25rem;
    }

    .notification--large {
      width: 95vw;
      max-width: 38.75rem;
    }

    .notification__content {
      max-width: 55%;
    }
  }
</style>
