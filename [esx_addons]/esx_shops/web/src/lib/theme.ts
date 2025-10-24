import type { ThemeConvars } from '@/types/shop';

/**
 * Color definition with multiple formats
 */
interface ColorDefinition {
  hex: string;
  rgb: string;
  rgba: (alpha: number) => string;
}

/**
 * Creates a color definition from RGB values
 * @param r - Red value (0-255)
 * @param g - Green value (0-255)
 * @param b - Blue value (0-255)
 * @returns Color definition object
 */
const createColor = (r: number, g: number, b: number): ColorDefinition => ({
  hex: `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`.toUpperCase(),
  rgb: `rgba(${r}, ${g}, ${b}, 1)`,
  rgba: (alpha: number) => `rgba(${r}, ${g}, ${b}, ${alpha})`
});

/**
 * ESX UI Kit - Color Palette
 */
export const colors = {
  brand: createColor(251, 155, 4),
  darkest: createColor(22, 22, 22),
  dark: createColor(37, 37, 37),
  mid: createColor(56, 56, 56),
  light: createColor(150, 150, 150),
  lightest: createColor(242, 242, 242),
  error: createColor(244, 91, 105)
} as const;

/**
 * ESX UI Kit - Font Sizes
 */
export const fontSizes = {
  h1: '32px',
  h2: '24px',
  h3: '20px',
  h4: '18px',
  h5: '16px',
  h6: '14px'
} as const;

/**
 * Button state style definition
 */
interface ButtonState {
  background: string;
  color: string;
  border: string;
}

/**
 * ESX UI Kit - Button States
 */
export const buttonStates: Record<'active' | 'hover' | 'inactive' | 'disabled', ButtonState> = {
  active: {
    background: colors.brand.rgb,
    color: colors.darkest.rgb,
    border: 'none'
  },
  hover: {
    background: 'transparent',
    color: colors.brand.rgb,
    border: `1px solid ${colors.brand.hex}`
  },
  inactive: {
    background: colors.dark.rgb,
    color: colors.lightest.rgb,
    border: 'none'
  },
  disabled: {
    background: colors.light.rgba(0.2),
    color: colors.lightest.rgba(0.5),
    border: 'none'
  }
} as const;

/**
 * Applies theme overrides from server convars to CSS custom properties
 * @param convars - Theme configuration from server
 */
export function applyConvarTheme(convars: ThemeConvars): void {
  const root = document.documentElement;
  const propertyMap: Array<[keyof ThemeConvars, string]> = [
    ['primaryColor', '--primary-color'],
    ['secondaryColor', '--secondary-color'],
    ['backgroundColor', '--background-color'],
    ['accentColor', '--accent-color']
  ];

  propertyMap.forEach(([key, cssVar]) => {
    const value = convars[key];
    if (value) {
      root.style.setProperty(cssVar, value);
    }
  });
}
