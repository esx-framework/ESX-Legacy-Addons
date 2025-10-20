import React from 'react';
import styled from 'styled-components';
import { AnimatePresence } from 'framer-motion';
import { Notification } from './Notification';
import { useNotifications } from '@/providers/NotificationProvider';

const Container = styled.div`
  position: fixed;
  top: 2rem;
  right: 2rem;
  z-index: ${props => props.theme.zIndex.toast};
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  pointer-events: none;

  > * {
    pointer-events: all;
  }
`;

export const NotificationContainer: React.FC = () => {
  const { notifications, removeNotification } = useNotifications();

  return (
    <Container>
      <AnimatePresence mode="popLayout">
        {notifications.map((notification) => (
          <Notification
            key={notification.id}
            notification={notification}
            onClose={() => removeNotification(notification.id)}
          />
        ))}
      </AnimatePresence>
    </Container>
  );
};
