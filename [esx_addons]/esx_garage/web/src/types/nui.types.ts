export interface NuiMessage<T = unknown> {
  type: string;
  payload: T;
}

export interface NuiCallbackResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: string;
}

// NUI Event Types
export const NuiEventType = {
  // UI Control
  OPEN_GARAGE: 'openGarage',
  CLOSE_GARAGE: 'closeGarage',
  SET_VISIBLE: 'setVisible',

  // Data Updates
  UPDATE_VEHICLES: 'updateVehicles',
  UPDATE_GARAGE: 'updateGarage',

  // Actions
  RETRIEVE_VEHICLE: 'retrieveVehicle',
  STORE_VEHICLE: 'storeVehicle',
  RENAME_VEHICLE: 'renameVehicle',
  TOGGLE_FAVORITE: 'toggleFavorite',

  // Notifications
  SHOW_NOTIFICATION: 'showNotification',
  SHOW_ERROR: 'showError'
} as const;

export type NuiEventType = typeof NuiEventType[keyof typeof NuiEventType];

// NUI Callback Types
export const NuiCallbackType = {
  RETRIEVE_VEHICLE: 'garage:retrieveVehicle',
  STORE_VEHICLE: 'garage:storeVehicle',
  RENAME_VEHICLE: 'garage:renameVehicle',
  TOGGLE_FAVORITE: 'garage:toggleFavorite',
  GIVE_KEYS: 'garage:giveKeys',
  TRANSFER_VEHICLE: 'garage:transferVehicle',
  CLOSE_UI: 'garage:closeUI',
  SEARCH_VEHICLES: 'garage:searchVehicles'
} as const;

export type NuiCallbackType = typeof NuiCallbackType[keyof typeof NuiCallbackType];