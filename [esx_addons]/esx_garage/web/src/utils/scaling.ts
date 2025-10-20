// Reference resolution for scaling calculations
export const REFERENCE_WIDTH = 1920;
export const REFERENCE_HEIGHT = 1080;
export const MIN_SCALE = 0.5;
export const MAX_SCALE = 2.5;

export const BREAKPOINTS = {
  HD: { width: 1280, height: 720, name: 'HD' },
  FHD: { width: 1920, height: 1080, name: 'FHD' },
  QHD: { width: 2560, height: 1440, name: 'QHD' },
  UHD: { width: 3840, height: 2160, name: 'UHD' }
} as const;

/**
 * Clamp a value between min and max
 */
export const clamp = (value: number, min: number, max: number): number => {
  return Math.min(Math.max(value, min), max);
};

/**
 * Get the current breakpoint based on viewport width
 */
export const getBreakpoint = (width: number): string => {
  if (width >= BREAKPOINTS.UHD.width) return BREAKPOINTS.UHD.name;
  if (width >= BREAKPOINTS.QHD.width) return BREAKPOINTS.QHD.name;
  if (width >= BREAKPOINTS.FHD.width) return BREAKPOINTS.FHD.name;
  return BREAKPOINTS.HD.name;
};

/**
 * Calculate scale factors based on viewport size
 */
export const calculateScale = () => {
  const width = window.innerWidth;
  const height = window.innerHeight;

  // Calculate scale based on both width and height
  const scaleX = width / REFERENCE_WIDTH;
  const scaleY = height / REFERENCE_HEIGHT;

  // Use the smaller scale to ensure content fits
  const scale = Math.min(scaleX, scaleY);

  // Clamp the scale to prevent too small or too large UI
  const clampedScale = clamp(scale, MIN_SCALE, MAX_SCALE);

  // Font scale is slightly less aggressive
  const fontScale = clamp(clampedScale * 0.9, MIN_SCALE * 0.9, MAX_SCALE * 0.9);

  return {
    scale: clampedScale,
    fontScale,
    viewport: { width, height },
    breakpoint: getBreakpoint(width),
    scalePercent: Math.round(clampedScale * 100)
  };
};

/**
 * Debounce function to limit resize event calls
 */
export const debounce = <T extends (...args: any[]) => any>(
  func: T,
  wait: number
): ((...args: Parameters<T>) => void) => {
  let timeout: NodeJS.Timeout;

  return (...args: Parameters<T>) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => func(...args), wait);
  };
};

/**
 * Convert px value to scaled value
 */
export const scalePx = (px: number, scale: number): string => {
  return `${px * scale}px`;
};