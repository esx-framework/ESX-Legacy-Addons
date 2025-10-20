export type LocaleCode = 'de' | 'en' | 'fr' | 'es' | 'pl' | 'ru';

export interface Locale {
  code: LocaleCode;
  name: string;
  translations: LocaleTranslations;
}

export interface LocaleTranslations {
  garage: {
    title: string;
    subtitle: string;
    search: string;
    noVehicles: string;
    loading: string;
  };
  vehicle: {
    stored: string;
    out: string;
    impounded: string;
    retrieve: string;
    store: string;
    payImpound: string;
    favorite: string;
    rename: string;
    details: string;
    mileage: string;
    fuel: string;
    engine: string;
    body: string;
    plate: string;
    customName: string;
  };
  filters: {
    all: string;
    car: string;
    motorcycle: string;
    boat: string;
    aircraft: string;
    bicycle: string;
    truck: string;
    emergency: string;
    showStored: string;
    showOut: string;
    showImpounded: string;
    showFavorites: string;
  };
  stats: {
    total: string;
    stored: string;
    out: string;
    impounded: string;
  };
  actions: {
    close: string;
    confirm: string;
    cancel: string;
    save: string;
    delete: string;
    reset: string;
  };
  notifications: {
    vehicleRetrieved: string;
    vehicleStored: string;
    vehicleRenamed: string;
    impoundPaid: string;
    favoriteAdded: string;
    favoriteRemoved: string;
    error: string;
    noSpawnPoints: string;
    notEnoughMoney: string;
  };
}
