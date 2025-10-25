Modules = Modules or {}
Modules.Weather = {}

Modules.Weather.ByZone = table.clone(Config.Zones) --[[@as table<Zone, WeatherType>]]
for zone, _ in pairs(Modules.Weather.ByZone) do
    Modules.Weather.ByZone[zone] = Config.Weather.ValidTypes[math.random(1, #Config.Weather.ValidTypes)]
end

---@param src integer?
function Modules.Weather.broadcastZones(src)
    TriggerClientEvent("esx_weather:client:weather:setZones", (src or -1), Modules.Weather.ByZone)
end

---@param zone Zone
---@param src integer?
function Modules.Weather.broadcastZone(zone, src)
    local weatherType = Modules.Weather.ByZone[zone]
    TriggerClientEvent("esx_weather:client:weather:setZone", (src or -1), zone, weatherType)
end

---@param zone Zone
---@param weatherType WeatherType
function Modules.Weather.setZone(zone, weatherType)
    Modules.Weather.ByZone[zone] = weatherType
    Modules.Weather.broadcastZone(zone)
end

Citizen.CreateThread(function()
    while (true) do
        Citizen.Wait(Config.Weather.cycleTimeSeconds * 1000)

        for zone, _ in pairs(Modules.Weather.ByZone) do
            Modules.Weather.ByZone[zone] = Config.Weather.ValidTypes[math.random(1, #Config.Weather.ValidTypes)]
        end

        Modules.Weather.broadcastZones()
    end
end)
