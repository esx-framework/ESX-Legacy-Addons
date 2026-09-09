-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Modules = Modules or {}
Modules.Weather = Modules.Weather or {}
Modules.Weather.ByZone = false ---@type table<Zone, WeatherType> | false
Modules.Weather.currentType = false ---@type WeatherType | false
Modules.Weather.isSyncEnabled = true
Modules.Weather.transitionTarget = false ---@type WeatherType | false
Modules.Weather.transitionEnd = 0 ---@type integer

---@param toggle boolean
function Modules.Weather.toggleSync(toggle)
    assert(type(toggle) == "boolean", "toggle must be a boolean")

    Modules.Weather.isSyncEnabled = toggle
end

function Modules.Weather.tick()
    if (not Modules.Weather.isSyncEnabled) then
        return
    end

    local currentZone = Modules.Zone.getClosest()
    local zoneWeather = Modules.Weather.ByZone[currentZone]
    if (not zoneWeather or zoneWeather == Modules.Weather.currentType) then
        return
    end

    if zoneWeather == Modules.Weather.transitionTarget and GetGameTimer() < Modules.Weather.transitionEnd then
        return
    end

    ClearWeatherTypePersist()

    Shared.Modules.Debug.print(("Entered zone %s. Changing weather: %s -> %s"):format(currentZone, Modules.Weather.currentType or "NONE", zoneWeather))
    Modules.Weather.currentType = zoneWeather
    Modules.Weather.transitionTarget = zoneWeather
    Modules.Weather.transitionEnd = GetGameTimer() + (Config.Weather.transitionTimeSeconds * 1000)
    SetWeatherTypeOvertimePersist(zoneWeather, Config.Weather.transitionTimeSeconds * 1.0)
end