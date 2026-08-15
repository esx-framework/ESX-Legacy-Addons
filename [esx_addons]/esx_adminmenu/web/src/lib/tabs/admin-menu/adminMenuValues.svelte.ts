import type { VehicleSpawnerConfig } from "$lib/shared/stores/user.svelte";

export type AdminMenuValueKey =
	| "spawnModel"
	| "spawnColor"
	| "spawnMaxPerformance"
	| "engineLevel"
	| "brakeLevel"
	| "transmissionLevel"
	| "suspensionLevel"
	| "armorLevel"
	| "turbo"
	| "xenon"
	| "neon"
	| "neonColor"
	| "vehicleColor"
	| "secondaryColor"
	| "windowTint"
	| "wheelCategory"
	| "wheelDesign"
	| "bulletproofTires";

export class AdminMenuValuesState {
	spawnModel = $state("");
	spawnColor = $state("");
	spawnMaxPerformance = $state(false);
	engineLevel = $state(1);
	brakeLevel = $state(1);
	transmissionLevel = $state(1);
	suspensionLevel = $state(1);
	armorLevel = $state(1);
	turbo = $state(false);
	xenon = $state(false);
	neon = $state(false);
	neonColor = $state("");
	vehicleColor = $state("");
	secondaryColor = $state("");
	windowTint = $state(0);
	wheelCategory = $state("");
	wheelDesign = $state(-1);
	bulletproofTires = $state(false);

	constructor(config: VehicleSpawnerConfig) {
		this.reset(config);
	}

	reset(config: VehicleSpawnerConfig) {
		this.spawnModel = config.defaultModel;
		this.spawnColor = config.defaultColor;
		this.spawnMaxPerformance = false;
		this.engineLevel = 1;
		this.brakeLevel = 1;
		this.transmissionLevel = 1;
		this.suspensionLevel = 1;
		this.armorLevel = 1;
		this.turbo = false;
		this.xenon = false;
		this.neon = false;
		this.neonColor = config.neonPresets[0]?.id ?? "white";
		this.vehicleColor = config.defaultColor;
		this.secondaryColor = config.defaultColor;
		this.windowTint = config.windowTints[0]?.id ?? 0;
		this.wheelCategory = config.wheelCategories[0]?.id ?? "sport";
		this.wheelDesign = config.wheelDesigns[0]?.id ?? -1;
		this.bulletproofTires = false;
	}

	get(key: AdminMenuValueKey) {
		return this[key];
	}

	set(key: AdminMenuValueKey, value: string | number | boolean) {
		(this[key] as string | number | boolean) = value;
	}

	applyMaxPerformance() {
		this.engineLevel = 5;
		this.brakeLevel = 5;
		this.transmissionLevel = 5;
		this.suspensionLevel = 5;
		this.armorLevel = 5;
		this.turbo = true;
	}

	spawnPayload() {
		return {
			model: this.spawnModel,
			color: this.spawnColor,
			primaryColor: this.spawnColor,
			secondaryColor: this.spawnColor,
			maxPerformance: this.spawnMaxPerformance,
			deleteCurrent: true,
		};
	}

	customizationPayload() {
		return {
			engineLevel: this.engineLevel,
			brakeLevel: this.brakeLevel,
			transmissionLevel: this.transmissionLevel,
			suspensionLevel: this.suspensionLevel,
			armorLevel: this.armorLevel,
			turbo: this.turbo,
			xenon: this.xenon,
			neon: this.neon,
			neonColor: this.neonColor,
			color: this.vehicleColor,
			primaryColor: this.vehicleColor,
			secondaryColor: this.secondaryColor,
			windowTint: this.windowTint,
			wheelCategory: this.wheelCategory,
			wheelDesign: this.wheelDesign,
			bulletproofTires: this.bulletproofTires,
		};
	}
}
