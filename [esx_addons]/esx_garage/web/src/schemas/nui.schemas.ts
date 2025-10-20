import { z } from 'zod';
import { VehicleType } from '@/types/vehicle.types';
import { GarageType } from '@/types/garage.types';

export const Vector3Schema = z.object({
  x: z.number(),
  y: z.number(),
  z: z.number(),
  h: z.number().optional()
});

export const VehiclePropsSchema = z.object({
  color1: z.array(z.number()).optional(),
  color2: z.array(z.number()).optional(),
  pearlescentColor: z.number().optional(),
  wheelColor: z.number().optional(),
  wheels: z.number().optional(),
  windowTint: z.number().optional(),
  neonEnabled: z.array(z.boolean()).optional(),
  neonColor: z.array(z.number()).optional(),
  extras: z.record(z.string(), z.boolean()).optional(),
  modSpoilers: z.number().optional(),
  modFrontBumper: z.number().optional(),
  modRearBumper: z.number().optional(),
  modSideSkirt: z.number().optional(),
  modExhaust: z.number().optional(),
  modEngine: z.number().optional(),
  modBrakes: z.number().optional(),
  modTransmission: z.number().optional(),
  modSuspension: z.number().optional(),
  modArmor: z.number().optional(),
  modTurbo: z.boolean().optional()
}).passthrough();

export const VehicleSchema = z.object({
  id: z.string(),
  plate: z.string(),
  model: z.string(),
  name: z.string(),
  type: z.enum([
    VehicleType.CAR,
    VehicleType.MOTORCYCLE,
    VehicleType.BOAT,
    VehicleType.AIRCRAFT,
    VehicleType.BICYCLE,
    VehicleType.TRUCK,
    VehicleType.EMERGENCY
  ]),
  stored: z.boolean(),
  garage: z.string().optional(),
  impounded: z.boolean(),
  impoundFee: z.number().optional(),
  mileage: z.number(),
  fuel: z.number().optional(),
  engine: z.number().optional(),
  body: z.number().optional(),
  image: z.string().optional(),
  isFavorite: z.boolean().optional(),
  customName: z.string().optional(),
  lastUsed: z.number().optional(),
  props: VehiclePropsSchema.optional()
});

export const GarageSchema = z.object({
  id: z.string(),
  name: z.string(),
  type: z.enum([
    GarageType.PUBLIC,
    GarageType.PRIVATE,
    GarageType.JOB,
    GarageType.GANG,
    GarageType.IMPOUND,
    GarageType.HOUSE,
    GarageType.AIRCRAFT,
    GarageType.BOAT
  ]),
  label: z.string(),
  coords: Vector3Schema.optional(),
  spawns: z.array(z.object({
    coords: Vector3Schema,
    occupied: z.boolean().optional()
  })).optional(),
  blip: z.object({
    sprite: z.number(),
    color: z.number(),
    scale: z.number(),
    display: z.number().optional(),
    shortRange: z.boolean().optional()
  }).optional(),
  job: z.string().optional(),
  gang: z.string().optional(),
  maxVehicles: z.number().optional()
});

export const OpenGarageDataSchema = z.object({
  garage: GarageSchema,
  vehicles: z.array(VehicleSchema)
});

export const NuiCallbackResponseSchema = z.object({
  success: z.boolean(),
  data: z.unknown().optional(),
  error: z.string().optional()
});

export const RetrieveVehicleDataSchema = z.object({
  vehicleId: z.string()
});

export const StoreVehicleDataSchema = z.object({
  vehicleId: z.string(),
  garageId: z.string().optional()
});

export const RenameVehicleDataSchema = z.object({
  vehicleId: z.string(),
  newName: z.string().min(1).max(50)
});

export const ToggleFavoriteDataSchema = z.object({
  vehicleId: z.string(),
  isFavorite: z.boolean()
});

export const GiveKeysDataSchema = z.object({
  vehicleId: z.string(),
  targetId: z.string()
});

export const TransferVehicleDataSchema = z.object({
  vehicleId: z.string(),
  targetId: z.string()
});

export const NotificationDataSchema = z.object({
  message: z.string(),
  type: z.enum(['success', 'error', 'info', 'warning']).optional().default('info')
});

export const LocaleDataSchema = z.enum(['de', 'en', 'fr', 'es', 'pl', 'ru']).default('en');

export const SetTranslationsDataSchema = z.record(z.string(), z.unknown());
