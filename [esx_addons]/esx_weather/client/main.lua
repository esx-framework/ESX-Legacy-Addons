-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local function assertClientConfig()
    if type(Config) ~= "table" then
        error("[esx_weather] Config must be configured")
    end

    if type(Config.AdminGroups) ~= "table" then
        error("[esx_weather] Config.AdminGroups must be configured")
    end

    if type(Config.Weather) ~= "table" then
        error("[esx_weather] Config.Weather must be configured")
    end

    local transitionTimeSeconds = tonumber(Config.Weather.transitionTimeSeconds)
    if not transitionTimeSeconds or transitionTimeSeconds < 0 then
        error("[esx_weather] Config.Weather.transitionTimeSeconds must be a number greater than or equal to 0")
    end

    if type(Config.Time) ~= "table" then
        error("[esx_weather] Config.Time must be configured")
    end

    local secondsPerGameMinute = tonumber(Config.Time.secondsPerGameMinute)
    if not secondsPerGameMinute or secondsPerGameMinute <= 0 then
        error("[esx_weather] Config.Time.secondsPerGameMinute must be a positive number")
    end

    Config.Weather.transitionTimeSeconds = transitionTimeSeconds
    Config.Time.secondsPerGameMinute = secondsPerGameMinute
end

assertClientConfig()

---@param WeatherByZone table<Zone, WeatherType>
RegisterNetEvent("esx_weather:client:weather:setZones", function(WeatherByZone)
    Modules.Weather.ByZone = WeatherByZone
    Modules.NUI.updateWeatherZones(Modules.Weather.ByZone)
    Shared.Modules.Debug.print("Received weather zones from server:", json.encode(Modules.Weather.ByZone, { indent = true }))
end)

---@param zone Zone
---@param weatherType WeatherType
RegisterNetEvent("esx_weather:client:weather:setZone", function(zone, weatherType)
    if (not Modules.Weather.ByZone) then return end

    local oldWeatherType = Modules.Weather.ByZone[zone]
    Modules.Weather.ByZone[zone] = weatherType
    Modules.NUI.updateWeatherZones(Modules.Weather.ByZone)
    Shared.Modules.Debug.print(("Updated zone %s. Changing weather: %s -> %s"):format(zone, oldWeatherType, weatherType))
end)

---@param currentTime SerializedTime
RegisterNetEvent("esx_weather:client:time:setTime", function(currentTime)
    Modules.Time.set(currentTime)
end)

Citizen.CreateThread(function()
    while (not ESX.PlayerLoaded) do Citizen.Wait(0) end
    while (not Modules.Weather.ByZone) do Citizen.Wait(0) end

    SetMillisecondsPerGameMinute(Config.Time.secondsPerGameMinute * 1000)

    while (true) do
        Modules.Time.tick()
        Modules.Weather.tick()
        Citizen.Wait(1000)
    end
end)

RegisterCommand(Config.panelCommand, function()
    local playerGroup = ESX.PlayerData and ESX.PlayerData.group
    if (not Config.AdminGroups[playerGroup]) then
        return
    end

    if (not Modules.Weather.ByZone or not Modules.Weather.currentType) then return end

    Modules.NUI.show(Modules.Zone.getClosest(), Modules.Weather.currentType, Modules.Weather.ByZone)
end, false)

exports("ToggleWeatherSync", Modules.Weather.toggleSync)
exports("ToggleTimeSync", Modules.Time.toggleSync)
