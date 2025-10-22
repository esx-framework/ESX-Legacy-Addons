Modules = Modules or {}
Modules.Weather = Modules.Weather or {}
Modules.Weather.ByZone = false ---@type table<string, WeatherType> | false
Modules.Weather.currentType = false ---@type WeatherType | false
Modules.Weather.isSyncEnabled = true

---@param toggle boolean
function Modules.Weather.toggleSync(toggle)
    if (type(toggle) ~= "boolean") then
        error("toggle: expected boolean, got " .. type(toggle))
    end

    Modules.Weather.isSyncEnabled = toggle
end

Citizen.CreateThread(function()
    while (not ESX.PlayerLoaded or not Modules.Weather.ByZone) do Citizen.Wait(0) end

    while (true) do
        local currentZone, zoneWeather

        if (not Modules.Weather.isSyncEnabled) then
            goto continue
        end

        currentZone = Modules.Zone.getClosest()
        zoneWeather = Modules.Weather.ByZone[currentZone]
        if (zoneWeather == Modules.Weather.currentType) then
            goto continue
        end

        Shared.Modules.Debug.print(("Entered zone %s. Changing weather: %s -> %s"):format(currentZone, Modules.Weather.currentType or "NONE", zoneWeather))
        Modules.Weather.currentType = zoneWeather
        SetWeatherTypeOvertimePersist(zoneWeather, Config.weatherTransitionTimeSeconds * 1.0)

        ::continue::
        Citizen.Wait(1000)
    end
end)
