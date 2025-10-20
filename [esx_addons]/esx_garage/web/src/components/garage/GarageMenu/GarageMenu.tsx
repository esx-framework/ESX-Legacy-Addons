import React from 'react';
import styled, { ThemeProvider } from 'styled-components';
import { AnimatePresence, motion } from 'framer-motion';
import { theme } from '@/styles/theme';
import { GarageHeader } from '../GarageHeader';
import { VehicleGrid } from '@/components/vehicle/VehicleGrid';
import { VehicleDetails } from '@/components/vehicle/VehicleDetails';
import { useGarageStore } from '@/store/garage.store';
import { useNuiEvent } from '@/hooks/useNuiEvent';
import { NuiEventType } from '@/types/nui.types';
import type { Vehicle } from '@/types/vehicle.types';
import type { Garage } from '@/types/garage.types';

const Container = styled.div`
  width: 100vw;
  height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  pointer-events: none;
`;

const GridContainer = styled(motion.div)`
  display: grid;
  grid-template-columns: 66.5rem 22.5rem;
  gap: 1.25rem;
  align-items: center;
  pointer-events: all;
  width: auto;
`;

const MenuContainer = styled(motion.div)`
  background: ${props => props.theme.colors.background};
  border: 1px solid ${props => props.theme.colors.border};
  border-radius: ${props => props.theme.sizes.borderRadius.sm};
  display: flex;
  flex-direction: column;
  width: 100%;
  min-height: 37.5rem;
  max-height: 45.875rem;
  height: 68vh;
  position: relative;
  overflow: hidden;
  z-index: 10;
`;

const LoadingOverlay = styled(motion.div)`
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.7);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: ${props => props.theme.zIndex.modal};
`;

const LoadingSpinner = styled.div`
  width: 3.125rem;
  height: 3.125rem;
  border: 0.1875rem solid ${props => props.theme.colors.backgroundSecondary};
  border-top: 0.1875rem solid ${props => props.theme.colors.primary};
  border-radius: 50%;
  animation: spin 1s linear infinite;

  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }
`;

interface OpenGarageData {
  garage: Garage;
  vehicles: Vehicle[];
}

export const GarageMenu: React.FC = () => {
  const {
    isOpen,
    isLoading,
    selectedVehicle,
    setOpen,
    selectGarage,
    selectVehicle,
    updateVehicles
  } = useGarageStore();

  // Listen for NUI events
  useNuiEvent<OpenGarageData>(NuiEventType.OPEN_GARAGE, (data) => {
    selectGarage(data.garage);
    updateVehicles(data.vehicles);
    setOpen(true);
  });

  useNuiEvent(NuiEventType.CLOSE_GARAGE, () => {
    setOpen(false);
  });

  useNuiEvent<Vehicle[]>(NuiEventType.UPDATE_VEHICLES, (vehicles) => {
    updateVehicles(vehicles);
  });

  return (
    <ThemeProvider theme={theme}>
      <AnimatePresence>
        {isOpen && (
          <Container>
            <GridContainer
              initial={{ x: 180 }}
              animate={{ x: selectedVehicle ? 0 : 180 }}
              transition={{
                duration: 0.6,
                ease: [0.34, 1.3, 0.64, 1]
              }}
            >
              <MenuContainer
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                transition={{
                  opacity: { duration: 0.3 }
                }}
              >
                <GarageHeader />
                <VehicleGrid onVehicleClick={(vehicle) => selectVehicle(vehicle)} />

                <AnimatePresence>
                  {isLoading && (
                    <LoadingOverlay
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      exit={{ opacity: 0 }}
                    >
                      <LoadingSpinner />
                    </LoadingOverlay>
                  )}
                </AnimatePresence>
              </MenuContainer>

              <AnimatePresence mode="wait">
                {selectedVehicle && (
                  <VehicleDetails
                    key="details"
                    vehicle={selectedVehicle}
                    onClose={() => selectVehicle(null)}
                  />
                )}
              </AnimatePresence>
            </GridContainer>
          </Container>
        )}
      </AnimatePresence>
    </ThemeProvider>
  );
};