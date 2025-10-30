Modules = Modules or {}
Modules.NUI = Modules.NUI or {}
Modules.NUI.isOpen = false

---@param currentZone Zone
---@param currentWeather WeatherType
---@param WeatherByZone table<Zone, WeatherType>
function Modules.NUI.show(currentZone, currentWeather, WeatherByZone)
    SendNUIMessage({
        action = "show",
        Data = {
            currentZone = currentZone,
            currentWeather = currentWeather,
            WeatherByZone = WeatherByZone,
        }
    })
    SetNuiFocus(true, true)
    Modules.NUI.isOpen = true
end

---@param WeatherByZone table<Zone, WeatherType>
function Modules.NUI.updateWeatherZones(WeatherByZone)
    if (not Modules.NUI.isOpen) then return end

    SendNUIMessage({
        action = "updateWeatherZones",
        Data = {
            WeatherByZone = WeatherByZone,
        }
    })
end

---@param Data {zoneName: Zone, weatherType: WeatherType}
---@param cb fun(success:boolean)
RegisterNUICallback("setZoneWeather", function(Data, cb)
    TriggerServerEvent("esx_weather:server:setZoneWeather", Data.zoneName, Data.weatherType)
    cb(true)
end)

---@param _ nil
---@param cb fun(success:boolean)
RegisterNUICallback("close", function(_, cb)
    SetNuiFocus(false, false)
    Modules.NUI.isOpen = false
    cb(true)
end)

---@param _ nil
---@param cb fun(Data: {WeatherTypes: table<WeatherType, string>})
RegisterNUICallback("ready", function(_, cb)
    cb({ WeatherTypes = Shared.Enum.WeatherType })
end)
