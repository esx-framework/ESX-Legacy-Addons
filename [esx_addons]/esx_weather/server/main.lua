-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local EVENT_COOLDOWNS <const> = {
    ["esx_weather:server:setZoneWeather"] = 1000,
}

---@type table<integer, table<string, integer>>
local eventCooldowns = {}

---@return integer
local function currentTimeMs()
    if type(GetGameTimer) == "function" then
        return GetGameTimer()
    end
    return math.floor(os.clock() * 1000)
end

---@param src integer
---@param eventName string
---@return boolean
local function isRateLimited(src, eventName)
    local cooldown = EVENT_COOLDOWNS[eventName]
    if not cooldown then
        return false
    end

    local now = currentTimeMs()
    local playerCooldowns = eventCooldowns[src]
    if not playerCooldowns then
        playerCooldowns = {}
        eventCooldowns[src] = playerCooldowns
    end

    if (playerCooldowns[eventName] or 0) > now then
        Shared.Modules.Debug.print(("Rate limited player %s on event %s"):format(tostring(src), eventName))
        return true
    end

    playerCooldowns[eventName] = now + cooldown
    return false
end

AddEventHandler("playerDropped", function()
    eventCooldowns[source] = nil
end)

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

    local isValidWeather = false
    for _, validType in ipairs(Config.Weather.ValidTypes) do
        if validType == weatherType then
            isValidWeather = true
            break
        end
    end

    if not isValidWeather then
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
