<script lang="ts">
  /**
   * Particle Effect Component
   * Generic particle system for visual effects
   * Used for candy rain, blood splatters, zone pulses, etc.
   */

  interface Particle {
    id: number;
    x: number; // X position (% or px)
    y: number; // Y position (% or px)
    vx: number; // X velocity
    vy: number; // Y velocity
    scale: number; // Size scale (0-1)
    opacity: number; // Opacity (0-1)
    rotation: number; // Rotation angle (degrees)
    lifetime: number; // Time since spawn (ms)
    maxLifetime: number; // Total lifetime (ms)
    type: 'candy' | 'blood' | 'spark';
  }

  let particles: Particle[] = $state([]);
  let particleIdCounter = 0;

  // Configuration
  const PARTICLE_CONFIG = {
    candy: {
      count: 12,
      speed: 2, // pixels per frame
      scale: 0.8,
      lifetime: 2000, // ms
      color: '#ff9500',
      emoji: '🍬',
    },
    blood: {
      count: 8,
      speed: 3,
      scale: 0.6,
      lifetime: 1500,
      color: '#8b0000',
      emoji: '●',
    },
    spark: {
      count: 6,
      speed: 4,
      scale: 0.4,
      lifetime: 1000,
      color: '#ffff00',
      emoji: '✨',
    },
  };

  /**
   * Spawn particles at a given position
   *
   * @param type - Particle type (candy, blood, spark)
   * @param x - X position (center)
   * @param y - Y position (center)
   */
  export function spawn(
    type: 'candy' | 'blood' | 'spark' = 'candy',
    x: number = 50,
    y: number = 50
  ): void {
    const config = PARTICLE_CONFIG[type];

    for (let i = 0; i < config.count; i++) {
      // Randomize angle for spreading effect
      const angle = (Math.random() * Math.PI * 2);
      const speed = config.speed + Math.random() * 1;

      const particle: Particle = {
        id: particleIdCounter++,
        x: x,
        y: y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed - 2, // Slight upward bias
        scale: config.scale + Math.random() * 0.2,
        opacity: 1,
        rotation: Math.random() * 360,
        lifetime: 0,
        maxLifetime: config.lifetime,
        type: type,
      };

      particles.push(particle);
    }
  }

  /**
   * Animation loop - update particles each frame
   */
  function updateParticles(): void {
    particles = particles.filter((p) => {
      p.lifetime += 16; // ~60fps
      p.x += p.vx;
      p.y += p.vy;
      p.vy += 0.1; // Gravity
      p.opacity = Math.max(0, 1 - p.lifetime / p.maxLifetime);
      p.rotation += 5;

      return p.lifetime < p.maxLifetime;
    });

    if (particles.length > 0) {
      requestAnimationFrame(updateParticles);
    }
  }

  /**
   * Trigger particle spawn (exposed for parent component)
   */
  export function triggerSpawn(
    type: 'candy' | 'blood' | 'spark' = 'candy',
    x?: number,
    y?: number
  ): void {
    spawn(type, x, y);
    updateParticles();
  }

  /**
   * Clear all particles (cleanup)
   */
  export function clear(): void {
    particles = [];
  }
</script>

<!-- Particle container -->
<div class="particle-container">
  {#each particles as particle (particle.id)}
    <div
      class="particle particle-{particle.type}"
      style="
        left: {particle.x}%;
        top: {particle.y}%;
        opacity: {particle.opacity};
        transform: scale({particle.scale}) rotateZ({particle.rotation}deg);
      "
    >
      {#if particle.type === 'candy'}
        <span class="candy-particle">🍬</span>
      {:else if particle.type === 'blood'}
        <span class="blood-particle">●</span>
      {:else if particle.type === 'spark'}
        <span class="spark-particle">✨</span>
      {/if}
    </div>
  {/each}
</div>

<style>
  .particle-container {
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    pointer-events: none;
    z-index: 200;
    overflow: hidden;
  }

  .particle {
    position: absolute;
    font-size: calc(24px * var(--hud-font-scale));
    display: flex;
    align-items: center;
    justify-content: center;
    will-change: transform, opacity;
    mix-blend-mode: screen;
  }

  .candy-particle {
    filter: drop-shadow(0 0 4px rgba(255, 149, 0, 0.6));
  }

  .blood-particle {
    color: #8b0000;
    filter: drop-shadow(0 0 2px rgba(139, 0, 0, 0.4));
  }

  .spark-particle {
    color: #ffff00;
    filter: drop-shadow(0 0 6px rgba(255, 255, 0, 0.7));
    text-shadow: 0 0 10px rgba(255, 255, 0, 0.5);
  }

  /* Reduce motion preference */
  @media (prefers-reduced-motion: reduce) {
    .particle {
      animation: none;
    }
  }
</style>
