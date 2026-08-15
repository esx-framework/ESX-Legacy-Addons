import type { Player } from "../../tabs/players/types/player";
import type { Ban } from "../../tabs/players/types/ban";
import { generateDummyPlayers, generateDummyBans, generateDummyVehicles } from "../util/generateDummyData";
import type { Vehicle } from "../../tabs/players/types/vehicle";
import { isChromium } from "../util/util";
import type { Impound } from "../types/impounds";

export type VehicleColorPreset = {
	id: string;
	label: string;
	primary: number;
	secondary?: number;
};

export type VehicleSpawnerConfig = {
	defaultModel: string;
	defaultColor: string;
	colorPresets: VehicleColorPreset[];
	neonPresets: Array<{ id: string; label: string; r: number; g: number; b: number }>;
	windowTints: Array<{ id: number; label: string }>;
	wheelCategories: Array<{ id: string; label: string; type: number }>;
	wheelDesigns: Array<{ id: number; label: string }>;
};

export const dummyImpounds: Record<string, Impound> = {
	city_impound: {
		getOutPoint: { x: 408.9, y: -1625.2, z: 29.3 },
		spawnPoint: { x: 401.2, y: -1631.5, z: 29.3, heading: 228.5 },
		sprite: 357,
		scale: 0.8,
		colour: 3,
		cost: 3000,
	},

	sandy_impound: {
		getOutPoint: { x: 1738.5, y: 3710.1, z: 34.1 },
		spawnPoint: { x: 1729.9, y: 3707.4, z: 34.2, heading: 21.2 },
		sprite: 357,
		scale: 0.8,
		colour: 5,
		cost: 2500,
	},

	paleto_impound: {
		getOutPoint: { x: -234.5, y: 6198.2, z: 31.5 },
		spawnPoint: { x: -230.1, y: 6205.6, z: 31.5, heading: 135.0 },
		sprite: 357,
		scale: 0.8,
		colour: 2,
		cost: 2000,
	},
};

export const dummyVehicleConfig: VehicleSpawnerConfig = {
	defaultModel: "sultan",
	defaultColor: "black",
	colorPresets: [
		{ id: "black", label: "Black", primary: 0, secondary: 0 },
		{ id: "white", label: "White", primary: 111, secondary: 111 },
		{ id: "red", label: "Red", primary: 27, secondary: 27 },
		{ id: "orange", label: "Orange", primary: 38, secondary: 38 },
		{ id: "blue", label: "Blue", primary: 64, secondary: 64 },
	],
	neonPresets: [
		{ id: "white", label: "White", r: 255, g: 255, b: 255 },
		{ id: "orange", label: "Orange", r: 251, g: 155, b: 4 },
		{ id: "red", label: "Red", r: 255, g: 32, b: 32 },
		{ id: "blue", label: "Blue", r: 32, g: 128, b: 255 },
	],
	windowTints: [
		{ id: 0, label: "None" },
		{ id: 1, label: "Pure Black" },
		{ id: 2, label: "Dark Smoke" },
		{ id: 3, label: "Light Smoke" },
		{ id: 4, label: "Stock" },
		{ id: 5, label: "Limo" },
	],
	wheelCategories: [
		{ id: "sport", label: "Sport", type: 0 },
		{ id: "muscle", label: "Muscle", type: 1 },
		{ id: "lowrider", label: "Lowrider", type: 2 },
		{ id: "suv", label: "SUV", type: 3 },
		{ id: "offroad", label: "Offroad", type: 4 },
		{ id: "tuner", label: "Tuner", type: 5 },
		{ id: "bike", label: "Bike", type: 6 },
		{ id: "highend", label: "High End", type: 7 },
		{ id: "street", label: "Street", type: 11 },
		{ id: "track", label: "Track", type: 12 },
	],
	wheelDesigns: [
		{ id: -1, label: "Stock" },
		...Array.from({ length: 20 }, (_, index) => ({ id: index, label: String(index + 1) })),
	],
};

export class UIState {
	visible = $state(!isChromium());
	mode = $state<"dashboard" | "menu">("dashboard");
	adminMenuStates = $state<Record<string, boolean>>({});
	adminMenuBadges = $state<Record<string, string>>({});
	spectating = $state(false);
	players = $state<Player[] | null>(isChromium() ? null : generateDummyPlayers(200));
	recentPlayers = $state<Player[] | null>(isChromium() ? null : generateDummyPlayers(20));
	focusPlayerId = $state<number | null>(null);
	bans = $state<Ban[] | null>(isChromium() ? null : generateDummyBans(200));
	banNextOffset = $state(isChromium() ? 0 : 200);
	banHasMore = $state(isChromium());
	banLoading = $state(false);
	vehicles = $state<Vehicle[] | null>(isChromium() ? null : generateDummyVehicles(200));
	vehicleNextOffset = $state(isChromium() ? 0 : 200);
	vehicleHasMore = $state(isChromium());
	vehicleLoading = $state(false);
	impounds = $state<Record<string, Impound> | null>(isChromium() ? null : dummyImpounds);
	vehicleConfig = $state<VehicleSpawnerConfig>(dummyVehicleConfig);

