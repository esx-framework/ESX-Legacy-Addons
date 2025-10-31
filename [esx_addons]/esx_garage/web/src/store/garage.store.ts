import { create } from 'zustand';
import { devtools } from 'zustand/middleware';
import { immer } from 'zustand/middleware/immer';
import type { Vehicle, VehicleFilter, VehicleStats } from '@/types/vehicle.types';
import type { Garage } from '@/types/garage.types';
import { fetchNui } from '@/utils/nui';
import { NuiCallbackType } from '@/types/nui.types';

interface GarageState {
  // UI State
  isOpen: boolean;
  isLoading: boolean;

  // Data
  selectedGarage: Garage | null;
  selectedVehicle: Vehicle | null;
  vehicles: Vehicle[];
  filter: VehicleFilter;

  // Stats
  stats: VehicleStats;

  // Actions
  setOpen: (open: boolean) => void;
  setLoading: (loading: boolean) => void;
  selectGarage: (garage: Garage) => void;
  selectVehicle: (vehicle: Vehicle | null) => void;
  updateVehicles: (vehicles: Vehicle[]) => void;
  setFilter: (filter: Partial<VehicleFilter>) => void;
  resetFilter: () => void;

  // Vehicle Actions
  retrieveVehicle: (vehicleId: string) => Promise<void>;
  storeVehicle: (vehicleId: string) => Promise<void>;
  renameVehicle: (vehicleId: string, newName: string) => Promise<void>;
  toggleFavorite: (vehicleId: string) => Promise<void>;

  // Computed
  getFilteredVehicles: () => Vehicle[];
  updateStats: () => void;
}

const defaultFilter: VehicleFilter = {
  search: '',
  type: 'all',
  stored: 'all',
  impounded: 'all',
  favorite: 'all',
};

export const useGarageStore = create<GarageState>()(
  devtools(
    immer((set, get) => ({
      // Initial state
      isOpen: false,
      isLoading: false,
      selectedGarage: null,
      selectedVehicle: null,
      vehicles: [],
      filter: defaultFilter,
      stats: {
        total: 0,
        stored: 0,
        out: 0,
        impounded: 0,
      },

      // UI Actions
      setOpen: (open) =>
        set((state) => {
          state.isOpen = open;
          if (!open) {
            // Reset state when closing
            state.selectedGarage = null;
            state.vehicles = [];
            state.filter = defaultFilter;
          }
        }),

      setLoading: (loading) =>
        set((state) => {
          state.isLoading = loading;
        }),

      selectGarage: (garage) =>
        set((state) => {
          state.selectedGarage = garage;
        }),

      selectVehicle: (vehicle) =>
        set((state) => {
          state.selectedVehicle = vehicle;
        }),

      updateVehicles: (vehicles) =>
        set((state) => {
          state.vehicles = vehicles;
          get().updateStats();
        }),

      setFilter: (filter) =>
        set((state) => {
          state.filter = { ...state.filter, ...filter };
        }),

      resetFilter: () =>
        set((state) => {
          state.filter = defaultFilter;
        }),

      // Vehicle Actions
      retrieveVehicle: async (vehicleId) => {
        set((state) => {
          state.isLoading = true;
        });

        try {
          const result = await fetchNui<boolean>(
            NuiCallbackType.RETRIEVE_VEHICLE,
            { vehicleId },
            true // Mock success in dev
          );

          if (result) {
            set((state) => {
              const vehicle = state.vehicles.find((v) => v.id === vehicleId);
              if (vehicle) {
                vehicle.stored = false;
                vehicle.garage = undefined;
              }
            });
            get().updateStats();
          }
        } catch (error) {
          console.error('Failed to retrieve vehicle:', error);
        } finally {
          set((state) => {
            state.isLoading = false;
          });
        }
      },

      storeVehicle: async (vehicleId) => {
        set((state) => {
          state.isLoading = true;
        });

        try {
          const result = await fetchNui<boolean>(
            NuiCallbackType.STORE_VEHICLE,
            { vehicleId, garageId: get().selectedGarage?.id },
            true // Mock success in dev
          );

          if (result) {
            set((state) => {
              const vehicle = state.vehicles.find((v) => v.id === vehicleId);
              if (vehicle) {
                vehicle.stored = true;
                vehicle.garage = state.selectedGarage?.id;
              }
            });
            get().updateStats();
          }
        } catch (error) {
          console.error('Failed to store vehicle:', error);
        } finally {
          set((state) => {
            state.isLoading = false;
          });
        }
      },

      renameVehicle: async (vehicleId, newName) => {
        try {
          const result = await fetchNui<boolean>(
            NuiCallbackType.RENAME_VEHICLE,
            { vehicleId, newName },
            true // Mock success in dev
          );

          if (result) {
            set((state) => {
              const vehicle = state.vehicles.find((v) => v.id === vehicleId);
              if (vehicle) {
                vehicle.customName = newName;
              }
            });
          }
        } catch (error) {
          console.error('Failed to rename vehicle:', error);
        }
      },

      toggleFavorite: async (vehicleId) => {
        try {
          const vehicle = get().vehicles.find((v) => v.id === vehicleId);
          if (!vehicle) return;

          const newFavoriteStatus = !vehicle.isFavorite;

          const result = await fetchNui<boolean>(
            NuiCallbackType.TOGGLE_FAVORITE,
            { vehicleId, isFavorite: newFavoriteStatus },
            true // Mock success in dev
          );

          if (result) {
            set((state) => {
              const vehicle = state.vehicles.find((v) => v.id === vehicleId);
              if (vehicle) {
                vehicle.isFavorite = newFavoriteStatus;
              }
            });
          }
        } catch (error) {
          console.error('Failed to toggle favorite:', error);
        }
      },

      // Computed
      getFilteredVehicles: () => {
        const state = get();
        let filtered = [...state.vehicles];

        // Search filter
        if (state.filter.search) {
          const search = state.filter.search.toLowerCase();
          filtered = filtered.filter(
            (v) =>
              v.name.toLowerCase().includes(search) ||
              v.customName?.toLowerCase().includes(search) ||
              v.plate.toLowerCase().includes(search) ||
              v.model.toLowerCase().includes(search)
          );
        }

        // Type filter
        if (state.filter.type && state.filter.type !== 'all') {
          filtered = filtered.filter((v) => v.type === state.filter.type);
        }

        // Stored filter
        if (state.filter.stored !== 'all') {
          filtered = filtered.filter((v) => v.stored === state.filter.stored);
        }

        // Impounded filter
        if (state.filter.impounded !== 'all') {
          filtered = filtered.filter((v) => v.impounded === state.filter.impounded);
        }

        // Favorite filter
        if (state.filter.favorite !== 'all') {
          filtered = filtered.filter((v) => v.isFavorite === state.filter.favorite);
        }

        // Sort: Favorites first, then by last used
        filtered.sort((a, b) => {
          if (a.isFavorite && !b.isFavorite) return -1;
          if (!a.isFavorite && b.isFavorite) return 1;
          return (b.lastUsed || 0) - (a.lastUsed || 0);
        });

        return filtered;
      },

      updateStats: () =>
        set((state) => {
          const vehicles = state.vehicles;
          state.stats = {
            total: vehicles.length,
            stored: vehicles.filter((v) => v.stored && !v.impounded).length,
            out: vehicles.filter((v) => !v.stored && !v.impounded).length,
            impounded: vehicles.filter((v) => v.impounded).length,
          };
        }),
    }))
  )
);
