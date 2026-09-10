-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

WorkshopStats = {}

local STAT_RANGES = {
    speed = { field = 'fInitialDriveMaxFlatVel', min = 20.0, max = 55.0 },
    accel = { field = 'fInitialDriveForce', min = 0.10, max = 0.45 },
    brake = { field = 'fBrakeForce', min = 0.40, max = 1.60 },
    handling = { field = 'fTractionCurveMax', min = 1.80, max = 3.20 }
}

local function normalizeStat(value, min, max)
    if max <= min then return 0 end

    local pct = (value - min) / (max - min) * 100.0
    if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end

    return math.floor(pct + 0.5)
end

function WorkshopStats.CalcHandling(vehicle)
    if not DoesEntityExist(vehicle) then
        return { speed = 0, accel = 0, brake = 0, handling = 0 }
    end

    local stats = {}
    for key, data in pairs(STAT_RANGES) do
        stats[key] = normalizeStat(GetVehicleHandlingFloat(vehicle, 'CHandlingData', data.field), data.min, data.max)
    end

    return stats
end

function WorkshopStats.CalcModded(vehicle, base)
    local stats = {
        speed = base.speed,
        accel = base.accel,
        brake = base.brake,
        handling = base.handling
    }

    local gains = Config.Workshop and Config.Workshop.StatGains or {}
    for modKey, modGains in pairs(gains) do
        local menu = Config.Menus[modKey]
        local factor = 0.0

        if menu and menu.modType then
            if modKey == 'modTurbo' then
                factor = IsToggleModOn(vehicle, 18) and 1.0 or 0.0
            else
                local maxLevel = GetNumVehicleMods(vehicle, menu.modType)
                local currentLevel = GetVehicleMod(vehicle, menu.modType)

                if maxLevel > 0 and currentLevel >= 0 then
                    factor = (currentLevel + 1) / maxLevel
                end
            end

            for stat, amount in pairs(modGains) do
                stats[stat] = math.min(100, (stats[stat] or 0) + amount * factor)
            end
        end
    end

    for key, value in pairs(stats) do
        stats[key] = math.floor(value + 0.5)
    end

    return stats
end

CalcHandlingStats = WorkshopStats.CalcHandling
CalcModdedStats = WorkshopStats.CalcModded
