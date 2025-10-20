import React, { createContext, useContext, useEffect, useState, useCallback, type PropsWithChildren } from 'react';
import { isInGame } from '@/utils/nui';
import type { NuiMessage } from '@/types/nui.types';

interface NuiContextValue {
  isVisible: boolean;
  hasFocus: boolean;
  isInGame: boolean;
  setVisible: (visible: boolean) => void;
  setFocus: (focus: boolean, cursor?: boolean) => void;
  sendCallback: <T = unknown>(event: string, data?: unknown) => Promise<T>;
}

const NuiContext = createContext<NuiContextValue | null>(null);

export const useNuiContext = () => {
  const context = useContext(NuiContext);
  if (!context) {
    throw new Error('useNuiContext must be used within NuiProvider');
  }
  return context;
};

export const NuiProvider: React.FC<PropsWithChildren> = ({ children }) => {
  const [isVisible, setIsVisible] = useState(false);
  const [hasFocus, setHasFocus] = useState(false);
  const inGame = isInGame();

  const setVisible = useCallback((visible: boolean) => {
    setIsVisible(visible);
    if (!visible) {
      setFocus(false, false);
    }
  }, []);

  const setFocus = useCallback((focus: boolean, cursor = true) => {
    setHasFocus(focus);

    if (inGame) {
      // @ts-ignore - FiveM native
      SetNuiFocus(focus, cursor);
    }
  }, [inGame]);

  const sendCallback = useCallback(async <T = unknown,>(
    event: string,
    data?: unknown
  ): Promise<T> => {
    if (!inGame) {
      console.warn(`[NUI] sendCallback called outside game context: ${event}`);
      return Promise.reject(new Error('Not in game'));
    }

    // @ts-ignore - FiveM global
    const resourceName = typeof GetParentResourceName !== 'undefined' ? GetParentResourceName() : 'esx_garages';

    const response = await fetch(`https://${resourceName}/${event}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data ?? {})
    });

    const result = await response.json();

    if (!result.success) {
      throw new Error(result.error ?? 'Unknown error');
    }

    return result.data as T;
  }, [inGame]);

  useEffect(() => {
    const handleMessage = (event: MessageEvent<NuiMessage>) => {
      const { type } = event.data;

      if (type === 'setVisible') {
        setVisible(event.data.payload as boolean);
      } else if (type === 'setFocus') {
        const { focus, cursor } = event.data.payload as { focus: boolean; cursor: boolean };
        setFocus(focus, cursor);
      }
    };

    window.addEventListener('message', handleMessage);
    return () => window.removeEventListener('message', handleMessage);
  }, [setVisible, setFocus]);

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && hasFocus) {
        // Send closeUI callback to notify Lua
        sendCallback('garage:closeUI', {}).catch(console.error);
        setVisible(false);
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [hasFocus, setVisible, sendCallback]);

  const value: NuiContextValue = {
    isVisible,
    hasFocus,
    isInGame: inGame,
    setVisible,
    setFocus,
    sendCallback
  };

  return (
    <NuiContext.Provider value={value}>
      {children}
    </NuiContext.Provider>
  );
};
