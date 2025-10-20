export interface Garage {
  id: string;
  name: string;
  type: GarageType;
  label: string;
  coords?: Vector3;
  spawns?: SpawnPoint[];
  blip?: BlipConfig;
  job?: string;
  gang?: string;
  maxVehicles?: number;
}

export const GarageType = {
  PUBLIC: 'public',
  PRIVATE: 'private',
  JOB: 'job',
  GANG: 'gang',
  IMPOUND: 'impound',
  HOUSE: 'house',
  AIRCRAFT: 'aircraft',
  BOAT: 'boat'
} as const;

export type GarageType = typeof GarageType[keyof typeof GarageType];

export interface Vector3 {
  x: number;
  y: number;
  z: number;
  h?: number; // Heading
}

export interface SpawnPoint {
  coords: Vector3;
  occupied?: boolean;
}

export interface BlipConfig {
  sprite: number;
  color: number;
  scale: number;
  display?: number;
  shortRange?: boolean;
}