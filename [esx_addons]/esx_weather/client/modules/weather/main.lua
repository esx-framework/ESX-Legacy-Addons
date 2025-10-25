Modules = Modules or {}
Modules.Weather = Modules.Weather or {}
Modules.Weather.ByZone = false ---@type table<Zone, WeatherType> | false
Modules.Weather.currentType = false ---@type WeatherType | false
Modules.Weather.isSyncEnabled = true

---@param toggle boolean
function Modules.Weather.toggleSync(toggle)
    assert(type(toggle) == "boolean", "toggle must be a boolean")

    Modules.Weather.isSyncEnabled = toggle
end

function Modules.Weather.tick()
    local currentZone, zoneWeather

    if (not Modules.Weather.isSyncEnabled) then
        return
    end

    currentZone = Modules.Zone.getClosest()
    zoneWeather = Modules.Weather.ByZone[currentZone]
    if (not zoneWeather or zoneWeather == Modules.Weather.currentType) then
        return
    end

    Shared.Modules.Debug.print(("Entered zone %s. Changing weather: %s -> %s"):format(currentZone, Modules.Weather.currentType or "NONE", zoneWeather))
    Modules.Weather.currentType = zoneWeather
    SetWeatherTypeOvertimePersist(zoneWeather, Config.Weather.transitionTimeSeconds * 1.0)
end
