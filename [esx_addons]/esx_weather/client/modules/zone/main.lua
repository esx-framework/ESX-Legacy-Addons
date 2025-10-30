Modules = Modules or {}
Modules.Zone = Modules.Zone or {}

---@return Zone
function Modules.Zone.getClosest()
    local playerCoords = GetEntityCoords(ESX.PlayerData.ped).xy

    local closestZone, closestZoneDistance = nil, nil
    for zone, zoneCoords in pairs(Config.Zones) do
        local currentDistance = #(playerCoords - zoneCoords)
        if (not closestZone or currentDistance < closestZoneDistance) then
            closestZone = zone
            closestZoneDistance = currentDistance
        end
    end

    return closestZone
end
