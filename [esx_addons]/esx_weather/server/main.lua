-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local EVENT_COOLDOWNS <const> = {
    ["esx_weather:server:setZoneWeather"] = 1000,
}

local eventLimiters = {}

---@param src integer
---@param eventName string
---@return boolean
local function isRateLimited(src, eventName)
    local cooldown = EVENT_COOLDOWNS[eventName]
    if not cooldown then
        return false
    end

    local limiter = eventLimiters[eventName]
    if not limiter then
        limiter = xLib.rateLimiter({
            capacity = 1,
            refill = 1,
            interval = cooldown,
            staleMs = math.max(60000, cooldown * 4)
        })
        eventLimiters[eventName] = limiter
    end

    if not limiter:consume(src) then
        Shared.Modules.Debug.print(("Rate limited player %s on event %s"):format(tostring(src), eventName))
        return true
    end

    return false
end

---@param zone Zone
---@param weatherType WeatherType
RegisterNetEvent("esx_weather:server:setZoneWeather", function(zone, weatherType)
    local src = source --[[@as integer]]

    if isRateLimited(src, "esx_weather:server:setZoneWeather") then
        return
    end

    local xPlayer = ESX.Player(src)
    if (not xPlayer) then return end

    if (not Config.AdminGroups[xPlayer.getGroup()]) then
        return
    end

    if (not Modules.Weather.ByZone[zone]) then
        return
    end

    if not Modules.Weather.isValidType(weatherType) then
        Shared.Modules.Debug.print(("Invalid weather type rejected from player %s: %s"):format(tostring(src), tostring(weatherType)))
        return
    end

    Modules.Weather.setZone(zone, weatherType)
end)

---@param src integer
AddEventHandler("esx:playerLoaded", function(src)
    Modules.Weather.broadcastZones(src)
    Modules.Time.broadcast(src)
end)

Citizen.SetTimeout(1000, function()
    Modules.Weather.broadcastZones()
    Modules.Time.broadcast()
end)
