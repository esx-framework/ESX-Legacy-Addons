import React from 'react';
import styled from 'styled-components';
import { motion } from 'framer-motion';
import { MdSettings } from 'react-icons/md';
import type { Vehicle } from '@/types/vehicle.types';
import { useGarageStore } from '@/store/garage.store';
import { fetchNui } from '@/utils/nui';
import { NuiCallbackType } from '@/types/nui.types';
import { getVehicleImagePath } from '@/utils/vehicle';

const DetailsContainer = styled(motion.div)`
  background: ${props => props.theme.colors.background};
  border: 1px solid ${props => props.theme.colors.border};
  border-radius: ${props => props.theme.sizes.borderRadius.sm};
  padding: ${props => props.theme.sizes.spacing.md};
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: space-between;
  width: 100%;
  height: 100%;
  overflow: hidden;
  pointer-events: all;
  z-index: 5;
`;

const VehicleHeader = styled.div`
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  justify-content: space-between;
  align-self: stretch;
  min-height: 12.5rem;
`;

const HeaderRow = styled.div`
  display: flex;
  flex-direction: row;
  align-items: center;
  justify-content: space-between;
  align-self: stretch;
`;

const VehicleName = styled.h2`
  color: ${props => props.theme.colors.text.primary};
  font-size: 1.5rem;
  font-weight: ${props => props.theme.fonts.weights.medium};
  margin: 0;
  text-transform: uppercase;
`;

const EngineIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="15" height="13" viewBox="0 0 15 13" fill="none">
    <path fillRule="evenodd" clipRule="evenodd" d="M7 0.25C7.19891 0.25 7.38967 0.329018 7.53033 0.46967C7.67098 0.610322 7.75 0.801088 7.75 1C7.75 1.19891 7.67098 1.38968 7.53033 1.53033C7.38967 1.67098 7.19891 1.75 7 1.75H6.25V2.5H8.323C8.55575 2.50002 8.7853 2.5542 8.9935 2.65825L11.4205 3.87175C11.6697 3.99629 11.8794 4.18779 12.0259 4.42478C12.1724 4.66177 12.25 4.93488 12.25 5.2135V7H13V6.25C13 6.05109 13.079 5.86032 13.2197 5.71967C13.3603 5.57902 13.5511 5.5 13.75 5.5C13.9489 5.5 14.1397 5.57902 14.2803 5.71967C14.421 5.86032 14.5 6.05109 14.5 6.25V9.25C14.5 9.44892 14.421 9.63968 14.2803 9.78033C14.1397 9.92099 13.9489 10 13.75 10C13.5511 10 13.3603 9.92099 13.2197 9.78033C13.079 9.63968 13 9.44892 13 9.25V8.5H12.25V9.625C12.25 9.85787 12.1958 10.0875 12.0916 10.2958C11.9875 10.5041 11.8363 10.6853 11.65 10.825L9.15025 12.7C8.8906 12.8947 8.5748 13 8.25025 13H1.75C1.35217 13 0.970644 12.842 0.68934 12.5607C0.408035 12.2794 0.25 11.8978 0.25 11.5V4C0.25 3.60218 0.408035 3.22065 0.68934 2.93934C0.970644 2.65804 1.35217 2.5 1.75 2.5H4.75V1.75H4C3.80109 1.75 3.61032 1.67098 3.46967 1.53033C3.32902 1.38968 3.25 1.19891 3.25 1C3.25 0.801088 3.32902 0.610322 3.46967 0.46967C3.61032 0.329018 3.80109 0.25 4 0.25H7ZM6.26125 5.23225C6.10365 5.13748 5.91673 5.10391 5.73601 5.13793C5.55528 5.17194 5.39335 5.27117 5.281 5.41675L5.23225 5.4895L4.114 7.3525C4.04865 7.46113 4.01162 7.58442 4.00628 7.71108C4.00094 7.83774 4.02748 7.96371 4.08345 8.07745C4.13943 8.19119 4.22305 8.28906 4.32666 8.3621C4.43027 8.43514 4.55056 8.48101 4.6765 8.4955L4.7635 8.5H5.6755L5.23225 9.2395C5.13457 9.40354 5.10313 9.59865 5.14433 9.78507C5.18553 9.97149 5.29627 10.1352 5.45398 10.2428C5.61169 10.3504 5.80449 10.3938 5.99309 10.3641C6.1817 10.3345 6.35189 10.234 6.469 10.0833L6.5185 10.0113L7.636 8.1475C7.70134 8.03887 7.73838 7.91558 7.74372 7.78893C7.74905 7.66227 7.72252 7.5363 7.66654 7.42256C7.61057 7.30882 7.52695 7.21094 7.42333 7.1379C7.31972 7.06487 7.19943 7.019 7.0735 7.0045L6.9865 7H6.0745L6.51775 6.26125C6.62015 6.09078 6.65066 5.88661 6.60256 5.69364C6.55446 5.50068 6.43169 5.33471 6.26125 5.23225Z" fill="white"/>
  </svg>
);

const BodyIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 18 18" fill="none">
    <path d="M12.9937 7.5L12.7875 6.61875C12.65 6.56875 12.5157 6.50625 12.3847 6.43125C12.2537 6.35625 12.1317 6.26875 12.0187 6.16875L11.1562 6.45L10.65 5.5875L11.3062 4.95C11.2812 4.8 11.2687 4.65 11.2687 4.5C11.2687 4.35 11.2812 4.2 11.3062 4.05L10.65 3.45L11.1562 2.5875L12 2.83125C12.1125 2.73125 12.2345 2.64375 12.366 2.56875C12.4975 2.49375 12.638 2.43125 12.7875 2.38125L12.9937 1.5H13.9875L14.2125 2.3625C14.3625 2.425 14.5032 2.49375 14.6347 2.56875C14.7662 2.64375 14.888 2.73125 15 2.83125L15.8437 2.5875L16.35 3.45L15.7125 4.05C15.7375 4.2 15.7532 4.35325 15.7597 4.50975C15.7662 4.66625 15.7505 4.81925 15.7125 4.96875L16.35 5.56875L15.8625 6.43125L15 6.16875C14.8875 6.26875 14.7625 6.35625 14.625 6.43125C14.4875 6.50625 14.35 6.56875 14.2125 6.61875L13.9875 7.5H12.9937ZM13.5 5.625C13.8125 5.625 14.0782 5.51575 14.2972 5.29725C14.5162 5.07875 14.6255 4.813 14.625 4.5C14.6245 4.187 14.5152 3.9215 14.2972 3.7035C14.0792 3.4855 13.8135 3.376 13.5 3.375C13.1865 3.374 12.921 3.4835 12.7035 3.7035C12.486 3.9235 12.3765 4.189 12.375 4.5C12.3735 4.811 12.483 5.07675 12.7035 5.29725C12.924 5.51775 13.1895 5.627 13.5 5.625ZM5.625 12C5.9375 12 6.20325 11.8908 6.42225 11.6723C6.64125 11.4538 6.7505 11.188 6.75 10.875C6.7495 10.562 6.64025 10.2965 6.42225 10.0785C6.20425 9.8605 5.9385 9.751 5.625 9.75C5.3115 9.749 5.046 9.8585 4.8285 10.0785C4.611 10.2985 4.5015 10.564 4.5 10.875C4.4985 11.186 4.608 11.4518 4.8285 11.6723C5.049 11.8928 5.3145 12.002 5.625 12ZM12.375 12C12.6875 12 12.9532 11.8908 13.1722 11.6723C13.3912 11.4538 13.5005 11.188 13.5 10.875C13.4995 10.562 13.3902 10.2965 13.1722 10.0785C12.9542 9.8605 12.6885 9.751 12.375 9.75C12.0615 9.749 11.796 9.8585 11.5785 10.0785C11.361 10.2985 11.2515 10.564 11.25 10.875C11.2485 11.186 11.358 11.4518 11.5785 11.6723C11.799 11.8928 12.0645 12.002 12.375 12ZM13.5 9C13.9 9 14.2907 8.95 14.6722 8.85C15.0537 8.75 15.413 8.6 15.75 8.4V15C15.75 15.2125 15.678 15.3908 15.534 15.5348C15.39 15.6788 15.212 15.7505 15 15.75H14.25C14.0375 15.75 13.8595 15.678 13.716 15.534C13.5725 15.39 13.5005 15.212 13.5 15V14.25H4.5V15C4.5 15.2125 4.428 15.3908 4.284 15.5348C4.14 15.6788 3.962 15.7505 3.75 15.75H3C2.7875 15.75 2.6095 15.678 2.466 15.534C2.3225 15.39 2.2505 15.212 2.25 15V9L3.80625 4.5C3.88125 4.275 4.01575 4.09375 4.20975 3.95625C4.40375 3.81875 4.6255 3.75 4.875 3.75H9.075C9.05 3.875 9.03125 3.997 9.01875 4.116C9.00625 4.235 9 4.363 9 4.5C9 4.637 9.00625 4.76525 9.01875 4.88475C9.03125 5.00425 9.05 5.126 9.075 5.25H5.1375L4.35 7.5H10.1625C10.6 7.975 11.1062 8.34375 11.6812 8.60625C12.2562 8.86875 12.8625 9 13.5 9Z" fill="white"/>
  </svg>
);

const FuelIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 18 18" fill="none">
    <path d="M12.1228 2L16 6V16H12.1228V12C8.24558 12 6.95318 9.33333 8.24558 4H2.42977V2M10.1842 4C8.89178 8 9.53798 10 12.1228 10L10.1842 4ZM3.39907 6C-1.44744 14 8.24558 14 3.39907 6V6Z" fill="white"/>
  </svg>
);

const BackArrowIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 20 20" fill="none">
    <path
      d="M9.16683 15H12.2918C13.4522 15 14.565 14.5391 15.3854 13.7186C16.2059 12.8981 16.6668 11.7853 16.6668 10.625C16.6668 9.46467 16.2059 8.35187 15.3854 7.5314C14.565 6.71093 13.4522 6.24999 12.2918 6.24999H4.16683M6.25016 3.33333L3.3335 6.24999L6.25016 9.16666"
      stroke="currentColor"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

const BackButton = styled.button`
  background: rgba(242, 242, 242, 0.10);
  border-radius: 0.25rem; /* 4px */
  border: none;
  opacity: 0.5;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.625rem; /* 10px */
  width: 2.375rem; /* 38px */
  height: 2.375rem; /* 38px */
  cursor: pointer;
  transition: ${props => props.theme.transitions.fast};

  &:hover {
    opacity: 0.8;
  }

  svg {
    width: 1.25rem; /* 20px */
    height: 1.25rem; /* 20px */
    flex-shrink: 0;
    aspect-ratio: 1/1;
    color: ${props => props.theme.colors.text.primary};
  }
`;

const VehicleImage = styled.img`
  align-self: stretch;
  height: 10.375rem;
  object-fit: contain;
  padding: 1rem;
`;

const PlateContainer = styled.div`
  display: flex;
  padding: 0 0.3125rem; /* 5px */
  justify-content: center;
  align-items: center;
  gap: 0.625rem; /* 10px */
  border-radius: 0.25rem; /* 4px */
  background: #F2F2F2;
  align-self: center;
`;

const PlateText = styled.div`
  color: #161616;
  text-shadow: 0 2px 0 #A2A2A2; /* x:0 y:2 blur:0 spread:0 */
  font-family: ${props => props.theme.fonts.primary};
  font-size: 2rem; /* 32px */
  font-style: normal;
  font-weight: ${props => props.theme.fonts.weights.bold};
  line-height: normal;
`;

const VehicleInfo = styled.div`
  display: flex;
  flex-direction: column;
  gap: 0.625rem;
  align-self: stretch;
`;

const StatRow = styled.div`
  display: flex;
  flex-direction: column;
  gap: 0.3125rem;
`;

const StatHeader = styled.div`
  display: flex;
  justify-content: space-between;
  align-items: center;
`;

const StatLabel = styled.div`
  display: flex;
  gap: 0.625rem;
  align-items: center;
  color: #F2F2F2;
  font-family: ${props => props.theme.fonts.primary};
  font-size: 0.875rem; /* 14px */
  font-style: normal;
  font-weight: 500;
  line-height: 1; /* 100% */
  letter-spacing: 0;
  min-width: 4.25rem; /* 68px */
  height: 1.3125rem; /* 21px */

  svg {
    flex-shrink: 0;
  }
`;

const StatValue = styled.div`
  color: #F2F2F2;
  font-family: ${props => props.theme.fonts.primary};
  font-size: 0.625rem; /* 10px */
  font-style: normal;
  font-weight: ${props => props.theme.fonts.weights.bold};
  line-height: normal;
`;

const ProgressBar = styled.div`
  display: flex;
  height: 0.875rem; /* 14px */
  width: 20rem; /* 320px */
  align-items: center;
  gap: 0.625rem; /* 10px */
  align-self: stretch;
  border-radius: 0.125rem; /* 2px */
  background: rgba(242, 242, 242, 0.10);
  overflow: hidden;
`;

const ProgressFill = styled.div<{ $percent: number; $color?: string }>`
  height: 100%;
  align-self: stretch;
  width: ${props => props.$percent}%;
  max-width: 100%;
  border-radius: 0.125rem; /* 2px */
  background: ${props => props.$color || '#FB9B04'};
  transition: width 0.3s ease;
`;

const ActionsSection = styled.div`
  display: flex;
  flex-direction: column;
  gap: 0.625rem;
  align-self: stretch;
`;

const ActionsHeader = styled.div`
  display: flex;
  gap: 0.3125rem;
  align-items: center;
  color: ${props => props.theme.colors.text.primary};
  font-size: 0.875rem;
  font-weight: ${props => props.theme.fonts.weights.bold};

  svg {
    width: 1rem;
    height: 1rem;
  }
`;

