---@param player_id integer
---@param cb fun(...)
---@param data { vehicleId: string, isFavorite: boolean }
ESX.RegisterServerCallback('esx_garages/toggleFavorite', function(player_id, cb, data)
    local xPlayer = ESX.Player(player_id)

    if not xPlayer then
        return cb({
            success = false,
            error = TranslateCap('internal_error')
        })
    end

    local player_coords = xPlayer.getCoords(true, false)

    local player_garage = Utils.GetPlayerGarage(player_coords)

    if not player_garage then
        return cb({
            success = false,
            TranslateCap('not-allowed')
        })
    end

    local identifier = xPlayer.getIdentifier()

    local updated_rows

    if Utils.IsSecondOwner(data.vehicleId, identifier) then
        updated_rows = MySQL.update.await(
            'UPDATE `second_owners` SET `favorite` = ? WHERE `identifier` = ? AND `plate` = ?',
            { data.isFavorite, identifier, data.vehicleId })
    else
        updated_rows = MySQL.update.await(
            'UPDATE `owned_vehicles` SET `favorite` = ? WHERE `owner` = ? AND `plate` = ?',
            { data.isFavorite, identifier, data.vehicleId })
    end

    if updated_rows == 0 then
        return cb({
            success = false,
            error = TranslateCap('internal_error')
        })
    end

    cb({
        success = true,
        data = true
    })
end)

---@param player_id integer
---@param cb fun(...)
---@param data { vehicleId: string, targetId: string}
ESX.RegisterServerCallback('esx_garages/transferVehicle', function(player_id, cb, data)
    local xPlayer = ESX.Player(player_id)

    if not xPlayer then
        return cb({
            success = false,
            error = TranslateCap('internal_error')
        })
    end

    local player_coords = xPlayer.getCoords(true, false)

    local player_garage = Utils.GetPlayerGarage(player_coords)

    if not player_garage then
        return cb({
            success = false,
            TranslateCap('not-allowed')
        })
    end

    local xTargetSource = tonumber(data.targetId)

    if not xTargetSource then
        return cb({
            success = false,
            error = TranslateCap('not-found-player')
        })
    end

    local xTarget = ESX.Player(xTargetSource)

    if not xTarget then
        return cb({
            success = false,
            error = TranslateCap('not-found-player')
        })
    end

    local player_identifier = xPlayer.getIdentifier()

    local target_identifier = xTarget.getIdentifier()

    if player_identifier == target_identifier then
        return cb({
            success = false,
            error = TranslateCap('to-your-self')
        })
    end

    if not Utils.IsOwner(data.vehicleId, player_identifier) then
        return cb({
            success = false,
            error = TranslateCap('not-the-owner')
        })
    end

    local updated_rows = MySQL.update.await(
        'UPDATE `owned_vehicles` SET `owner` = ? WHERE `owner` = ? AND `plate` = ?',
        { target_identifier, player_identifier, data.vehicleId })


    if updated_rows == 0 then
        return cb({
            success = false,
            error = TranslateCap('internal_error')
        })
    end

    cb({
        success = true,
        data = true
    })
end)

---@param player_id integer
---@param cb fun(...)
---@param data { vehicleId: string, newName: string }
ESX.RegisterServerCallback('esx_garages/renameVehicle', function(player_id, cb, data)
    local xPlayer = ESX.Player(player_id)

    if not xPlayer then
        return cb({
            success = false,
            error = TranslateCap('internal_error')
        })
    end

    local player_coords = xPlayer.getCoords(true, false)

    local player_garage = Utils.GetPlayerGarage(player_coords)

    if not player_garage then
        return cb({
            success = false,
            TranslateCap('not-allowed')
        })
    end

    if data.newName == "" then
        data.newName = nil
    end

    local identifier = xPlayer.getIdentifier()

    local updated_rows

    if Utils.IsSecondOwner(data.vehicleId, identifier) then
        updated_rows = MySQL.update.await(
            'UPDATE `second_owners` SET `nickname` = ? WHERE `identifier` = ? AND `plate` = ?',
            { data.newName, identifier, data.vehicleId })
    else
        updated_rows = MySQL.update.await(
            'UPDATE `owned_vehicles` SET `nickname` = ? WHERE `owner` = ? AND `plate` = ?',
            { data.newName, identifier, data.vehicleId })
    end


    if updated_rows == 0 then
        return cb({
            success = false,
            error = TranslateCap('internal_error')
        })
    end

    cb({
        success = true,
        data = true
    })
end)


