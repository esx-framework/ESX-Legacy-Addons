import React, { createContext, useContext, useState, useCallback, type PropsWithChildren } from 'react';
import type { Notification, NotificationOptions } from '@/types/notification.types';
import { useNuiEvent } from '@/hooks/useNuiEvent';
import { NuiEventType } from '@/types/nui.types';

interface NotificationContextValue {
  notifications: Notification[];
  showNotification: (message: string, options?: NotificationOptions) => void;
  removeNotification: (id: string) => void;
  clearNotifications: () => void;
}

const NotificationContext = createContext<NotificationContextValue | null>(null);

export const useNotifications = () => {
  const context = useContext(NotificationContext);
  if (!context) {
    throw new Error('useNotifications must be used within NotificationProvider');
  }
  return context;
};

export const NotificationProvider: React.FC<PropsWithChildren> = ({ children }) => {
  const [notifications, setNotifications] = useState<Notification[]>([]);

  const showNotification = useCallback((message: string, options?: NotificationOptions) => {
    const id = `notification-${Date.now()}-${Math.random()}`;
    const notification: Notification = {
      id,
      message,
      type: options?.type ?? 'info',
      duration: options?.duration ?? 3000
    };

    setNotifications(prev => [...prev, notification]);
  }, []);

  const removeNotification = useCallback((id: string) => {
    setNotifications(prev => prev.filter(n => n.id !== id));
  }, []);

  const clearNotifications = useCallback(() => {
    setNotifications([]);
  }, []);

  useNuiEvent<{ message: string; type?: NotificationOptions['type'] }>(
    NuiEventType.SHOW_NOTIFICATION,
    (data) => {
      showNotification(data.message, { type: data.type ?? 'info' });
    }
  );

  useNuiEvent<{ message: string }>(NuiEventType.SHOW_ERROR, (data) => {
    showNotification(data.message, { type: 'error' });
  });

  const value: NotificationContextValue = {
    notifications,
    showNotification,
    removeNotification,
    clearNotifications
  };

  return (
    <NotificationContext.Provider value={value}>
      {children}
    </NotificationContext.Provider>
  );
};
