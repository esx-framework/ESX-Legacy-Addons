import React, { useState } from 'react';
import styled from 'styled-components';
import { motion } from 'framer-motion';
import { MdStar, MdStarBorder, MdEdit } from 'react-icons/md';
import type { Vehicle } from '@/types/vehicle.types';
import { useGarageStore } from '@/store/garage.store';

const CardContainer = styled(motion.div)`
  background: ${props => props.theme.colors.background};
  border-radius: ${props => props.theme.sizes.borderRadius.sm};
  border: 1px solid ${props => props.theme.colors.borderLight};
  width: 20.625rem;
  height: 12rem;
  overflow: hidden;
  cursor: pointer;
  transition: ${props => props.theme.transitions.fast};
  display: grid;
  grid-template-rows: auto 1fr auto;

  &:hover {
    border-color: ${props => props.theme.colors.primary};
    transform: translateY(-0.125rem);
  }
`;

const VehicleImage = styled.img`
  grid-row: 1 / -1;
  grid-column: 1;
  width: 100%;
  height: 100%;
  object-fit: contain;
  opacity: 0.8;
  pointer-events: none;
  padding: 1.25rem;
  z-index: 0;
`;

const VehicleOverlay = styled.div`
  grid-row: 1 / -1;
  grid-column: 1;
  background: linear-gradient(180deg, rgba(0,0,0,0.8) 0%, transparent 50%, rgba(0,0,0,0.8) 100%);
  pointer-events: none;
  z-index: 1;
`;

const InfoContainer = styled.div`
  grid-row: 1;
  grid-column: 1;
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  padding: 0.625rem;
  z-index: 2;
`;

const VehicleInfo = styled.div`
  display: flex;
  flex-direction: column;
  gap: 0.3125rem;
`;

const VehicleName = styled.h3`
  color: ${props => props.theme.colors.text.primary};
  font-size: 0.75rem;
  font-weight: ${props => props.theme.fonts.weights.medium};
  margin: 0;
  text-transform: uppercase;
`;

const VehicleDetails = styled.div`
  display: flex;
  gap: ${props => props.theme.sizes.spacing.sm};
`;

const DetailBadge = styled.div`
  background: ${props => props.theme.colors.backgroundSecondary};
  border-radius: ${props => props.theme.sizes.borderRadius.sm};
  padding: 0 0.3125rem;
  height: 1.125rem;
  display: flex;
  align-items: center;
  justify-content: center;
`;

const DetailText = styled.span`
  color: ${props => props.theme.colors.text.primary};
  font-size: 0.625rem;
  font-weight: ${props => props.theme.fonts.weights.bold};
`;

const ActionButtons = styled.div`
  display: flex;
  gap: 0.3125rem;
  height: 2rem;
`;

const ActionButton = styled.button<{ $active?: boolean }>`
  background: ${props =>
    props.$active
      ? props.theme.colors.primary
      : props.theme.colors.backgroundSecondary};
  border-radius: ${props => props.theme.sizes.borderRadius.sm};
  width: 2rem;
  height: 2rem;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: ${props => props.theme.transitions.fast};
  box-shadow: ${props => props.$active ? props.theme.colors.shadows.brand : 'none'};

  svg {
    width: 1.125rem;
    height: 1.125rem;
    color: ${props =>
      props.$active
        ? props.theme.colors.background
        : props.theme.colors.text.secondary};
  }

  &:hover {
    background: ${props =>
      props.$active
        ? props.theme.colors.button.primaryHover
        : props.theme.colors.backgroundSecondary};
  }
`;

const BottomContainer = styled.div`
  grid-row: 3;
  grid-column: 1;
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  padding: 0.625rem;
  z-index: 2;
`;

const StatusIndicator = styled.div<{ $impounded?: boolean }>`
  background: ${props =>
    props.$impounded
      ? props.theme.colors.secondary
      : props.theme.colors.primary};
  color: ${props => props.theme.colors.background};
  padding: 0.25rem 0.5rem;
  border-radius: ${props => props.theme.sizes.borderRadius.sm};
  font-size: 0.625rem;
  font-weight: ${props => props.theme.fonts.weights.bold};
  text-transform: uppercase;
  margin-left: auto;
`;

