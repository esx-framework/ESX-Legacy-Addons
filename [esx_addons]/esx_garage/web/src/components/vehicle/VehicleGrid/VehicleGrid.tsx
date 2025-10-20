import React from 'react';
import styled from 'styled-components';
import type { Vehicle } from '@/types/vehicle.types';
import { VehicleCard } from '../VehicleCard';
import { useGarageStore } from '@/store/garage.store';

const GridContainer = styled.div`
  width: 100%;
  height: calc(100% - 3.875rem - 1.25rem); /* header + bottom spacing */
  display: flex;
  padding-top: 1.25rem;
`;

const VehiclesWrapper = styled.div`
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
  padding-left: 1.25rem;
  padding-right: 0.625rem;
  margin-right: 1.25rem;

  /* Custom Scrollbar - Clean & Simple */
  &::-webkit-scrollbar {
    width: 0.25rem;
  }

  &::-webkit-scrollbar-button {
    display: none;
  }

  &::-webkit-scrollbar-track {
    background: rgba(251, 155, 4, 0.20);
    border-radius: 0.125rem;
  }

  &::-webkit-scrollbar-thumb {
    background: ${props => props.theme.colors.primary};
    border-radius: 0.125rem;

    &:hover {
      background: ${props => props.theme.colors.button.primaryHover};
    }
  }
`;

const VehiclesGrid = styled.div`
  display: grid;
  grid-template-columns: repeat(3, 20.625rem);
  gap: 0.625rem;
  width: 100%;
  padding-bottom: 0.625rem;
  padding-right: 0.625rem;
  justify-content: start;
`;

const EmptyState = styled.div`
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: ${props => props.theme.colors.text.secondary};
  font-size: 1.125rem;
  text-align: center;
  gap: 1.25rem;
`;

interface VehicleGridProps {
  onVehicleClick?: (vehicle: Vehicle) => void;
}

export const VehicleGrid: React.FC<VehicleGridProps> = ({ onVehicleClick }) => {
  const { getFilteredVehicles, retrieveVehicle } = useGarageStore();
  const vehicles = getFilteredVehicles();

  const handleVehicleClick = (vehicle: Vehicle) => {
    if (vehicle.stored) {
      retrieveVehicle(vehicle.id);
    }
    onVehicleClick?.(vehicle);
  };

  if (vehicles.length === 0) {
    return (
      <GridContainer>
        <VehiclesWrapper>
          <EmptyState>
            <div>No vehicles found</div>
            <div style={{ fontSize: '0.875rem', opacity: 0.7 }}>
              Try adjusting your search or filters
            </div>
          </EmptyState>
        </VehiclesWrapper>
      </GridContainer>
    );
  }

  return (
    <GridContainer>
      <VehiclesWrapper>
        <VehiclesGrid>
          {vehicles.map((vehicle) => (
            <VehicleCard
              key={vehicle.id}
              vehicle={vehicle}
              onClick={() => handleVehicleClick(vehicle)}
            />
          ))}
        </VehiclesGrid>
      </VehiclesWrapper>
    </GridContainer>
  );
};
