/* ESX Legacy Garage Theme - Compliant with ESX Guidelines */

export const theme = {
  colors: {
    // ESX Brand Color (Primary Orange)
    brand: '#FB9B04',

    // ESX Grayscale Palette
    darkest: '#161616',
    dark: '#252525',
    mid: '#383838',
    light: '#969696',
    lightest: '#F2F2F2',

    // Accent Colors
    primary: '#FB9B04', // Orange accent
    secondary: '#FF8080', // Red for impound/danger

    // Semantic Colors
    background: '#161616',
    backgroundSecondary: '#252525',
    backgroundOverlay: 'rgba(37, 37, 37, 0.85)', // No backdrop-filter, using rgba

    border: 'rgba(255, 255, 255, 0.06)',
    borderLight: 'rgba(255, 255, 255, 0.08)',
    borderBrand: 'rgba(251, 155, 4, 0.45)',

    text: {
      primary: '#F2F2F2',
      secondary: 'rgba(242, 242, 242, 0.7)',
      disabled: 'rgba(242, 242, 242, 0.5)'
    },

    button: {
      primary: '#FB9B04',
      primaryHover: 'rgba(251, 155, 4, 0.8)',
      secondary: 'rgba(251, 155, 4, 0.1)',
      danger: '#FF8080',
      dangerBg: 'rgba(255, 128, 128, 0.1)'
    },

    // ESX Standard Shadows
    shadows: {
      sm: '0 6px 18px rgba(0, 0, 0, 0.25)',
      lg: '0 10px 30px rgba(0, 0, 0, 0.35)',
      brand: '0 6px 18px rgba(251, 155, 4, 0.25)'
    }
  },

  fonts: {
    primary: "'Roboto', system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif",
    weights: {
      light: 300,
      regular: 400,
      medium: 500,
      bold: 700
    }
  },

  // ESX Border Radius Standards
  sizes: {
    borderRadius: {
      sm: '8px',   // --radius-sm
      md: '12px',  // --radius-md
      lg: '16px'   // --radius-lg
    },

    spacing: {
      xs: '5px',
      sm: '10px',
      md: '20px',
      lg: '30px'
    },

    components: {
      header: {
        height: '56px' // ESX standard header height
      },
      toolbar: {
        height: '50px'
      },
      vehicleCard: {
        width: '20.625rem',
        height: '12rem'
      },
      scrollbar: {
        width: '4px'
      }
    }
  },

  // ESX Standard Transitions with cubic-bezier
  transitions: {
    fast: '160ms cubic-bezier(0.2, 0.7, 0.2, 1)',
    normal: '260ms cubic-bezier(0.2, 0.7, 0.2, 1)',
    slow: '350ms ease'
  },

  effects: {
    // Removed backdrop-filter for FiveM CEF compatibility
    // Using rgba() backgrounds instead
    opacity: {
      hover: 0.8,
      disabled: 0.5
    }
  },

  zIndex: {
    base: 1,
    dropdown: 100,
    modal: 1000,
    tooltip: 1100,
    toast: 1200
  }
} as const;

export type Theme = typeof theme;
