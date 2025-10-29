local created_peds = {}

GARAGE_POINT = nil

local function openGarage()
    if not GARAGE_POINT then
        return
    end

    local garage = Config.Garages[GARAGE_POINT]

    if not garage then
        ESX.ShowNotification('Couldn\'t open garage menu', 'error')
        return
    end

    ---@type GarageVehicleDB[]
    local owned_vehicles = ESX.AwaitServerCallback('esx_garages/getOwnedVehicles')

    ---@type GarageVehicle[]
    local wrapped_vehicles = {}

    for i = 1, #owned_vehicles do
        local vehicle = owned_vehicles[i]
        ---@type ESXVehicleProperties
        local properties = json.decode(vehicle.vehicle)

        if not properties then
            ESX.ShowNotification('One of your vehicles, have invalid properties. Contact server owner', 'error')
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
            mileage = 0,
            fuel = properties.fuelLevel,
            engine = properties.engineHealth / 10,
            body = properties.bodyHealth / 10,
            stored = Config.GarageState.STORED == vehicle.stored,
            isFavorite = false,
            customName = nil,
            lastUsed = 0,
            props = properties,
        }
    end

    SendNUIMessage({
        type = 'openGarage',
        payload = {
            garage = {
                id = garage.id,
                name = garage.id,
                type = 'public',
                label = garage.label,
            },
            vehicles = wrapped_vehicles
        }
    })

    SetNuiFocus(true, true)
end

ESX.RegisterInput('openGarage', 'Opens Garage Menu', 'keyboard', 'E', openGarage)

Citizen.CreateThread(function()
    for i = 1, #Config.Garages do
        local garage = Config.Garages[i]
        local blip = garage.blip

        Utils.CreateBlip(garage.entryPoint, blip.sprite, blip.scale, blip.color, TranslateCap('parking_blip_name'))

        created_peds[#created_peds + 1] = Utils.SpawnFrozenPed(garage.ped.model, garage.ped.coords)

        ESX.Point:new({
            coords = garage.entryPoint,
            distance = 3,
            enter = function()
                GARAGE_POINT = i
                exports['esx_textui']:TextUI('Press [E] to open Garage Menu')
            end,
            leave = function()
                GARAGE_POINT = nil
                exports['esx_textui']:HideUI()
            end
        })
    end
end)


AddEventHandler('onResourceStop', function(resource_name)
    if resource_name ~= GetCurrentResourceName() then
        return
    end

    for i = 1, #created_peds do
        local ped = created_peds[i]
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
end)

---@param body { vehicleId: string, isFavorite: boolean }
---@param cb function
RegisterNUICallback('garage:toggleFavorite', function(body, cb)
    local result = ESX.AwaitServerCallback('esx_garages/toggleFavorite', body)
    cb(result)
end)

---@param body { hasFocus: boolean, hasCursor: boolean }
---@param cb function
RegisterNUICallback('SetNuiFocus', function(body, cb)
    SetNuiFocus(body.hasFocus, body.hasCursor)

    cb({
        success = true
    })
end)
