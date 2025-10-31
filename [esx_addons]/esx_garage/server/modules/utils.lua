Utils = {}

---@param plate string
---@param identifier string
---@return boolean
function Utils.IsSecondOwner(plate, identifier)
    return MySQL.prepare.await(
        'SELECT 1 FROM `second_owners` WHERE `identifier` = ? AND `plate` = ?', { identifier, plate }
    ) and true or false
end

---@param plate string
---@param identifier string
---@return boolean
function Utils.IsOwner(plate, identifier)
    return MySQL.prepare.await(
        'SELECT 1 FROM `owned_vehicles` WHERE `owner` = ? AND `plate` = ?', { identifier, plate }
    ) and true or false
end

---@param plate string
---@param identifier string
---@return boolean
function Utils.HasAccess(plate, identifier)
    return Utils.IsOwner(plate, identifier) or Utils.IsSecondOwner(plate, identifier)
end

---@param player_coords vector3 | vector4
function Utils.GetPlayerGarage(player_coords)
    for i = 1, #Config.Garages do
        local vec3d = vec3(
            Config.Garages[i].ped.coords.x,
            Config.Garages[i].ped.coords.y,
            Config.Garages[i].ped.coords.z)
        if #(vec3d - player_coords) <= 16 then
            return i
        end
    end
end

---@param player_coords vector3 | vector4
---@return boolean
function Utils.IsNearReturnPoint(player_coords)
    for i = 1, #Config.Garages do
        local vec3d = vec3(
            Config.Garages[i].spawnPoint.x,
            Config.Garages[i].spawnPoint.y,
            Config.Garages[i].spawnPoint.z)
        if #(vec3d - player_coords) <= 30 then
            return true
        end
    end

    return false
end

---@param vehicle integer
---@return boolean
function Utils.IsVehicleEmpty(vehicle)
    local vehicle_model = GetEntityModel(vehicle)
    local seat_count = GetVehicleModelNumberOfSeats(vehicle_model)

    for seat = -1, seat_count - 2 do
        local ped = GetPedInVehicleSeat(vehicle, seat)
        if ped and ped ~= 0 then
            return false
        end
    end

    return true
end
