Modules = Modules or {}
Modules.Zone = Modules.Zone or {}

---@return string
function Modules.Zone.getClosest()
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
