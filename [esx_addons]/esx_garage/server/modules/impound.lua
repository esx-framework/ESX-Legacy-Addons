---@param player_id integer
---@param cb fun(...)
---@param data { type: 'impound' | 'find', vehicleId: string }
ESX.RegisterServerCallback('esx_garages/impoundVehicle', function(player_id, cb, data)
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
            error = TranslateCap('not-allowed')
        })
    end

    local player_identifier = xPlayer.getIdentifier()

    if not Utils.HasAccess(data.vehicleId, player_identifier) then
        return cb({
            success = false,
            error = TranslateCap('not-permitted')
        })
    end

    local fee = data.type == 'find' and Config.FindVehicleFee or Config.ImpoundFee

    if xPlayer.getAccount('bank').money < fee then
        return cb({
            success = false,
            error = TranslateCap('missing_money')
        })
    end

    local vehicle = SPAWNED_VEHICLES[data.vehicleId]

    if vehicle and DoesEntityExist(vehicle) then
        if not Utils.IsVehicleEmpty(vehicle) then
            return cb({
                success = false,
                error = TranslateCap('failed_find')
            })
        end

        DeleteEntity(vehicle)
    end

    xPlayer.removeAccountMoney('bank', fee)

    MySQL.update.await(
        "UPDATE `owned_vehicles` SET `stored` = ? WHERE `plate` = ?",
        { Config.GarageState.STORED, data.vehicleId })

    cb({
        success = true,
        data = true
    })
end)
