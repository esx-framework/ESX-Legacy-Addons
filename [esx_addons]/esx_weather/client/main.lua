local WeatherByZone = false ---@type table<string, WeatherType> | false
local currentWeather = false ---@type WeatherType | false
local isWeatherSyncEnabled = true ---@type boolean

---@param _WeatherByZone table<string, WeatherType>
RegisterNetEvent("esx_weather:client:setWeatherZones", function(_WeatherByZone)
    WeatherByZone = _WeatherByZone
    Modules.NUI.updateWeatherZones(WeatherByZone)
    Shared.Modules.Debug.print("Received weather zones from server:", json.encode(WeatherByZone, { indent = true }))
end)

---@param zoneName string
---@param weatherType WeatherType
RegisterNetEvent("esx_weather:client:setZoneWeather", function(zoneName, weatherType)
    if (not WeatherByZone) then return end

    local oldWeatherType = WeatherByZone[zoneName]
    WeatherByZone[zoneName] = weatherType
    Modules.NUI.updateWeatherZones(WeatherByZone)
    Shared.Modules.Debug.print(("Updated zone %s. Changing weather: %s -> %s"):format(zoneName, oldWeatherType, weatherType))
end)

---@return string
local function getPlayerCurrentZone()
    local playerCoords = GetEntityCoords(ESX.PlayerData.ped).xy

    local closestZone, closestZoneDistance = nil, nil
    for zoneName, zoneCoords in pairs(Config.Zones) do
        local currentDistance = #(playerCoords - zoneCoords)
        if (not closestZone or currentDistance < closestZoneDistance) then
            closestZone = zoneName
            closestZoneDistance = currentDistance
        end
    end

    return closestZone
end

---@param toggle boolean
local function toggleWeatherSync(toggle)
    if (type(toggle) ~= "boolean") then
        error("toggleWeatherSync: expected boolean, got " .. type(toggle))
    end

    isWeatherSyncEnabled = toggle
end
exports("ToggleWeatherSync", toggleWeatherSync)

Citizen.CreateThread(function()
    while (not ESX.PlayerLoaded or not WeatherByZone) do Citizen.Wait(0) end

    while (true) do
        local currentZone, zoneWeather

        if (not isWeatherSyncEnabled) then
            goto continue
        end

        currentZone = getPlayerCurrentZone()
        zoneWeather = WeatherByZone[currentZone]
        if (zoneWeather == currentWeather) then
            goto continue
        end

        Shared.Modules.Debug.print(("Entered zone %s. Changing weather: %s -> %s"):format(currentZone, currentWeather or "NONE", zoneWeather))
        currentWeather = zoneWeather
        SetWeatherTypeOvertimePersist(zoneWeather, Config.weatherTransitionTimeSeconds * 1.0)

        ::continue::
        Citizen.Wait(1000)
    end
end)

RegisterCommand("weathersync", function()
    if (not Config.AdminGroups[ESX.PlayerData.group]) then
        return
    end

    if (not WeatherByZone or not currentWeather) then return end

    Modules.NUI.show(getPlayerCurrentZone(), currentWeather, WeatherByZone)
end)
