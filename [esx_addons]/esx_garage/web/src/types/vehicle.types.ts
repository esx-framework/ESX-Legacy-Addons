export interface Vehicle {
  id: string;
  plate: string;
  model: string;
  name: string;
  type: VehicleType;
  stored: boolean;
  garage?: string;
  impounded: boolean;
  impoundFee?: number;
  mileage: number;
  fuel?: number;
  engine?: number;
  body?: number;
  image?: string;
  isFavorite?: boolean;
  customName?: string;
  lastUsed?: number;
  props?: VehicleProps;
}

export const VehicleType = {
  CAR: 'car',
  MOTORCYCLE: 'motorcycle',
  BOAT: 'boat',
  AIRCRAFT: 'aircraft',
  BICYCLE: 'bicycle',
  TRUCK: 'truck',
  EMERGENCY: 'emergency',
} as const;

export type VehicleType = (typeof VehicleType)[keyof typeof VehicleType];

export interface VehicleProps {
  color1?: number[];
  color2?: number[];
  pearlescentColor?: number;
  wheelColor?: number;
  wheels?: number;
  windowTint?: number;
  neonEnabled?: boolean[];
  neonColor?: number[];
  extras?: Record<string, boolean>;
  modSpoilers?: number;
  modFrontBumper?: number;
  modRearBumper?: number;
  modSideSkirt?: number;
  modExhaust?: number;
  modEngine?: number;
  modBrakes?: number;
  modTransmission?: number;
  modSuspension?: number;
  modArmor?: number;
  modTurbo?: boolean;
}

export interface VehicleFilter {
  search: string;
  type?: VehicleType | 'all';
  stored?: boolean | 'all';
  impounded?: boolean | 'all';
  favorite?: boolean | 'all';
}

export interface VehicleStats {
  total: number;
  stored: number;
  out: number;
  impounded: number;
}
