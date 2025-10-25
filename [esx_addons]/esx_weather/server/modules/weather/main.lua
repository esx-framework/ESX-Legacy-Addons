Modules = Modules or {}
Modules.Weather = {}

Modules.Weather.ByZone = table.clone(Config.Zones) --[[@as table<Zone, WeatherType>]]
for zoneName, _ in pairs(Modules.Weather.ByZone) do
    Modules.Weather.ByZone[zoneName] = Config.Weather.ValidTypes[math.random(1, #Config.Weather.ValidTypes)]
end

---@param src integer?
function Modules.Weather.broadcastZones(src)
    TriggerClientEvent("esx_weather:client:weather:setZones", (src or -1), Modules.Weather.ByZone)
end

---@param zoneName Zone
---@param src integer?
function Modules.Weather.broadcastZone(zoneName, src)
    local weatherType = Modules.Weather.ByZone[zoneName]
    TriggerClientEvent("esx_weather:client:weather:setZone", (src or -1), zoneName, weatherType)
end

---@param zoneName Zone
---@param weatherType WeatherType
function Modules.Weather.setZone(zoneName, weatherType)
    Modules.Weather.ByZone[zoneName] = weatherType
    Modules.Weather.broadcastZone(zoneName)
end

Citizen.CreateThread(function()
    while (true) do
        Citizen.Wait(Config.Weather.cycleTimeSeconds * 1000)

        for zoneName, _ in pairs(Modules.Weather.ByZone) do
            Modules.Weather.ByZone[zoneName] = Config.Weather.ValidTypes[math.random(1, #Config.Weather.ValidTypes)]
        end

        Modules.Weather.broadcastZones()
    end
end)
