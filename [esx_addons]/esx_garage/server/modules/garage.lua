---@param player_id integer
---@param cb fun(...)
ESX.RegisterServerCallback('esx_garages/getOwnedVehicles', function(player_id, cb)
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

    local identifier = xPlayer.getIdentifier()

    ---@type GarageVehicleDB[]
    local owned_vehicles = MySQL.query.await('SELECT * FROM `owned_vehicles` WHERE `owner` = ?',
        { identifier }) or {}

    for i = 1, #owned_vehicles do
        ---@type GarageSecondOwner[]
        local second_owners = MySQL.query.await([[
			SELECT `second_owners`.`identifier`, `firstname`, `lastname`
			FROM `second_owners`
			INNER JOIN `users`
				ON `second_owners`.`identifier` = `users`.`identifier`
			WHERE `second_owners`.`plate` = ?
		]], { owned_vehicles[i].plate })


        ---@diagnostic disable-next-line: inject-field
        owned_vehicles.second_owners = second_owners or {}
    end

    local second_owner_vehicles = MySQL.query.await([[
			SELECT
				`owned_vehicles`.*,
				`second_owners`.`favorite` AS `second_favorite`,
				`second_owners`.`nickname` AS `second_nickname`
			FROM `owned_vehicles`
			INNER JOIN `second_owners`
				ON `second_owners`.`plate` = `owned_vehicles`.`plate`
			WHERE `second_owners`.`identifier` = ?
	]], { identifier })

    if second_owner_vehicles then
        for i = 1, #second_owner_vehicles do
            owned_vehicles[#owned_vehicles + 1] = second_owner_vehicles[i]
        end
    end

    cb(owned_vehicles)
end)


---@param player_id integer
---@param cb fun(...)
---@param data { vehicleId: string }
ESX.RegisterServerCallback('esx_garages/retrieveVehicle', function(player_id, cb, data)
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

    local vehicle_data = MySQL.prepare.await("SELECT * FROM `owned_vehicles` WHERE `plate` = ?", {
        data.vehicleId
    })

    if not vehicle_data then
        return cb({
            success = false,
            error = TranslateCap('internal_error')
        })
    end

    if not vehicle_data.stored == Config.GarageState.STORED then
        return cb({
            success = false,
            error = TranslateCap('not_in_garage')
        })
    end

    local properties = json.decode(vehicle_data.vehicle)

    local garage = Config.Garages[player_garage]

    local vec3d = vec3(garage.spawnPoint.x, garage.spawnPoint.y, garage.spawnPoint.z)

    ESX.OneSync.SpawnVehicle(properties.model, vec3d, garage.spawnPoint.w, properties, function(net_id)
        local entity = NetworkGetEntityFromNetworkId(net_id)

        if not DoesEntityExist(entity) then
            return cb({
                success = false,
                error = TranslateCap('failed_create')
            })
        end

        MySQL.update.await("UPDATE `owned_vehicles` SET `stored` = ? WHERE `plate` = ?",
            { Config.GarageState.NOT_STORED, vehicle_data.plate })


        Entity(entity).state:set("mileage", vehicle_data.mileage or 0, true)

        SPAWNED_VEHICLES[vehicle_data.plate] = entity
    end)

    cb({
        success = true,
        data = true
    })
end)

---@param player_id integer
---@param cb fun(...)
---@param data { properties: ESXVehicleProperties }
ESX.RegisterServerCallback('esx_garages/hideVehicle', function(player_id, cb, data)
    local xPlayer = ESX.Player(player_id)

    if not xPlayer then
        return cb({
            success = false,
            error = TranslateCap('internal_error')
        })
    end

    local player_coords = xPlayer.getCoords(true, false)

    local is_allowed = Utils.IsNearReturnPoint(player_coords)

    if not is_allowed then
        return cb({
            success = false,
            error = TranslateCap('not-allowed')
        })
    end

    local player_ped = GetPlayerPed(player_id)
    local vehicle = GetVehiclePedIsIn(player_ped, false)

    if vehicle == 0 then
        return cb({
            success = false,
            error = TranslateCap('not_in_vehicle')
        })
    end

    local vehicle_plate = GetVehicleNumberPlateText(vehicle)

    local player_identifier = xPlayer.getIdentifier()

    if not Utils.HasAccess(vehicle_plate, player_identifier) then
        return cb({
            success = false,
            error = TranslateCap('not-permitted')
        })
    end

    local database_properties = MySQL.prepare.await("SELECT `vehicle` FROM `owned_vehicles` WHERE `plate` = ?", {
        vehicle_plate
    })

    local properties = data.properties

    if database_properties?.vehicle then
        ---already checks if nil by ?
        ---@diagnostic disable-next-line: need-check-nil
        database_properties = json.decode(database_properties.vehicle)

        if database_properties.model ~= properties.model then
            --! Ban function
            xPlayer.kick('Cheating')
        end
    end

    MySQL.update.await(
        "UPDATE `owned_vehicles` SET `stored` = ?, `vehicle` = ?, `last_used` = ?, `mileage` = ? WHERE `plate` = ?",
        { Config.GarageState.STORED, json.encode(properties), os.time(), Entity(vehicle).state.mileage or
        0, vehicle_plate })

    DeleteEntity(vehicle)

    cb({
        success = true,
        data = true
    })
end)
