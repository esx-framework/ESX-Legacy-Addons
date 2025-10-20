import React, { useState } from 'react';
import styled from 'styled-components';
import { MdGarage, MdClose, MdSearch } from 'react-icons/md';
import { GiHook } from 'react-icons/gi';
import { IoCarSport } from 'react-icons/io5';
import { useGarageStore } from '@/store/garage.store';
import { useNui } from '@/hooks/useNui';
import { useTranslation } from '@/hooks/useTranslation';

const HeaderContainer = styled.div`
  display: flex;
  flex-direction: row;
  align-items: center;
  width: 100%;
  padding: 1.5rem 1.25rem 0 1.25rem;
  height: 3.875rem;
`;

const GarageName = styled.div`
  display: flex;
  align-items: center;
  gap: 0.625rem;
  flex-shrink: 0;
  margin-right: auto;
`;

const GarageIcon = styled.div`
  background: ${props => props.theme.colors.primary};
  border-radius: ${props => props.theme.sizes.borderRadius.sm};
  width: 1.875rem;
  height: 1.875rem;
  display: flex;
  align-items: center;
  justify-content: center;

  svg {
    width: 1.25rem;
    height: 1.25rem;
    color: ${props => props.theme.colors.background};
  }
`;

const GarageTitle = styled.h2`
  color: ${props => props.theme.colors.text.primary};
  font-size: 1.5rem;
  font-weight: ${props => props.theme.fonts.weights.medium};
  margin: 0;
`;

const ControlsContainer = styled.div`
  display: flex;
  align-items: center;
  gap: 0.625rem;
  flex-shrink: 0;
`;

const CounterButton = styled.div<{ $variant?: 'primary' | 'danger' }>`
  background: ${props =>
    props.$variant === 'danger'
      ? props.theme.colors.button.dangerBg
      : props.theme.colors.button.secondary};
  border-radius: ${props => props.theme.sizes.borderRadius.lg};
  padding: 0 0.625rem 0 0.1875rem;
  height: 1.875rem;
  display: flex;
  align-items: center;
  gap: 0.3125rem;
  box-shadow: ${props => props.theme.colors.shadows.sm};
  cursor: pointer;
  transition: ${props => props.theme.transitions.fast};

  &:hover {
    opacity: ${props => props.theme.effects.opacity.hover};
  }
`;

const CounterIcon = styled.div<{ $variant?: 'primary' | 'danger' }>`
  background: ${props =>
    props.$variant === 'danger'
      ? props.theme.colors.secondary
      : props.theme.colors.primary};
  border-radius: 6.25rem;
  width: 1.5rem;
  height: 1.5rem;
  display: flex;
  align-items: center;
  justify-content: center;

  svg {
    width: 1rem;
    height: 1rem;
    color: ${props => props.theme.colors.background};
  }
`;

const CounterText = styled.span<{ $variant?: 'primary' | 'danger' }>`
  color: ${props =>
    props.$variant === 'danger'
      ? props.theme.colors.secondary
      : props.theme.colors.primary};
  font-size: 0.875rem;
  font-weight: ${props => props.theme.fonts.weights.bold};
`;

const SearchBar = styled.div`
  background: ${props => props.theme.colors.backgroundSecondary};
  border-radius: ${props => props.theme.sizes.borderRadius.sm};
  padding: 0.625rem;
  width: 21.875rem;
  height: 2.375rem;
  display: flex;
  align-items: center;
  gap: 0.625rem;
  opacity: ${props => props.theme.effects.opacity.disabled};
  transition: ${props => props.theme.transitions.fast};

  &:focus-within {
    opacity: 1;
    border: 1px solid ${props => props.theme.colors.primary};
  }
`;

const SearchInput = styled.input`
  flex: 1;
  background: transparent;
  border: none;
  color: ${props => props.theme.colors.text.primary};
  font-size: 1rem;
  font-weight: ${props => props.theme.fonts.weights.regular};
  outline: none;

  &::placeholder {
    color: ${props => props.theme.colors.text.disabled};
  }
`;

const CloseButton = styled.button`
  background: ${props => props.theme.colors.backgroundSecondary};
  border-radius: ${props => props.theme.sizes.borderRadius.sm};
  width: 2.375rem;
  height: 2.375rem;
  display: flex;
  align-items: center;
  justify-content: center;
  opacity: ${props => props.theme.effects.opacity.disabled};
  transition: ${props => props.theme.transitions.fast};

  svg {
    width: 1.25rem;
    height: 1.25rem;
    color: ${props => props.theme.colors.text.primary};
  }

  &:hover {
    opacity: 1;
    background: ${props => props.theme.colors.button.danger};
  }
`;

// Spacer removed - use margin-left: auto instead

export const GarageHeader: React.FC = () => {
  const { selectedGarage, stats, setFilter } = useGarageStore();
  const { close } = useNui();
  const { t } = useTranslation();
  const [searchValue, setSearchValue] = useState('');

  const handleSearch = (value: string) => {
    setSearchValue(value);
    setFilter({ search: value });
  };

  const handleClose = () => {
    close();
  };

  const handleStoredFilter = () => {
    setFilter({ stored: true, impounded: false });
  };

  const handleImpoundedFilter = () => {
    setFilter({ impounded: true });
  };

  return (
    <HeaderContainer>
      <GarageName>
        <GarageIcon>
          <MdGarage />
        </GarageIcon>
        <GarageTitle>{selectedGarage?.label || t('garage.title')}</GarageTitle>
      </GarageName>

      <ControlsContainer>
        <CounterButton onClick={handleStoredFilter}>
          <CounterIcon>
            <IoCarSport />
          </CounterIcon>
          <CounterText>{stats.stored}</CounterText>
        </CounterButton>

        <CounterButton $variant="danger" onClick={handleImpoundedFilter}>
          <CounterIcon $variant="danger">
            <GiHook />
          </CounterIcon>
          <CounterText $variant="danger">{stats.impounded}</CounterText>
        </CounterButton>

        <SearchBar>
          <MdSearch />
          <SearchInput
            type="text"
            placeholder={t('garage.search')}
            value={searchValue}
            onChange={(e) => handleSearch(e.target.value)}
          />
        </SearchBar>

        <CloseButton onClick={handleClose}>
          <MdClose />
        </CloseButton>
      </ControlsContainer>
    </HeaderContainer>
  );
};