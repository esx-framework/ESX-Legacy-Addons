import type { LocaleTranslations } from '@/types/locale.types';

export const en: LocaleTranslations = {
  garage: {
    title: 'Garage',
    subtitle: 'Vehicle Management',
    search: 'Search by plate, model or name...',
    noVehicles: 'No vehicles found',
    loading: 'Loading vehicles...'
  },
  vehicle: {
    stored: 'Stored',
    out: 'Out',
    impounded: 'Impounded',
    retrieve: 'Retrieve',
    store: 'Store',
    payImpound: 'Pay Fee',
    favorite: 'Favorite',
    rename: 'Rename',
    details: 'Details',
    mileage: 'Mileage',
    fuel: 'Fuel',
    engine: 'Engine',
    body: 'Body',
    plate: 'Plate',
    customName: 'Custom Name'
  },
  filters: {
    all: 'All',
    car: 'Car',
    motorcycle: 'Motorcycle',
    boat: 'Boat',
    aircraft: 'Aircraft',
    bicycle: 'Bicycle',
    truck: 'Truck',
    emergency: 'Emergency',
    showStored: 'Stored',
    showOut: 'Out',
    showImpounded: 'Impounded',
    showFavorites: 'Favorites'
  },
  stats: {
    total: 'Total',
    stored: 'Stored',
    out: 'Out',
    impounded: 'Impounded'
  },
  actions: {
    close: 'Close',
    confirm: 'Confirm',
    cancel: 'Cancel',
    save: 'Save',
    delete: 'Delete',
    reset: 'Reset'
  },
  notifications: {
    vehicleRetrieved: 'Vehicle retrieved successfully',
    vehicleStored: 'Vehicle stored successfully',
    vehicleRenamed: 'Vehicle renamed successfully',
    impoundPaid: 'Impound fee paid successfully',
    favoriteAdded: 'Added to favorites',
    favoriteRemoved: 'Removed from favorites',
    error: 'An error occurred',
    noSpawnPoints: 'No available spawn points',
    notEnoughMoney: 'Not enough money'
  }
};
