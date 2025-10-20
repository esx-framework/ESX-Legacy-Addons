export type NotificationType = 'success' | 'error' | 'info' | 'warning';

export interface Notification {
  id: string;
  type: NotificationType;
  message: string;
  duration?: number;
}

export interface NotificationOptions {
  type?: NotificationType;
  duration?: number;
}
