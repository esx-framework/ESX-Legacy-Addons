<script lang="ts">
  /**
   * Trick-or-Treat Reward Popup
   * Shows when player collects candy from a house
   * Displays treat or trick effect with smooth animation
   * Now uses notification-style design with background image and pumpkin overlay
   */
  import { onMount } from 'svelte';
  import { Candy, Ghost } from 'lucide-svelte';
  import backgroundImage from '../assets/background.webp';
  import pumpkinImage from '../assets/pumpkin.webp';

  interface Props {
    /** Whether reward popup is currently visible */
    visible?: boolean;
    /** Type of reward: 'treat' or 'trick' */
    rewardType?: 'treat' | 'trick';
    /** Item name (e.g., 'halloween_candy') */
    item?: string;
    /** Amount of item received */
    amount?: number;
  }

  let {
    visible = $bindable(false),
    rewardType = $bindable('treat'),
    item = $bindable(''),
    amount = $bindable(0),
  }: Props = $props();

  // Auto-dismiss after delay
  $effect(() => {
    if (visible) {
      const timeout = setTimeout(() => {
        visible = false;
      }, 2500);

      return () => clearTimeout(timeout);
    }
  });

  // Determine styling based on reward type
  const isPositive = $derived(rewardType === 'treat');
  const rewardTitle = $derived(isPositive ? 'TREAT!' : 'TRICK!');
  const rewardMessage = $derived(
    isPositive ? `You received ${amount}x ${item}` : 'You\'ve been spooked!'
  );

  // Create candy particles for positive reward
  let particles: Array<{ id: number; left: number; delay: number }> = $state([]);

  $effect(() => {
    if (visible && isPositive) {
      particles = Array.from({ length: 12 }, (_, i) => ({
        id: i,
        left: Math.random() * 100,
        delay: Math.random() * 0.3,
      }));
    }
  });
</script>

