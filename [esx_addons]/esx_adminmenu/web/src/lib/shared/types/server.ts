/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

export interface ServerEnvironmentState {
  weather: string;
  hour: number;
  minute: number;
  blackout: boolean;
  pvp: boolean;
  densityEnabled: boolean;
  pedDensity: number;
  vehicleDensity: number;
  randomVehicleDensity: number;
}

export interface ServerState {
  currentPlayers: number;
  maxPlayers: number;
  uptimeSeconds: number;
  uptimeFormatted: string;
  environment?: Partial<ServerEnvironmentState>;
}
