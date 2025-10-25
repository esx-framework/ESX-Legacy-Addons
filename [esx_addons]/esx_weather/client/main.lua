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

    while (true) do
        Modules.Time.tick()
        Modules.Weather.tick()
        Citizen.Wait(1000)
    end
end)

RegisterCommand("weathersync", function()
    if (not Config.AdminGroups[ESX.PlayerData.group]) then
        return
    end

    if (not Modules.Weather.ByZone or not Modules.Weather.currentType) then return end

    Modules.NUI.show(Modules.Zone.getClosest(), Modules.Weather.currentType, Modules.Weather.ByZone)
end)

exports("ToggleWeatherSync", Modules.Weather.toggleSync)
exports("ToggleTimeSync", Modules.Time.toggleSync)
