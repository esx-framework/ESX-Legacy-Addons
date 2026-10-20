/**
 * Tests for mapping the server theme onto the kit's custom properties.
 *
 * @see themeVariables
 */

import { describe, expect, it } from 'vitest';
import { themeVariables, toRgbChannels } from './theme';

describe('toRgbChannels', (): void => {
  it('should split a six digit color', (): void => {
    expect(toRgbChannels('#FB9B04')).toBe('251, 155, 4');
  });

  it('should expand a three digit color', (): void => {
    expect(toRgbChannels('#0f8')).toBe('0, 255, 136');
  });
});

describe('themeVariables', (): void => {
  it('should use the kit colors without a theme', (): void => {
    expect(themeVariables(undefined)).toEqual({
      '--brand-color': '#fb9b04',
      '--brand-color-rgb': '251, 155, 4',
      '--dark-color': '#252525',
      '--dark-color-rgb': '37, 37, 37',
      '--darkest-color': '#161616',
      '--darkest-color-rgb': '22, 22, 22',
      '--mid-color': '#383838',
      '--mid-color-rgb': '56, 56, 56',
    });
  });

  it('should take the server colors and keep the kit for the rest', (): void => {
    const variables = themeVariables({ primaryColor: '#2f80ed', accentColor: '#444' });
    expect(variables['--brand-color']).toBe('#2f80ed');
    expect(variables['--brand-color-rgb']).toBe('47, 128, 237');
    expect(variables['--mid-color-rgb']).toBe('68, 68, 68');
    expect(variables['--dark-color']).toBe('#252525');
  });

  it('should ignore a color that is not hex', (): void => {
    expect(themeVariables({ primaryColor: 'red' })['--brand-color']).toBe('#fb9b04');
  });
});
