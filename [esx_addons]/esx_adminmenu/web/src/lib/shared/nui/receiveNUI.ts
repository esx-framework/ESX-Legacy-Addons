/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

import type { ServerState } from "../types/server";
import type { Translations } from "../stores/translations.svelte";
import type { Player } from "../../tabs/players/types/player";
import type { VehicleSpawnerConfig } from "../stores/user.svelte";
import type { Impound } from "../types/impounds";

type InitResourceData = {
  translations: Translations;
  serverData: ServerState;
  impounds?: Record<string, Impound> | Impound[];
  vehicleConfig?: VehicleSpawnerConfig;
};

export type NuiMessage =
	| { action: "initResource"; data: InitResourceData }
	| { action: "openAdmin"; data: Player[] }
	| { action: "openAdminDashboard"; data: { players: Player[]; serverData?: ServerState; selectedPlayerId?: number; impounds?: Record<string, Impound> | Impound[] } }
	| { action: "openAdminMenu"; data?: { serverData?: ServerState; impounds?: Record<string, Impound> | Impound[] } }
	| { action: "updateServerData"; data: ServerState }
	| { action: "updatePlayers"; data: Player[] }
	| { action: "closeAdmin"; data?: undefined };

export function listenNui<T extends { action: string }>(
  handler: (message: T) => void
) {
  const listener = (event: MessageEvent<T>) => {
    if (!event.data?.action) return;
    handler(event.data);
  };

  window.addEventListener("message", listener);

  return () => window.removeEventListener("message", listener);
}