{#if visible}
  <div class="reward-popup" class:trick={!isPositive}>
    <!-- Background glow effect -->
    <div class="glow-effect"></div>

    <!-- Main reward card -->
    <div class="reward-card" class:trick={!isPositive}>
      <!-- Background image layer (z-index: 1) -->
      <img src={backgroundImage} alt="" class="reward-card__background" />

      <!-- Pumpkin overlay (z-index: 2) -->
      <img src={pumpkinImage} alt="" class="reward-card__pumpkin" />

      <!-- Content layer (z-index: 3) -->
      <div class="reward-card__content">
        <!-- Title with icon -->
        <div class="reward-title-container">
          {#if isPositive}
            <Candy class="reward-title-icon" size={40} strokeWidth={2} />
          {:else}
            <Ghost class="reward-title-icon" size={40} strokeWidth={2} />
          {/if}
          <div class="reward-title">{rewardTitle}</div>
        </div>

        <!-- Reward message -->
        <div class="reward-message">{rewardMessage}</div>

        <!-- Item display for treats -->
        {#if isPositive}
          <div class="item-display">
            <Candy class="item-icon" size={64} strokeWidth={1.5} />
            <div class="item-amount">+{amount}</div>
          </div>
        {/if}
      </div>
    </div>

    <!-- Candy falling particles (only for treats) -->
    {#if isPositive}
      {#each particles as particle (particle.id)}
        <div class="candy-particle" style="left: {particle.left}%; animation-delay: {particle.delay}s;">
          <Candy size={24} strokeWidth={2} />
        </div>
      {/each}
    {/if}
  </div>
{/if}

<style>
  .reward-popup {
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: var(--z-modal);
    pointer-events: none;
  }

  .reward-popup.trick {
    background: radial-gradient(circle, rgba(var(--color-danger-rgb), 0.2) 0%, transparent 70%);
  }

  .glow-effect {
    position: absolute;
    width: 25rem;
    height: 25rem;
    border-radius: 50%;
    background: radial-gradient(circle, rgba(var(--color-brand-rgb), 0.3) 0%, transparent 70%);
    animation: glowPulse 2s ease-in-out infinite;
    filter: blur(40px);
  }

  .reward-popup.trick .glow-effect {
    background: radial-gradient(circle, rgba(var(--color-danger-rgb), 0.4) 0%, transparent 70%);
  }

  .reward-card {
    position: relative;
    border-radius: var(--radius-xl);
    padding: var(--space-3xl);
    z-index: calc(var(--z-modal) + 1);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.4);
    min-width: 28.125rem;
    overflow: hidden;
    animation: slideInFromTop 400ms ease-out;
  }

  .reward-card.trick {
    animation: slideInFromTop 400ms ease-out, shake 0.5s ease 0.4s;
  }

  /* Background image layer (z-index: 1) */
  .reward-card__background {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    width: 120%;
    height: 120%;
    object-fit: cover;
    filter: brightness(0.7);
    z-index: 1;
    pointer-events: none;
  }

  /* Pumpkin overlay (z-index: 2) */
  .reward-card__pumpkin {
    position: absolute;
    right: 0;
    top: 50%;
    transform: translateY(-50%);
    height: 90%;
    z-index: 2;
    pointer-events: none;
    animation: pumpkinGlow 2s ease-in-out infinite;
  }

  /* Content layer (z-index: 3) */
  .reward-card__content {
    position: relative;
    z-index: 3;
    max-width: 65%;
  }

  .reward-title-container {
    display: flex;
    align-items: center;
    gap: var(--space-md);
    margin-bottom: var(--space-lg);
  }

  :global(.reward-title-icon) {
    color: var(--color-brand);
  }

  .reward-card.trick :global(.reward-title-icon) {
    color: var(--color-danger);
  }

  .reward-title {
    color: var(--color-brand);
    font-size: var(--font-size-h1);
    font-family: var(--font-family-halloween);
    font-weight: var(--font-weight-bold);
    letter-spacing: 0.125rem;
    text-shadow: 0 2px 8px rgba(0, 0, 0, 0.6);
  }

  .reward-card.trick .reward-title {
    color: var(--color-danger);
  }

  .reward-message {
    color: var(--color-lightest);
    font-size: var(--font-size-h4);
    margin-bottom: var(--space-lg);
    font-weight: 300;
    text-shadow: 0 2px 4px rgba(0, 0, 0, 0.6);
  }

  .item-display {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: var(--space-md);
    margin-top: var(--space-lg);
  }

  :global(.item-icon) {
    color: var(--color-brand);
    animation: bounce 0.6s cubic-bezier(0.34, 1.56, 0.64, 1);
  }

  .item-amount {
    color: var(--color-brand);
    font-size: var(--font-size-h2);
    font-weight: var(--font-weight-bold);
    text-shadow: 0 2px 8px rgba(0, 0, 0, 0.6);
    animation: slideUp 0.5s ease 0.2s both;
  }

  .candy-particle {
    position: fixed;
    animation: candyFall 2s ease-in forwards;
    top: -1.25rem;
    z-index: calc(var(--z-modal) - 1);
    pointer-events: none;
  }

  .candy-particle :global(svg) {
    color: var(--color-brand);
  }

  @keyframes slideInFromTop {
    from {
      opacity: 0;
      transform: translateY(-100%);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  @keyframes shake {
    0%, 100% {
      transform: translate(0, 0) rotate(0deg);
    }
    10% {
      transform: translate(-0.3125rem, -0.3125rem) rotate(-1deg);
    }
    20% {
      transform: translate(0.3125rem, 0.3125rem) rotate(1deg);
    }
    30% {
      transform: translate(-0.3125rem, 0.3125rem) rotate(-1deg);
    }
    40% {
      transform: translate(0.3125rem, -0.3125rem) rotate(1deg);
    }
    50% {
      transform: translate(-0.3125rem, -0.3125rem) rotate(-1deg);
    }
  }

  @keyframes pumpkinGlow {
    0%, 100% {
      filter: brightness(1.1) saturate(1.2);
    }
    50% {
      filter: brightness(1.4) saturate(1.6);
    }
  }

  @keyframes bounce {
    0%, 100% {
      transform: translateY(0);
    }
    50% {
      transform: translateY(-1.25rem);
    }
  }

  @keyframes slideUp {
    from {
      opacity: 0;
      transform: translateY(1.25rem);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  @keyframes candyFall {
    0% {
      opacity: 1;
      transform: translateY(0) rotate(0deg);
    }
    90% {
      opacity: 1;
    }
    100% {
      opacity: 0;
      transform: translateY(100vh) rotate(720deg);
    }
  }

  @keyframes glowPulse {
    0%, 100% {
      transform: scale(1);
      opacity: 0.6;
    }
    50% {
      transform: scale(1.2);
      opacity: 0.9;
    }
  }
</style>
