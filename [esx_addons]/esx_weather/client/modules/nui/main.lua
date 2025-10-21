Modules = Modules or {}
Modules.NUI = Modules.NUI or {}
Modules.NUI.isOpen = false

---@param currentWeather WeatherType
---@param WeatherByZone table<string, WeatherType>
function Modules.NUI.show(currentWeather, WeatherByZone)
    SendNUIMessage({
        action = "show",
        Data = {
            currentWeather = currentWeather,
            WeatherByZone = WeatherByZone,
        }
    })
    SetNuiFocus(true, true)
    Modules.NUI.isOpen = true
end

---@param WeatherByZone table<string, WeatherType>
function Modules.NUI.updateWeatherZones(WeatherByZone)
    if (not Modules.NUI.isOpen) then return end

    SendNUIMessage({
        action = "updateWeatherZones",
        Data = {
            WeatherByZone = WeatherByZone,
        }
    })
end

---@param Data {zoneName: string, weatherType: WeatherType}
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