const ActionButton = styled.button<{ $primary?: boolean }>`
  display: flex;
  height: 2.5rem; /* 40px */
  padding: 0 0.625rem; /* 0 10px */
  justify-content: center;
  align-items: center;
  gap: 0.625rem; /* 10px */
  align-self: stretch;
  border-radius: 0 0 0.125rem 0.125rem; /* 0 0 2px 2px */
  background: ${props => props.$primary
    ? props.theme.colors.primary
    : 'rgba(242, 242, 242, 0.10)'};
  border: 1px solid transparent;
  color: ${props => props.$primary
    ? props.theme.colors.background
    : props.theme.colors.text.primary};
  font-size: 0.75rem;
  font-weight: ${props => props.theme.fonts.weights.bold};
  text-transform: uppercase;
  cursor: pointer;
  transition: ${props => props.theme.transitions.fast};

  &:hover {
    background: ${props => props.$primary
      ? props.theme.colors.button.primaryHover
      : 'rgba(242, 242, 242, 0.15)'};
  }
`;

const SpawnButton = styled(ActionButton)`
  align-self: stretch;
`;

interface VehicleDetailsProps {
  vehicle: Vehicle;
  onClose: () => void;
}

export const VehicleDetails: React.FC<VehicleDetailsProps> = ({ vehicle, onClose }) => {
  const { setLoading } = useGarageStore();

  const handleSpawn = async () => {
    setLoading(true);
    try {
      await fetchNui(NuiCallbackType.RETRIEVE_VEHICLE, { vehicleId: vehicle.id });
      onClose();
    } finally {
      setLoading(false);
    }
  };

  const handleGiveKeys = async () => {
    await fetchNui(NuiCallbackType.GIVE_KEYS, { vehicleId: vehicle.id });
  };

  const handleRename = async () => {
    const newName = prompt('Enter new vehicle name:', vehicle.customName || vehicle.name);
    if (newName) {
      await fetchNui(NuiCallbackType.RENAME_VEHICLE, {
        vehicleId: vehicle.id,
        name: newName
      });
    }
  };

  const handleTransfer = async () => {
    const playerId = prompt('Enter player ID to transfer vehicle:');
    if (playerId) {
      await fetchNui(NuiCallbackType.TRANSFER_VEHICLE, {
        vehicleId: vehicle.id,
        targetId: playerId
      });
    }
  };

  return (
    <DetailsContainer
      initial={{ x: -360, opacity: 0 }}
      animate={{ x: 0, opacity: 1 }}
      exit={{ x: -360, opacity: 0 }}
      transition={{
        duration: 0.6,
        ease: [0.34, 1.3, 0.64, 1]
      }}
    >
      <VehicleHeader>
        <HeaderRow>
          <VehicleName>{vehicle.customName || vehicle.name}</VehicleName>
          <BackButton onClick={onClose}>
            <BackArrowIcon />
          </BackButton>
        </HeaderRow>
        <VehicleImage
          src={vehicle.image || getVehicleImagePath(vehicle.model)}
          alt={vehicle.name}
          onError={(e) => {
            e.currentTarget.src = './vehicleImages/fallback.webp';
          }}
        />
      </VehicleHeader>

      <PlateContainer>
        <PlateText>{vehicle.plate}</PlateText>
      </PlateContainer>

      <VehicleInfo>
        <StatRow>
          <StatHeader>
            <StatLabel>
              <EngineIcon />
              Engine Health
            </StatLabel>
            <StatValue>{vehicle.engine}%</StatValue>
          </StatHeader>
          <ProgressBar>
            <ProgressFill $percent={vehicle.engine ?? 0} />
          </ProgressBar>
        </StatRow>

        <StatRow>
          <StatHeader>
            <StatLabel>
              <BodyIcon />
              Body Health
            </StatLabel>
            <StatValue>{vehicle.body}%</StatValue>
          </StatHeader>
          <ProgressBar>
            <ProgressFill $percent={vehicle.body ?? 0} />
          </ProgressBar>
        </StatRow>

        <StatRow>
          <StatHeader>
            <StatLabel>
              <FuelIcon />
              Fuel Level
            </StatLabel>
            <StatValue>{vehicle.fuel}%</StatValue>
          </StatHeader>
          <ProgressBar>
            <ProgressFill $percent={vehicle.fuel ?? 0} />
          </ProgressBar>
        </StatRow>
      </VehicleInfo>

      <ActionsSection>
        <ActionsHeader>
          <MdSettings />
          Vehicle Actions
        </ActionsHeader>
        <ActionButton $primary onClick={handleGiveKeys}>
          Give Keys
        </ActionButton>
        <ActionButton onClick={handleRename}>
          Rename Vehicle
        </ActionButton>
        <ActionButton onClick={handleTransfer}>
          Transfer Vehicle
        </ActionButton>
      </ActionsSection>

      <SpawnButton onClick={handleSpawn}>
        Spawn Vehicle
      </SpawnButton>
    </DetailsContainer>
  );
};