<script lang="ts">
  import { setContext, onMount, type Snippet } from 'svelte';
  import {
    BASE_FONT_SIZE,
    DEBOUNCE_DELAY_MS,
    SCALING_BREAKPOINTS,
    BREAKPOINT_KEYS
  } from '@/constants/ui';

  interface Props {
    children?: Snippet;
  }

  let { children }: Props = $props();

  /** Minimum allowed scale factor */
  const MIN_SCALE = 0.5;
  /** Maximum allowed scale factor */
  const MAX_SCALE = 1.5;

  let scale = $state<number>(1);

  /**
   * Calculates UI scale based on breakpoints for current viewport size
   * Uses predefined breakpoints (HD, FHD, QHD, 4K, 5K) with interpolation
   * @returns Clamped scale value between MIN_SCALE and MAX_SCALE
   */
  function calculateScale(): number {
    const width = window.innerWidth;
    const height = window.innerHeight;

    // Find appropriate breakpoints for current resolution
    let lowerBreakpoint = null;
    let upperBreakpoint = null;

    for (let i = 0; i < BREAKPOINT_KEYS.length; i++) {
      const key = BREAKPOINT_KEYS[i] as keyof typeof SCALING_BREAKPOINTS;
      const breakpoint = SCALING_BREAKPOINTS[key];

      // Check if current resolution fits within this breakpoint
      if (width <= breakpoint.width || height <= breakpoint.height) {
        upperBreakpoint = breakpoint;
        if (i > 0) {
          const prevKey = BREAKPOINT_KEYS[i - 1] as keyof typeof SCALING_BREAKPOINTS;
          lowerBreakpoint = SCALING_BREAKPOINTS[prevKey];
        }
        break;
      }
    }

    // Resolution larger than all breakpoints - use largest breakpoint
    if (!upperBreakpoint) {
      return Math.max(MIN_SCALE, Math.min(MAX_SCALE, SCALING_BREAKPOINTS._5K.scale));
    }

    // Resolution smaller than HD - use HD scale
    if (!lowerBreakpoint) {
      return Math.max(MIN_SCALE, Math.min(MAX_SCALE, SCALING_BREAKPOINTS.HD.scale));
    }

    // Interpolate between breakpoints for smooth scaling
    const widthProgress = (width - lowerBreakpoint.width) / (upperBreakpoint.width - lowerBreakpoint.width);
    const heightProgress =
      (height - lowerBreakpoint.height) / (upperBreakpoint.height - lowerBreakpoint.height);

    // Use the smaller progress to ensure UI fits
    const progress = Math.min(widthProgress, heightProgress);
    const interpolatedScale =
      lowerBreakpoint.scale + (upperBreakpoint.scale - lowerBreakpoint.scale) * progress;

    return Math.max(MIN_SCALE, Math.min(MAX_SCALE, interpolatedScale));
  }

  /**
   * Updates CSS custom properties with new scale value
   */
  function updateScale(): void {
    const newScale = calculateScale();
    scale = newScale;

    const root = document.documentElement;
    root.style.setProperty('--ui-scale', newScale.toString());
    root.style.setProperty('--base-font-size', `${BASE_FONT_SIZE * newScale}px`);
  }

  onMount(() => {
    updateScale();

    let resizeTimeout: ReturnType<typeof setTimeout>;

    /**
     * Debounced resize handler to improve performance
     */
    const handleResize = (): void => {
      clearTimeout(resizeTimeout);
      resizeTimeout = setTimeout(updateScale, DEBOUNCE_DELAY_MS);
    };

    window.addEventListener('resize', handleResize);

    return () => {
      window.removeEventListener('resize', handleResize);
      clearTimeout(resizeTimeout);
    };
  });

  // Provide scale context to children
  setContext('scale', {
    get current() {
      return scale;
    }
  });
</script>

{@render children?.()}
