import React, { createContext, useContext, useEffect, useState } from 'react';
import { calculateScale, debounce } from '@/utils/scaling';

interface ScaleContextValue {
  scale: number;
  fontScale: number;
  viewport: { width: number; height: number };
  breakpoint: string;
  scalePercent: number;
}

const ScaleContext = createContext<ScaleContextValue | null>(null);

export const useScale = () => {
  const context = useContext(ScaleContext);
  if (!context) {
    throw new Error('useScale must be used within ScaleProvider');
  }
  return context;
};

interface ScaleProviderProps {
  children: React.ReactNode;
}

export const ScaleProvider: React.FC<ScaleProviderProps> = ({ children }) => {
  const [scaleData, setScaleData] = useState(calculateScale());

  useEffect(() => {
    const handleResize = debounce(() => {
      const newScaleData = calculateScale();
      setScaleData(newScaleData);
    }, 150);

    // Initial setup
    handleResize();

    // Listen for resize events
    window.addEventListener('resize', handleResize);

    return () => {
      window.removeEventListener('resize', handleResize);
    };
  }, []);

  useEffect(() => {
    // Update CSS variables
    const root = document.documentElement;
    root.style.setProperty('--ui-scale', scaleData.scale.toString());
    root.style.setProperty('--ui-font-scale', scaleData.fontScale.toString());
    root.style.setProperty('--ui-viewport-width', `${scaleData.viewport.width}px`);
    root.style.setProperty('--ui-viewport-height', `${scaleData.viewport.height}px`);
    root.style.setProperty('--ui-scale-percent', `${scaleData.scalePercent}%`);
    root.style.setProperty('--ui-breakpoint', scaleData.breakpoint);
  }, [scaleData]);

  return (
    <ScaleContext.Provider value={scaleData}>
      {children}
    </ScaleContext.Provider>
  );
};