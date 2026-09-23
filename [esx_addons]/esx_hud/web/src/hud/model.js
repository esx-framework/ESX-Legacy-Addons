// SPDX-License-Identifier: GPL-3.0-only
export const STORAGE_KEY = "esx-hud:preferences:v2";
export const defaults = {
    scale: 1,
    opacity: 0.88,
    compact: false,
    contrast: false,
    reducedMotion: false,
    smartStatus: true,
    privacy: false,
    cinematic: false,
    Status: false,
    Vehicle: false,
    Weapon: false,
    Position: false,
    Voice: false,
    Money: false,
    Info: false,
    IndicatorSound: true,
    IndicatorSeatbeltSound: false,
    MinimapOnFoot: false,
    StatusPercent: false,
    CenterStatuses: true,
    Kmh: true,
};
export const clamp = (value, min = 0, max = 100) => Math.min(max, Math.max(min, Number(value) || 0));
export function sanitizePreferences(value = {}) {
    const result = {};
    if (!value || typeof value !== "object") return result;
    for (const key of Object.keys(defaults)) {
        if (typeof defaults[key] === "boolean" && typeof value[key] === "boolean") result[key] = value[key];
    }
    if (Number.isFinite(value.scale)) result.scale = clamp(value.scale, 0.75, 1.25);
    if (Number.isFinite(value.opacity)) result.opacity = clamp(value.opacity, 0.65, 1);
    return result;
}
export function loadPreferences(storage) {
    try {
        return sanitizePreferences(JSON.parse(storage.getItem(STORAGE_KEY) || "{}"));
    } catch {
        return {};
    }
}
export function fuelPercent(fuel) {
    return fuel?.maxLevel > 0 ? clamp((fuel.level / fuel.maxLevel) * 100) : 0;
}
export const initialHud = { playerId: "", onlinePlayers: 0, serverLogo: "", moneys: { bank: 0, money: 0 }, job: "", streetName: "", zoneName: "", heading: 0, gameTime: "", voice: { mic: false, radio: false, range: 2 }, weaponData: { use: false } };
export const initialVehicle = { show: false, speed: 0, rpm: 0, gear: 0, fuel: { level: 0, maxLevel: 100 }, damage: 100, mileage: 0, kmh: true, vehType: "LAND", defaultIndicators: {} };
export const statusItems = [
    ["healthBar", "heart", "health"],
    ["armorBar", "shield", "armor"],
    ["foodBar", "food", "food"],
    ["drinkBar", "drop", "water"],
    ["staminaBar", "bolt", "stamina"],
    ["oxygenBar", "lungs", "oxygen"],
];
export const statusColors = { healthBar: "#f2f2f2", armorBar: "#9dafff", foodBar: "#fb9b04", drinkBar: "#70c9e9", staminaBar: "#d5e6a5", oxygenBar: "#70c9e9" };
