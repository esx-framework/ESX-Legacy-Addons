-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Modules = Modules or {}
Modules.Weather = {}

local function assertWeatherConfig()
    if type(Config) ~= "table" or type(Config.Zones) ~= "table" or next(Config.Zones) == nil then
        error("[esx_weather] Config.Zones must contain at least one zone")
    end

    if type(Config.Weather) ~= "table" then
        error("[esx_weather] Config.Weather must be configured")
    end

    if type(Config.Weather.ValidTypes) ~= "table" or #Config.Weather.ValidTypes == 0 then
        error("[esx_weather] Config.Weather.ValidTypes must contain at least one weather type")
    end

    for index, weatherType in ipairs(Config.Weather.ValidTypes) do
        if type(weatherType) ~= "string" or weatherType == "" then
            error(("[esx_weather] Config.Weather.ValidTypes[%s] must be a non-empty string"):format(index))
        end
    end

    local cycleTimeSeconds = tonumber(Config.Weather.cycleTimeSeconds)
    if not cycleTimeSeconds or cycleTimeSeconds <= 0 then
        error("[esx_weather] Config.Weather.cycleTimeSeconds must be a positive number")
    end

    Config.Weather.cycleTimeSeconds = cycleTimeSeconds
end

assertWeatherConfig()

Modules.Weather.ByZone = table.clone(Config.Zones) --[[@as table<Zone, WeatherType>]]
for zone, _ in pairs(Modules.Weather.ByZone) do
    Modules.Weather.ByZone[zone] = Config.Weather.ValidTypes[math.random(1, #Config.Weather.ValidTypes)]
end

---@param src integer?
function Modules.Weather.broadcastZones(src)
    TriggerClientEvent("esx_weather:client:weather:setZones", (src or -1), Modules.Weather.ByZone)
end

---@param zone Zone
---@param src integer?
function Modules.Weather.broadcastZone(zone, src)
    local weatherType = Modules.Weather.ByZone[zone]
    TriggerClientEvent("esx_weather:client:weather:setZone", (src or -1), zone, weatherType)
end

---@param zone Zone
---@param weatherType WeatherType
function Modules.Weather.setZone(zone, weatherType)
    Modules.Weather.ByZone[zone] = weatherType
    Modules.Weather.broadcastZone(zone)
end

Citizen.CreateThread(function()
    while (true) do
        Citizen.Wait(Config.Weather.cycleTimeSeconds * 1000)

        for zone, _ in pairs(Modules.Weather.ByZone) do
            Modules.Weather.ByZone[zone] = Config.Weather.ValidTypes[math.random(1, #Config.Weather.ValidTypes)]
        end

        Modules.Weather.broadcastZones()
    end
end)