const PriceTag = styled.div`
  background: ${props => props.theme.colors.secondary};
  color: ${props => props.theme.colors.text.primary};
  padding: 0.25rem 0.5rem;
  border-radius: ${props => props.theme.sizes.borderRadius.sm};
  font-size: 0.625rem;
  font-weight: ${props => props.theme.fonts.weights.bold};
`;

const RenameInput = styled.input`
  background: ${props => props.theme.colors.backgroundSecondary};
  border: 1px solid ${props => props.theme.colors.primary};
  border-radius: ${props => props.theme.sizes.borderRadius.sm};
  color: ${props => props.theme.colors.text.primary};
  font-size: 0.75rem;
  padding: 0.125rem 0.3125rem;
  outline: none;
  width: 6.25rem;
`;

interface VehicleCardProps {
  vehicle: Vehicle;
  onClick?: () => void;
}

export const VehicleCard: React.FC<VehicleCardProps> = ({ vehicle, onClick }) => {
  const { toggleFavorite, renameVehicle } = useGarageStore();
  const [isRenaming, setIsRenaming] = useState(false);
  const [newName, setNewName] = useState(vehicle.customName || '');

  const handleFavoriteClick = (e: React.MouseEvent) => {
    e.stopPropagation();
    toggleFavorite(vehicle.id);
  };

  const handleRenameClick = (e: React.MouseEvent) => {
    e.stopPropagation();
    setIsRenaming(true);
  };

  const handleRenameSubmit = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      renameVehicle(vehicle.id, newName);
      setIsRenaming(false);
    } else if (e.key === 'Escape') {
      setIsRenaming(false);
      setNewName(vehicle.customName || '');
    }
  };

  const formatMileage = (mileage: number) => {
    // Convert to miles (1 km = 0.621371 miles)
    const miles = mileage * 0.621371 / 1000;
    return `${miles.toFixed(1)} miles`;
  };

  return (
    <CardContainer
      onClick={onClick}
      whileHover={{ scale: 1.02 }}
      whileTap={{ scale: 0.98 }}
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3 }}
    >
      <VehicleImage
        src={vehicle.image || '/Car.svg'}
        alt={vehicle.name}
        onError={(e) => {
          e.currentTarget.src = '/Car.svg';
        }}
      />
      <VehicleOverlay />

      <InfoContainer>
        <VehicleInfo>
          {isRenaming ? (
            <RenameInput
              type="text"
              value={newName}
              onChange={(e) => setNewName(e.target.value)}
              onKeyDown={handleRenameSubmit}
              onBlur={() => setIsRenaming(false)}
              autoFocus
              onClick={(e) => e.stopPropagation()}
            />
          ) : (
            <VehicleName>{vehicle.customName || vehicle.name}</VehicleName>
          )}
          <VehicleDetails>
            <DetailBadge>
              <DetailText>{vehicle.plate}</DetailText>
            </DetailBadge>
            <DetailBadge>
              <DetailText>{formatMileage(vehicle.mileage)}</DetailText>
            </DetailBadge>
          </VehicleDetails>
        </VehicleInfo>

        <ActionButtons>
          <ActionButton
            $active={vehicle.isFavorite}
            onClick={handleFavoriteClick}
            title="Toggle Favorite"
          >
            {vehicle.isFavorite ? <MdStar /> : <MdStarBorder />}
          </ActionButton>
          <ActionButton onClick={handleRenameClick} title="Rename Vehicle">
            <MdEdit />
          </ActionButton>
        </ActionButtons>
      </InfoContainer>

      <BottomContainer>
        {vehicle.impounded ? (
          <>
            {vehicle.impoundFee && (
              <PriceTag>${vehicle.impoundFee}</PriceTag>
            )}
            <StatusIndicator $impounded>Impounded</StatusIndicator>
          </>
        ) : (
          <StatusIndicator>
            {vehicle.stored ? 'Stored' : 'Out'}
          </StatusIndicator>
        )}
      </BottomContainer>
    </CardContainer>
  );
};
