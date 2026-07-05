import { fetchNui } from "./fetchNUI";
import { uiState } from "../stores/user.svelte";
import type { Vehicle } from "../../tabs/players/types/vehicle";
import type { Ban } from "../../tabs/players/types/ban";
import type { ServerState } from "../types/server";

// Callback response type
export type NuiSuccess = {
	success: boolean;
	playerOnline?: boolean;
	err?: string;
	message?: string;
	serverData?: ServerState;
};

type VehiclePageResponse = NuiSuccess & {
	vehicles?: Vehicle[];
	hasMore?: boolean;
	nextOffset?: number;
};

type BanPageResponse = NuiSuccess & {
	bans?: Ban[];
	hasMore?: boolean;
	nextOffset?: number;
};

export type RadioPlayer = {
	id: number;
	name: string;
	char_identifier?: string | null;
};

type RadioPlayersResponse = NuiSuccess & {
	players?: RadioPlayer[];
};

const VEHICLE_PAGE_SIZE = 100;
const BAN_PAGE_SIZE = 100;

// Admin Actions
export const bringPlayer = (playerId: number) => fetchNui<NuiSuccess>("bring", { id: playerId });

export const gotoPlayer = (playerId: number) => fetchNui<NuiSuccess>("goto", { id: playerId });

export const spectatePlayer = async (playerId: number) => {
	const res = await fetchNui<NuiSuccess>("spectate", { id: playerId });

	if (res?.success) {
		uiState.spectate();
	}
};

export const stopSpectate = (bool: boolean) => {
	if (bool) {
		uiState.stopSpectate();
	}
};

export const kickPlayer = async (playerId: number, reason?: string) => {
	const res = await fetchNui<NuiSuccess>("kick", { id: playerId, reason });

	if (res && !res.playerOnline) {
		uiState.removePlayer(playerId);
	}
};

export const banPlayer = async (playerId: number, reason?: string, duration?: number) => {
	const res = await fetchNui<NuiSuccess>("ban", { id: playerId, reason, duration });

	if (res && !res.playerOnline) {
		uiState.removePlayer(playerId);
	}
};

export const banOfflinePlayer = async (identifier: string, reason: string, duration?: number) => {
	const res = await fetchNui<NuiSuccess>("ban:offline", { identifier, reason, duration });

	return res?.success ?? false;
};

export const changeBanExpiry = async (identifier: string, newDate?: number | null) => {
	const res = await fetchNui<NuiSuccess>("ban:changeExpiry", { identifier, newDate });

	if (res?.success) {
		uiState.updateBanExpiry(identifier, newDate);
	}
};

export const revokeBan = async (identifier: string) => {
	const res = await fetchNui<NuiSuccess>("ban:revoke", { identifier });

	if (res?.success) {
		uiState.removeBan(identifier);
	}
};

export const impoundVehicle = async (plate: string, impoundName: string) => {
	const res = await fetchNui<NuiSuccess>("vehicle:impound", { plate, impoundName });

	if (res?.success) {
		uiState.updateVehicleImpoundState(plate, true);
	}
};

export const unimpoundVehicle = async (plate: string) => {
	const res = await fetchNui<NuiSuccess>("vehicle:unimpound", { plate });

	if (res?.success) {
		uiState.updateVehicleImpoundState(plate, false);
	}
};

export const deleteVehicle = async (plate: string) => {
	const res = await fetchNui<NuiSuccess>("vehicle:delete", { plate });

	if (res?.success) {
		uiState.removeVehicle(plate);
	}
};

export const notifyPlayer = (playerId: number, message: string) => {
	return fetchNui<NuiSuccess>("player:notify", {
		id: playerId,
		notificationContent: message,
		notificationType: "info",
	});
};

export const runPlayerAction = (playerId: number | string | undefined, action: string, payload: Record<string, unknown> = {}) => {
	return fetchNui<NuiSuccess>("player:action", {
		id: playerId,
		action,
		payload,
	});
};

export const fetchVehiclePage = async (options: { reset?: boolean; search?: string } = {}) => {
	if (uiState.vehicleLoading) return false;
	if (!options.reset && !uiState.vehicleHasMore) return false;

	uiState.vehicleLoading = true;

	try {
		const res = await fetchNui<VehiclePageResponse>("getVehicles", {
			offset: options.reset ? 0 : uiState.vehicleNextOffset,
			limit: VEHICLE_PAGE_SIZE,
			search: options.search ?? "",
		});

		if (!res?.success) return false;

		const vehicles = res.vehicles ?? [];
		const hasMore = res.hasMore ?? false;
		const nextOffset = res.nextOffset ?? (options.reset ? vehicles.length : uiState.vehicleNextOffset + vehicles.length);

		if (options.reset) {
			uiState.setVehiclePage(vehicles, hasMore, nextOffset);
		} else {
			uiState.appendVehiclePage(vehicles, hasMore, nextOffset);
		}

		return true;
	} finally {
		uiState.vehicleLoading = false;
	}
};

export const fetchBanPage = async (options: { reset?: boolean } = {}) => {
	if (uiState.banLoading) return false;
	if (!options.reset && !uiState.banHasMore) return false;

	uiState.banLoading = true;

	try {
		const res = await fetchNui<BanPageResponse>("getBans", {
			offset: options.reset ? 0 : uiState.banNextOffset,
			limit: BAN_PAGE_SIZE,
		});

		if (!res?.success) return false;

		const bans = res.bans ?? [];
		const hasMore = res.hasMore ?? false;
		const nextOffset = res.nextOffset ?? (options.reset ? bans.length : uiState.banNextOffset + bans.length);

		if (options.reset) {
			uiState.setBanPage(bans, hasMore, nextOffset);
		} else {
			uiState.appendBanPage(bans, hasMore, nextOffset);
		}

		return true;
	} finally {
		uiState.banLoading = false;
	}
};

export const runServerAction = (action: string, payload: Record<string, unknown> = {}) => {
	return fetchNui<NuiSuccess>("server:action", { action, payload });
};

export const runAdminMenuAction = (action: string, payload: Record<string, unknown> = {}) => {
	return fetchNui<NuiSuccess & { active?: boolean; value?: string }>(`adminMenu:${action}`, payload);
};

export const getRadioChannelPlayers = async (channel: number) => {
	const res = await fetchNui<RadioPlayersResponse>("server:radioPlayers", { channel });

	return res?.success ? (res.players ?? []) : [];
};

// For requesting players (Don't think it is needed but will keep it here)
// export const requestPlayers = () => fetchNui("requestPlayers");
