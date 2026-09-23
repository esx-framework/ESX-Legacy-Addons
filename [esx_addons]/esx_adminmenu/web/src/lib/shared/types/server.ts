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
}

export interface ServerState {
  currentPlayers: number;
  maxPlayers: number;
  uptimeSeconds: number;
  uptimeFormatted: string;
  environment?: Partial<ServerEnvironmentState>;
}
