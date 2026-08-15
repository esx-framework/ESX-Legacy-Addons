import type { VehicleSpawnerConfig } from "$lib/shared/stores/user.svelte";
import type { AdminMenuValueKey, AdminMenuValuesState } from "./adminMenuValues.svelte";

export type AdminMenuValues = AdminMenuValuesState;

export type AdminMenuOption = {
	value: string | number | boolean;
	label: string;
};

export type AdminMenuCategory = {
	id: string;
	labelKey: string;
	page: string;
};

export type AdminMenuItem =
	| { type: "section"; id: string; labelKey: string }
	| { type: "back"; id: string; labelKey: string; page: string }
	| { type: "page"; id: string; labelKey: string; page: string }
	| { type: "action"; id: string; labelKey: string; event: string; badge?: "toggle" | "value"; payload?: (values: AdminMenuValues) => Record<string, unknown> }
	| { type: "input"; id: string; labelKey: string; valueKey: AdminMenuValueKey; placeholder?: string; event?: string; payload?: (values: AdminMenuValues) => Record<string, unknown> }
	| {
			type: "option" | "toggle";
			id: string;
			labelKey: string;
			valueKey: AdminMenuValueKey;
			options?: AdminMenuOption[];
			event?: string;
			payload?: (values: AdminMenuValues) => Record<string, unknown>;
	  };

export type AdminMenuPage = {
	id: string;
	titleKey: string;
	subtitleKey: string;
	categoryId?: string;
	parentPage?: string;
	items: AdminMenuItem[];
};

export const adminMenuCategories: AdminMenuCategory[] = [
	{ id: "self", labelKey: "admin_menu_self", page: "self" },
	{ id: "vehicle", labelKey: "admin_menu_vehicle", page: "vehicle" },
	{ id: "utility", labelKey: "admin_menu_utility", page: "utility" },
];

export const defaultAdminMenuPage = adminMenuCategories[0]?.page ?? "self";

const levelOptions: AdminMenuOption[] = [1, 2, 3, 4, 5].map((value) => ({
	value,
	label: `${value}/5`,
}));

const item = {
	section(id: string, labelKey: string): AdminMenuItem {
		return { type: "section", id, labelKey };
	},
	back(page: string): AdminMenuItem {
		return { type: "back", id: "back", labelKey: "back", page };
	},
	page(id: string, labelKey: string, page: string): AdminMenuItem {
		return { type: "page", id, labelKey, page };
	},
	action(id: string, labelKey: string, event: string, options: Pick<Extract<AdminMenuItem, { type: "action" }>, "badge" | "payload"> = {}): AdminMenuItem {
		return { type: "action", id, labelKey, event, ...options };
	},
	input(id: string, labelKey: string, valueKey: AdminMenuValueKey, options: Pick<Extract<AdminMenuItem, { type: "input" }>, "placeholder" | "event" | "payload"> = {}): AdminMenuItem {
		return { type: "input", id, labelKey, valueKey, ...options };
	},
	option(
		id: string,
		labelKey: string,
		valueKey: AdminMenuValueKey,
		choices: AdminMenuOption[],
		event?: string,
		payload?: (values: AdminMenuValues) => Record<string, unknown>
	): AdminMenuItem {
		return { type: "option", id, labelKey, valueKey, options: choices, event, payload };
	},
	toggle(id: string, labelKey: string, valueKey: AdminMenuValueKey, event?: string, payload?: (values: AdminMenuValues) => Record<string, unknown>): AdminMenuItem {
		return { type: "toggle", id, labelKey, valueKey, event, payload };
	},
};

function customizationPayload(values: AdminMenuValues) {
	return values.customizationPayload();
}