	openDashboard(players: Player[], focusPlayerId?: number | null) {
		this.visible = true;
		this.mode = "dashboard";
		this.spectating = false;
		this.players = players;
		this.focusPlayerId = focusPlayerId ?? null;
		this.bans = null;
		this.resetBans();
		this.resetVehicles();
	}

	open(players: Player[]) {
		this.openDashboard(players);
	}

	openMenu() {
		this.visible = true;
		this.mode = "menu";
		this.spectating = false;
	}

	setAdminMenuState(action: string, active: boolean) {
		this.adminMenuStates = { ...this.adminMenuStates, [action]: active };
	}

	setAdminMenuBadge(action: string, value?: string | null) {
		if (!value) return;
		this.adminMenuBadges = { ...this.adminMenuBadges, [action]: value };
	}

	close() {
		this.visible = false;
	}

	spectate() {
		this.spectating = true;
		this.visible = false;
	}

	stopSpectate() {
		this.spectating = false;
		this.visible = true;
		this.mode = "dashboard";
	}

	setPlayers(players: Player[]) {
		this.players = players;
	}

	setRecentPlayers(players: Player[]) {
		this.recentPlayers = players;
	}

	clearFocusPlayer() {
		this.focusPlayerId = null;
	}

	setVehicles(vehicles: Vehicle[]) {
		this.vehicles = vehicles;
	}

	setVehiclePage(vehicles: Vehicle[], hasMore: boolean, nextOffset: number) {
		this.vehicles = vehicles;
		this.vehicleHasMore = hasMore;
		this.vehicleNextOffset = nextOffset;
	}

	appendVehiclePage(vehicles: Vehicle[], hasMore: boolean, nextOffset: number) {
		this.vehicles = [...(this.vehicles ?? []), ...vehicles];
		this.vehicleHasMore = hasMore;
		this.vehicleNextOffset = nextOffset;
	}

	resetVehicles() {
		this.vehicles = null;
		this.vehicleNextOffset = 0;
		this.vehicleHasMore = true;
		this.vehicleLoading = false;
	}

	setBans(bans: Ban[]) {
		this.bans = bans;
	}

	setBanPage(bans: Ban[], hasMore: boolean, nextOffset: number) {
		this.bans = bans;
		this.banHasMore = hasMore;
		this.banNextOffset = nextOffset;
	}

	appendBanPage(bans: Ban[], hasMore: boolean, nextOffset: number) {
		this.bans = [...(this.bans ?? []), ...bans];
		this.banHasMore = hasMore;
		this.banNextOffset = nextOffset;
	}

	resetBans() {
		this.bans = null;
		this.banNextOffset = 0;
		this.banHasMore = true;
		this.banLoading = false;
	}

	setImpounds(impounds: Record<string, Impound>) {
		this.impounds = impounds;
	}

	setVehicleConfig(config?: Partial<VehicleSpawnerConfig> | null) {
		if (!config) return;

		this.vehicleConfig = {
			defaultModel: config.defaultModel ?? dummyVehicleConfig.defaultModel,
			defaultColor: config.defaultColor ?? dummyVehicleConfig.defaultColor,
			colorPresets: config.colorPresets?.length ? config.colorPresets : dummyVehicleConfig.colorPresets,
			neonPresets: config.neonPresets?.length ? config.neonPresets : dummyVehicleConfig.neonPresets,
			windowTints: config.windowTints?.length ? config.windowTints : dummyVehicleConfig.windowTints,
			wheelCategories: config.wheelCategories?.length ? config.wheelCategories : dummyVehicleConfig.wheelCategories,
			wheelDesigns: config.wheelDesigns?.length ? config.wheelDesigns : dummyVehicleConfig.wheelDesigns,
		};
	}

	removePlayer(playerId: number) {
		if (!this.players) return;

		this.players = this.players.filter((p) => p.id !== playerId);
	}

	updateBanExpiry(identifier: string, newDate?: number | null) {
		if (!this.bans) return;

		this.bans = this.bans.map((b) => (b.identifier === identifier ? { ...b, expires_at: newDate } : b));
	}

	removeBan(identifier: string) {
		if (!this.bans) return;

		this.bans = this.bans.filter((b) => b.identifier !== identifier);
	}

	updateVehicleImpoundState(plate: string, state: boolean) {
		if (!this.vehicles) return;

		this.vehicles = this.vehicles.map((v) => (v.plate === plate ? { ...v, impounded: state } : v));
	}

	removeVehicle(plate: string) {
		if (!this.vehicles) return;

		this.vehicles = this.vehicles.filter((v) => v.plate !== plate);
	}
}

export const uiState = new UIState();
