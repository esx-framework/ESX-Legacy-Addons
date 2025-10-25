---@param zoneName Zone
---@param weatherType WeatherType
RegisterNetEvent("esx_weather:server:setZoneWeather", function(zoneName, weatherType)
    local src = source --[[@as integer]]
    local xPlayer = ESX.Player(src)
    if (not xPlayer) then return end

    if (not Config.AdminGroups[xPlayer.getGroup()]) then
        return
    end

    if (not Modules.Weather.ByZone[zoneName]) then
        return
    end

    Modules.Weather.setZone(zoneName, weatherType)
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