export function createAdminMenuPages(config: VehicleSpawnerConfig): Record<string, AdminMenuPage> {
	const colorOptions = config.colorPresets.map((preset) => ({ value: preset.id, label: preset.label }));
	const neonOptions = config.neonPresets.map((preset) => ({ value: preset.id, label: preset.label }));
	const tintOptions = config.windowTints.map((tint) => ({ value: tint.id, label: tint.label }));
	const wheelCategoryOptions = config.wheelCategories.map((category) => ({ value: category.id, label: category.label }));
	const wheelDesignOptions = config.wheelDesigns.map((design) => ({ value: design.id, label: design.label }));

	return {
		root: {
			id: "root",
			titleKey: "admin_menu_self",
			subtitleKey: "quick_actions",
			categoryId: "self",
			items: [
				item.action("noclip", "noclip", "adminMenu:noclip", { badge: "toggle" }),
				item.action("names", "show_names", "adminMenu:names", { badge: "toggle" }),
				item.action("blips", "show_blips", "adminMenu:blips", { badge: "toggle" }),
				item.action("godmode", "godmode", "adminMenu:godmode", { badge: "toggle" }),
				item.action("invisible", "invisible", "adminMenu:invisible", { badge: "toggle" }),
				item.action("infiniteAmmo", "infinite_ammo", "adminMenu:infiniteAmmo", { badge: "toggle" }),
				item.action("revive", "revive", "adminMenu:revive"),
				item.action("heal", "heal", "adminMenu:heal"),
				item.action("armor", "armor", "adminMenu:armor"),
				item.action("waypoint", "teleport_waypoint", "adminMenu:waypoint"),
			],
		},
		self: {
			id: "self",
			titleKey: "admin_menu_self",
			subtitleKey: "quick_actions",
			categoryId: "self",
			items: [
				item.action("noclip", "noclip", "adminMenu:noclip", { badge: "toggle" }),
				item.action("names", "show_names", "adminMenu:names", { badge: "toggle" }),
				item.action("blips", "show_blips", "adminMenu:blips", { badge: "toggle" }),
				item.action("godmode", "godmode", "adminMenu:godmode", { badge: "toggle" }),
				item.action("invisible", "invisible", "adminMenu:invisible", { badge: "toggle" }),
				item.action("infiniteAmmo", "infinite_ammo", "adminMenu:infiniteAmmo", { badge: "toggle" }),
				item.action("revive", "revive", "adminMenu:revive"),
				item.action("heal", "heal", "adminMenu:heal"),
				item.action("armor", "armor", "adminMenu:armor"),
				item.action("waypoint", "teleport_waypoint", "adminMenu:waypoint"),
			],
		},
		vehicle: {
			id: "vehicle",
			titleKey: "admin_menu_vehicle",
			subtitleKey: "quick_actions",
			categoryId: "vehicle",
			items: [
				item.page("spawnVehiclePage", "spawn_vehicle", "spawn"),
				item.page("customizeVehiclePage", "customize_vehicle", "customize"),
				item.action("repair", "repair_vehicle", "adminMenu:repairVehicle"),
				item.action("clean", "clean_vehicle", "adminMenu:cleanVehicle"),
				item.action("flip", "flip_vehicle", "adminMenu:flipVehicle"),
				item.action("delete", "delete_current_vehicle", "adminMenu:deleteVehicle"),
			],
		},
		utility: {
			id: "utility",
			titleKey: "admin_menu_utility",
			subtitleKey: "quick_actions",
			categoryId: "utility",
			items: [
				item.action("copyCoords", "copy_coords", "adminMenu:copyCoords"),
			],
		},
		spawn: {
			id: "spawn",
			titleKey: "spawn_vehicle",
			subtitleKey: "vehicle_model",
			categoryId: "vehicle",
			parentPage: "vehicle",
			items: [
				item.input("spawnModel", "vehicle_model", "spawnModel", {
					placeholder: config.defaultModel,
					event: "adminMenu:spawnVehicle",
					payload: (values) => values.spawnPayload(),
				}),
				item.option("spawnColor", "vehicle_color", "spawnColor", colorOptions),
				item.toggle("spawnMaxPerformance", "spawn_tuned", "spawnMaxPerformance"),
			],
		},
		customize: {
			id: "customize",
			titleKey: "customize_vehicle",
			subtitleKey: "customize_vehicle_hint",
			categoryId: "vehicle",
			parentPage: "vehicle",
			items: [
				item.option("engineLevel", "engine_level", "engineLevel", levelOptions, "adminMenu:customizeVehicle", customizationPayload),
				item.option("brakeLevel", "brake_level", "brakeLevel", levelOptions, "adminMenu:customizeVehicle", customizationPayload),
				item.option("transmissionLevel", "transmission_level", "transmissionLevel", levelOptions, "adminMenu:customizeVehicle", customizationPayload),
				item.option("suspensionLevel", "suspension_level", "suspensionLevel", levelOptions, "adminMenu:customizeVehicle", customizationPayload),
				item.option("armorLevel", "vehicle_armor", "armorLevel", levelOptions, "adminMenu:customizeVehicle", customizationPayload),
				item.toggle("turbo", "turbo", "turbo", "adminMenu:customizeVehicle", customizationPayload),
				item.toggle("xenon", "xenon_lights", "xenon", "adminMenu:customizeVehicle", customizationPayload),
				item.toggle("neon", "neon_lights", "neon", "adminMenu:customizeVehicle", customizationPayload),
				item.option("neonColor", "neon_color", "neonColor", neonOptions, "adminMenu:customizeVehicle", customizationPayload),
				item.option("vehicleColor", "primary_color", "vehicleColor", colorOptions, "adminMenu:customizeVehicle", customizationPayload),
				item.option("secondaryColor", "secondary_color", "secondaryColor", colorOptions, "adminMenu:customizeVehicle", customizationPayload),
				item.option("windowTint", "window_tint", "windowTint", tintOptions, "adminMenu:customizeVehicle", customizationPayload),
				item.option("wheelCategory", "wheel_category", "wheelCategory", wheelCategoryOptions, "adminMenu:customizeVehicle", customizationPayload),
				item.option("wheelDesign", "wheel_design", "wheelDesign", wheelDesignOptions, "adminMenu:customizeVehicle", customizationPayload),
				item.toggle("bulletproofTires", "bulletproof_tires", "bulletproofTires", "adminMenu:customizeVehicle", customizationPayload),
				item.action("maxPerformance", "max_performance", "adminMenu:maxVehiclePerformance", { badge: "value" }),
			],
		},
	};
}
