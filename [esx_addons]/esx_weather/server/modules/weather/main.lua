-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Modules = Modules or {}
Modules.Weather = {}

local KVP_VERSION <const> = 1

local function isValidWeatherType(weatherType)
    for _, validType in ipairs(Config.Weather.ValidTypes) do
        if validType == weatherType then
            return true
        end
    end

    return false
end

Modules.Weather.isValidType = isValidWeatherType

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

    Config.Weather.dynamic = Config.Weather.dynamic ~= false
    Config.Weather.persist = Config.Weather.persist == true
    Config.Weather.defaultType = Config.Weather.defaultType or Config.Weather.ValidTypes[1]

    if not isValidWeatherType(Config.Weather.defaultType) then
        error("[esx_weather] Config.Weather.defaultType must be listed in Config.Weather.ValidTypes")
    end

    if Config.Weather.persistKey ~= nil and type(Config.Weather.persistKey) ~= "string" then
        error("[esx_weather] Config.Weather.persistKey must be a string")
    end
end

assertWeatherConfig()

local lastRotation = os.time()

local function getPersistKey()
    return Config.Weather.persistKey or "esx_weather_zones"
end

local function getRandomWeatherType()
    return Config.Weather.ValidTypes[math.random(1, #Config.Weather.ValidTypes)]
end

local function persistZones()
    if not Config.Weather.persist then
        return
    end

    SetResourceKvp(getPersistKey(), json.encode({
        version = KVP_VERSION,
        zones = Modules.Weather.ByZone,
        rotatedAt = lastRotation,
    }))
end

local function restorePersistedZones()
    if not Config.Weather.persist then
        return
    end

    local stored = GetResourceKvpString(getPersistKey())

    if not stored then
        return
    end

    local ok, decoded = pcall(json.decode, stored)

    if not ok or type(decoded) ~= "table" or decoded.version ~= KVP_VERSION or type(decoded.zones) ~= "table" then
        DeleteResourceKvp(getPersistKey())
        return
    end

    for zone, weatherType in pairs(decoded.zones) do
        if Modules.Weather.ByZone[zone] and isValidWeatherType(weatherType) then
            Modules.Weather.ByZone[zone] = weatherType
        end
    end

    if type(decoded.rotatedAt) == "number" and decoded.rotatedAt <= lastRotation then
        lastRotation = decoded.rotatedAt
    end
end

Modules.Weather.ByZone = table.clone(Config.Zones) --[[@as table<Zone, WeatherType>]]
for zone, _ in pairs(Modules.Weather.ByZone) do
    Modules.Weather.ByZone[zone] = Config.Weather.dynamic and getRandomWeatherType() or Config.Weather.defaultType
end
restorePersistedZones()

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
    persistZones()
    Modules.Weather.broadcastZone(zone)
end

if Config.Weather.dynamic then
    Citizen.CreateThread(function()
        while (true) do
            local remaining = Config.Weather.cycleTimeSeconds - (os.time() - lastRotation)
            Citizen.Wait(math.floor(math.max(0, math.min(remaining, Config.Weather.cycleTimeSeconds)) * 1000))

            for zone, _ in pairs(Modules.Weather.ByZone) do
                Modules.Weather.ByZone[zone] = getRandomWeatherType()
            end

            lastRotation = os.time()
            persistZones()
            Modules.Weather.broadcastZones()
        end
    end)
end
