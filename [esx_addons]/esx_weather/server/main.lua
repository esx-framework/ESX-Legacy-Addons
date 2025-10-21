local WeatherByZone = table.clone(Config.Zones) --[[@as table<string, WeatherType>]]
for zoneName, _ in pairs(WeatherByZone) do
    WeatherByZone[zoneName] = Config.ValidWeatherTypes[math.random(1, #Config.ValidWeatherTypes)]
end

RegisterNetEvent("esx_weather:server:setZoneWeather", function(zoneName, weatherType)
    local src = source --[[@as integer]]
    local xPlayer = ESX.Player(src)
    if (not xPlayer) then return end

    if (not Config.AdminGroups[xPlayer.getGroup()]) then
        return
    end

    if (not WeatherByZone[zoneName]) then
        return
    end

    WeatherByZone[zoneName] = weatherType
    TriggerClientEvent("esx_weather:client:setZoneWeather", -1, zoneName, weatherType)
end)

---@param src integer
local function onPlayerLoaded(src)
    TriggerClientEvent("esx_weather:client:setWeatherZones", src, WeatherByZone)
end
AddEventHandler("esx:playerLoaded", onPlayerLoaded)

Citizen.SetTimeout(1000, function()
    for i, src in ipairs(GetPlayers()) do
        onPlayerLoaded(tonumber(src) --[[@as integer]])
    end
end)

Citizen.CreateThread(function()
    while (true) do
        Citizen.Wait(Config.weatherCycleTimeSeconds * 1000)

        for zoneName, _ in pairs(WeatherByZone) do
            WeatherByZone[zoneName] = Config.ValidWeatherTypes[math.random(1, #Config.ValidWeatherTypes)]
        end

        onPlayerLoaded(-1)
    end
end)
