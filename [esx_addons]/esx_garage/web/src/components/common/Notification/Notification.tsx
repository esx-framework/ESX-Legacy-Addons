import React, { useEffect } from 'react';
import styled from 'styled-components';
import { motion } from 'framer-motion';
import type { Notification as NotificationType } from '@/types/notification.types';
import { FiCheck, FiX, FiInfo, FiAlertTriangle } from 'react-icons/fi';

const NotificationContainer = styled(motion.div)<{ $type: NotificationType['type'] }>`
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 1rem 1.25rem;
  background: ${props => {
    switch (props.$type) {
      case 'success': return 'rgba(16, 185, 129, 0.1)';
      case 'error': return 'rgba(239, 68, 68, 0.1)';
      case 'warning': return 'rgba(251, 155, 4, 0.1)';
      default: return props.theme.colors.backgroundSecondary;
    }
  }};
  border: 1px solid ${props => {
    switch (props.$type) {
      case 'success': return 'rgba(16, 185, 129, 0.3)';
      case 'error': return 'rgba(239, 68, 68, 0.3)';
      case 'warning': return 'rgba(251, 155, 4, 0.3)';
      default: return props.theme.colors.border;
    }
  }};
  border-radius: ${props => props.theme.sizes.borderRadius.sm};
  min-width: 20rem;
  max-width: 25rem;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
`;

const IconWrapper = styled.div<{ $type: NotificationType['type'] }>`
  display: flex;
  align-items: center;
  justify-content: center;
  width: 1.5rem;
  height: 1.5rem;
  color: ${props => {
    switch (props.$type) {
      case 'success': return '#10B981';
      case 'error': return '#EF4444';
      case 'warning': return props.theme.colors.primary;
      default: return props.theme.colors.text.primary;
    }
  }};
`;

const Message = styled.div`
  flex: 1;
  font-size: 0.875rem;
  font-weight: ${props => props.theme.fonts.weights.medium};
  color: ${props => props.theme.colors.text.primary};
  line-height: 1.4;
`;

const CloseButton = styled.button`
  display: flex;
  align-items: center;
  justify-content: center;
  width: 1.25rem;
  height: 1.25rem;
  background: none;
  border: none;
  color: ${props => props.theme.colors.text.secondary};
  cursor: pointer;
  transition: color ${props => props.theme.transitions.fast};

  &:hover {
    color: ${props => props.theme.colors.text.primary};
  }
`;

interface NotificationProps {
  notification: NotificationType;
  onClose: () => void;
}

export const Notification: React.FC<NotificationProps> = ({ notification, onClose }) => {
  const { type, message, duration = 3000 } = notification;

  useEffect(() => {
    if (duration > 0) {
      const timer = setTimeout(onClose, duration);
      return () => clearTimeout(timer);
    }
  }, [duration, onClose]);

  const Icon = () => {
    switch (type) {
      case 'success': return <FiCheck size={20} />;
      case 'error': return <FiX size={20} />;
      case 'warning': return <FiAlertTriangle size={20} />;
      default: return <FiInfo size={20} />;
    }
  };

  return (
    <NotificationContainer
      $type={type}
      initial={{ opacity: 0, y: -20, scale: 0.95 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      exit={{ opacity: 0, x: 100, scale: 0.95 }}
      transition={{ duration: 0.2 }}
    >
      <IconWrapper $type={type}>
        <Icon />
      </IconWrapper>
      <Message>{message}</Message>
      <CloseButton onClick={onClose}>
        <FiX size={16} />
      </CloseButton>
    </NotificationContainer>
  );
};
