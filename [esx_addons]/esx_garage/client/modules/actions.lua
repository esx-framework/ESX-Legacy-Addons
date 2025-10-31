Actions = {}

---@return nil | GaragePayload
function Actions.GaragePayload()
    if not GARAGE_POINT then
        return
    end

    local garage = Config.Garages[GARAGE_POINT]

    if not garage then
        ESX.ShowNotification(TranslateCap('cant-open'), 'error')
        return
    end

    ---@type GarageVehicleDB[] | { success: false, error: string}
    local owned_vehicles = ESX.AwaitServerCallback('esx_garages/getOwnedVehicles')

    if owned_vehicles?.error then
        return ESX.ShowNotification(owned_vehicles.error, 'error')
    end

    ---@type GarageVehicle[]
    local wrapped_vehicles = {}

    for i = 1, #owned_vehicles do
        local vehicle = owned_vehicles[i]
        ---@type ESXVehicleProperties
        local properties = json.decode(vehicle.vehicle)

        if not properties then
            ESX.ShowNotification(TranslateCap('invalid-vehicle'), 'error')
            return
        end

        local display_name = GetDisplayNameFromVehicleModel(properties.model):lower()

        wrapped_vehicles[i] = {
            id = vehicle.plate,
            plate = vehicle.plate,
            model = vehicle.model or display_name:lower(),
            name = display_name,
            type = vehicle.type,
            garageId = vehicle.parking,
            impouned = Config.GarageState.IMPOUNDED == vehicle.stored,
            impoundFee = Config.ImpoundFee,
            mileage = vehicle.mileage or 0,
            fuel = properties.fuelLevel,
            engine = properties.engineHealth / 10,
            body = properties.bodyHealth / 10,
            stored = Config.GarageState.STORED == vehicle.stored,
            isFavorite = (vehicle.second_favorite or vehicle.favorite) == 1,
            customName = (vehicle.second_nickname or vehicle.nickname),
            lastUsed = vehicle.last_used,
            props = properties,
            secondOwners = vehicle.second_owners
        }
    end

    return {
        garage = {
            id = garage.id,
            name = garage.id,
            type = 'public',
            label = garage.label,
        },
        vehicles = wrapped_vehicles
    }
end

---@param data { vehicleId: string, isFavorite: boolean }
---@return CallbackResult
function Actions.ToggleFavorite(data)
    local result = ESX.AwaitServerCallback('esx_garages/toggleFavorite', data)

    if result.error then
        ESX.ShowNotification(result.error, 'error')
    end

    return result
end

---@param data { vehicleId: string, newName: string }
---@return CallbackResult
function Actions.RenameVehicle(data)
    local result = ESX.AwaitServerCallback('esx_garages/renameVehicle', data)

    if result.error then
        ESX.ShowNotification(result.error, 'error')
    end

    return result
end

---@param data { vehicleId: string, targetId: string}
---@return CallbackResult
function Actions.TransferVehicle(data)
    local result = ESX.AwaitServerCallback('esx_garages/transferVehicle', data)

    if result.error then
        ESX.ShowNotification(result.error, 'error')
    end

    return result
end

---@param data { vehicleId: string }
---@return CallbackResult
function Actions.RetrieveVehicle(data)
    if not ESX.Game.IsSpawnPointClear(Config.Garages[GARAGE_POINT].spawnPoint, 8) then
        ESX.ShowNotification(TranslateCap('no-empty-space'), 'error')
        return {
            success = false,
            error = TranslateCap('no-empty-space')
        }
    end

    local result = ESX.AwaitServerCallback('esx_garages/retrieveVehicle', data)

    if result.error then
        ESX.ShowNotification(result.error, 'error')
    end

    return result
end

---@return CallbackResult | nil
function Actions.HideVehicle()
    if not PLAYER_VEHICLE then
        return
    end

    local properties = ESX.Game.GetVehicleProperties(PLAYER_VEHICLE)

    local result = ESX.AwaitServerCallback('esx_garages/hideVehicle', {
        properties = properties
    })

    if result.error then
        ESX.ShowNotification(result.error, 'error')
    else
        PLAYER_VEHICLE = false
    end

    return result
end

---@param data { vehicleId: string, targetId: string }
---@return CallbackResult
function Actions.AddSecondOwner(data)
    local result = ESX.AwaitServerCallback('esx_garages/addSecondOwner', data)

    if result.error then
        ESX.ShowNotification(result.error, 'error')
    end

    return result
end

---@param data { vehicleId: string, targetId: string }
---@return CallbackResult
function Actions.RemoveSecondOwner(data)
    local result = ESX.AwaitServerCallback('esx_garages/removeSecondOwner', data)

    if result.error then
        ESX.ShowNotification(result.error, 'error')
    end

    return result
end

---@param data { type: 'impound' | 'find', vehicleId: string }
---@return CallbackResult
function Actions.ImpoundVehicle(data)
    local result = ESX.AwaitServerCallback('esx_garages/impoundVehicle', data)

    if result.error then
        ESX.ShowNotification(result.error, 'error')
    end

    return result
end
