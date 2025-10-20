import type { LocaleTranslations } from '@/types/locale.types';

export const de: LocaleTranslations = {
  garage: {
    title: 'Garage',
    subtitle: 'Fahrzeugverwaltung',
    search: 'Suche nach Kennzeichen, Modell oder Name...',
    noVehicles: 'Keine Fahrzeuge gefunden',
    loading: 'Lädt Fahrzeuge...'
  },
  vehicle: {
    stored: 'Eingelagert',
    out: 'Ausgeparkt',
    impounded: 'Beschlagnahmt',
    retrieve: 'Ausparken',
    store: 'Einparken',
    payImpound: 'Gebühr bezahlen',
    favorite: 'Favorit',
    rename: 'Umbenennen',
    details: 'Details',
    mileage: 'Kilometerstand',
    fuel: 'Kraftstoff',
    engine: 'Motor',
    body: 'Karosserie',
    plate: 'Kennzeichen',
    customName: 'Eigener Name'
  },
  filters: {
    all: 'Alle',
    car: 'Auto',
    motorcycle: 'Motorrad',
    boat: 'Boot',
    aircraft: 'Flugzeug',
    bicycle: 'Fahrrad',
    truck: 'LKW',
    emergency: 'Einsatzfahrzeug',
    showStored: 'Eingelagert',
    showOut: 'Ausgeparkt',
    showImpounded: 'Beschlagnahmt',
    showFavorites: 'Favoriten'
  },
  stats: {
    total: 'Gesamt',
    stored: 'Eingelagert',
    out: 'Ausgeparkt',
    impounded: 'Beschlagnahmt'
  },
  actions: {
    close: 'Schließen',
    confirm: 'Bestätigen',
    cancel: 'Abbrechen',
    save: 'Speichern',
    delete: 'Löschen',
    reset: 'Zurücksetzen'
  },
  notifications: {
    vehicleRetrieved: 'Fahrzeug wurde ausgeparkt',
    vehicleStored: 'Fahrzeug wurde eingeparkt',
    vehicleRenamed: 'Fahrzeug wurde umbenannt',
    impoundPaid: 'Beschlagnahmungsgebühr wurde bezahlt',
    favoriteAdded: 'Zu Favoriten hinzugefügt',
    favoriteRemoved: 'Von Favoriten entfernt',
    error: 'Ein Fehler ist aufgetreten',
    noSpawnPoints: 'Keine freien Stellplätze verfügbar',
    notEnoughMoney: 'Nicht genug Geld'
  }
};