---@param player_id any
---@param cb any
---@param data { vehicleId: string, targetId: string}
ESX.RegisterServerCallback('esx_garages/addSecondOwner', function(player_id, cb, data)
    local xPlayer = ESX.Player(player_id)

    if not xPlayer then
        return cb({
            success = false,
            error = TranslateCap('internal_error')
        })
    end

    local player_coords = xPlayer.getCoords(true, false)

    local player_garage = Utils.GetPlayerGarage(player_coords)

    if not player_garage then
        return cb({
            success = false,
            TranslateCap('not-allowed')
        })
    end

    local xTargetSource = tonumber(data.targetId)

    if not xTargetSource then
        return cb({
            success = false,
            error = TranslateCap('not-found-player')
        })
    end

    local xTarget = ESX.Player(xTargetSource)

    if not xTarget then
        return cb({
            success = false,
            error = TranslateCap('not-found-player')
        })
    end

    local player_identifier = xPlayer.getIdentifier()

    local target_identifier = xTarget.getIdentifier()

    if player_identifier == target_identifier then
        return cb({
            success = false,
            error = TranslateCap('to-your-self')
        })
    end

    if not Utils.IsOwner(data.vehicleId, player_identifier) then
        return cb({
            success = false,
            error = TranslateCap('not-the-owner')
        })
    end

    if Utils.IsSecondOwner(data.vehicleId, target_identifier) then
        return cb({
            success = false,
            error = TranslateCap('already-second-owner')
        })
    end

    local id = MySQL.insert.await(
        'INSERT INTO `second_owners`(`identifier`, `plate`) VALUES(?, ?)',
        { target_identifier, data.vehicleId })

    if not id then
        return cb({
            success = false,
            error = TranslateCap('internal_error')
        })
    end

    cb({
        success = true,
        data = true
    })
end)

---@param player_id any
---@param cb any
---@param data { vehicleId: string, targetId: string}
ESX.RegisterServerCallback('esx_garages/removeSecondOwner', function(player_id, cb, data)
    local xPlayer = ESX.Player(player_id)

    if not xPlayer then
        return cb({
            success = false,
            error = TranslateCap('internal_error')
        })
    end

    local player_coords = xPlayer.getCoords(true, false)

    local player_garage = Utils.GetPlayerGarage(player_coords)

    if not player_garage then
        return cb({
            success = false,
            TranslateCap('not-allowed')
        })
    end

    local xTargetSource = tonumber(data.targetId)

    if not xTargetSource then
        return cb({
            success = false,
            error = TranslateCap('not-found-player')
        })
    end

    local xTarget = ESX.Player(xTargetSource)

    if not xTarget then
        return cb({
            success = false,
            error = TranslateCap('not-found-player')
        })
    end

    local player_identifier = xPlayer.getIdentifier()

    local target_identifier = xTarget.getIdentifier()

    if player_identifier == target_identifier then
        return cb({
            success = false,
            error = TranslateCap('remove-from-yourself')
        })
    end

    if not Utils.IsOwner(data.vehicleId, player_identifier) then
        return cb({
            success = false,
            error = TranslateCap('not-the-owner')
        })
    end

    if not Utils.IsSecondOwner(data.vehicleId, target_identifier) then
        return cb({
            success = false,
            error = TranslateCap('not-a-second-owner')
        })
    end

    local updated_rows = MySQL.update.await(
        'DELETE FROM `second_owners`  WHERE `identifier` = ? AND `plate` = ?',
        { target_identifier, data.vehicleId })


    if updated_rows == 0 then
        return cb({
            success = false,
            error = TranslateCap('internal_error')
        })
    end

    cb({
        success = true,
        data = true
    })
end)
