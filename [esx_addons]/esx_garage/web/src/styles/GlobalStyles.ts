import { createGlobalStyle } from 'styled-components';

export const GlobalStyles = createGlobalStyle`
  /* Roboto Font is loaded from fonts.css */

  :root {
    /* Scaling variables for responsive UI */
    --ui-scale: 1;
    --ui-font-scale: 1;
    --ui-viewport-width: 1920px;
    --ui-viewport-height: 1080px;
    --ui-scale-percent: 100%;
    --ui-breakpoint: 'FHD';
    --ui-base-size: 16px;

    /* ESX Theme Variables - Align with ESX Guidelines */
    --brand: #FB9B04;
    --darkest: #161616;
    --dark: #252525;
    --mid: #383838;
    --light: #969696;
    --lightest: #F2F2F2;
    --toolbar-h: 50px;
    --radius-lg: 16px;
    --radius-md: 12px;
    --radius-sm: 8px;
    --shadow-1: 0 10px 30px rgba(0, 0, 0, 0.35);
    --shadow-2: 0 6px 18px rgba(0, 0, 0, 0.25);
    --transition-fast: 160ms cubic-bezier(0.2, 0.7, 0.2, 1);
    --transition-med: 260ms cubic-bezier(0.2, 0.7, 0.2, 1);

    font-size: calc(var(--ui-base-size) * var(--ui-font-scale));
  }

  * {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
  }

  html, body {
    width: 100%;
    height: 100%;
    background: transparent;
  }

  body {
    font-family: 'Roboto', system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
    font-weight: 500;
    font-size: 14px;
    line-height: 1.45;
    color: var(--lightest);
    background: transparent;
    overflow: hidden;
    user-select: none;
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
    cursor: default;
  }

  #root {
    width: 100vw;
    height: 100vh;
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  /* Global Scrollbar - Hidden by default, components can override */
  * {
    scrollbar-width: none;
  }

  *::-webkit-scrollbar {
    width: 0 !important;
    height: 0 !important;
  }

  /* Firefox scrollbar for specific elements that need it */
  @supports not selector(::-webkit-scrollbar) {
    .with-scrollbar {
      scrollbar-width: thin;
      scrollbar-color: var(--brand) rgba(251, 155, 4, 0.2);
    }
  }

  /* Animations */
  @keyframes fadeIn {
    from {
      opacity: 0;
      transform: translateY(10px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  @keyframes slideIn {
    from {
      opacity: 0;
      transform: translateX(-20px);
    }
    to {
      opacity: 1;
      transform: translateX(0);
    }
  }

  @keyframes pulse {
    0%, 100% {
      opacity: 1;
    }
    50% {
      opacity: 0.6;
    }
  }

  /* Utility Classes */
  .fade-in {
    animation: fadeIn 0.3s ease;
  }

  .slide-in {
    animation: slideIn 0.3s ease;
  }

  /* Remove default button styles */
  button {
    background: none;
    border: none;
    color: inherit;
    font: inherit;
    cursor: pointer;
    outline: none;
    transition: all var(--transition-fast);

    &:disabled {
      cursor: not-allowed;
      opacity: 0.5;
    }
  }

  /* Remove default input styles */
  input {
    background: none;
    border: none;
    color: inherit;
    font: inherit;
    outline: none;

    &::placeholder {
      color: rgba(242, 242, 242, 0.55);
    }
  }

  /* Image defaults */
  img {
    display: block;
    max-width: 100%;
    height: auto;
  }

  /* Focus styles for accessibility */
  *:focus-visible {
    outline: 2px solid var(--brand);
    outline-offset: 2px;
  }

  /* Selection colors */
  ::selection {
    background: transparent;
    color: inherit;
  }

  ::-moz-selection {
    background: transparent;
    color: inherit;
  }

  /* Reduce motion for accessibility */
  @media (prefers-reduced-motion: reduce) {
    * {
      transition: none !important;
      animation: none !important;
    }
  }
`;
