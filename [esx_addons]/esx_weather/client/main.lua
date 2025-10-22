---@param WeatherByZone table<string, WeatherType>
RegisterNetEvent("esx_weather:client:weather:setZones", function(WeatherByZone)
    Modules.Weather.ByZone = WeatherByZone
    Modules.NUI.updateWeatherZones(Modules.Weather.ByZone)
    Shared.Modules.Debug.print("Received weather zones from server:", json.encode(Modules.Weather.ByZone, { indent = true }))
end)

---@param zoneName string
---@param weatherType WeatherType
RegisterNetEvent("esx_weather:client:setZoneWeather", function(zoneName, weatherType)
    if (not Modules.Weather.ByZone) then return end

    local oldWeatherType = Modules.Weather.ByZone[zoneName]
    Modules.Weather.ByZone[zoneName] = weatherType
    Modules.NUI.updateWeatherZones(Modules.Weather.ByZone)
    Shared.Modules.Debug.print(("Updated zone %s. Changing weather: %s -> %s"):format(zoneName, oldWeatherType, weatherType))
end)

exports("ToggleWeatherSync", Modules.Weather.toggleSync)

RegisterCommand("weathersync", function()
    if (not Config.AdminGroups[ESX.PlayerData.group]) then
        return
    end

    if (not Modules.Weather.ByZone or not Modules.Weather.currentType) then return end

    Modules.NUI.show(Modules.Zone.getClosest(), Modules.Weather.currentType, Modules.Weather.ByZone)
end)
