local created_peds = {}
local return_vehicle = false

---@type false | integer
PLAYER_VEHICLE = false
GARAGE_POINT = nil

-- ~INPUT_94A9125A~ - 0x94A9125A
-- https://tools.povers.fr/hashgenerator/ If you ever change the openGarage name
ESX.RegisterInput('openGarage', 'Opens Garage Menu', 'keyboard', 'E', function()
    if GARAGE_POINT then
        NUI.OpenGarage()
    elseif return_vehicle and PLAYER_VEHICLE then
        Actions.HideVehicle()
    end
end)

AddEventHandler('esx:enteredVehicle', function(vehicle, plate, seat, displayName, netId)
    PLAYER_VEHICLE = vehicle
    Mileage.StartLoop()
end)

AddEventHandler('esx:exitedVehicle', function()
    PLAYER_VEHICLE = false
end)

local function displayReturn()
    Citizen.CreateThread(function()
        local displayed = false

        local return_vehicle_locale = (TranslateCap('park-vehicle', Keybinds.GetName()))

        while true do
            if not return_vehicle then
                break
            end

            if PLAYER_VEHICLE and not displayed and not GARAGE_POINT then
                exports['esx_textui']:TextUI(return_vehicle_locale)
                displayed = true
            end

            Citizen.Wait(1000)
        end

        exports['esx_textui']:HideUI()
    end)
end

Citizen.CreateThread(function()
    for i = 1, #Config.Garages do
        local garage = Config.Garages[i]
        local blip = garage.blip

        Utils.CreateBlip(garage.entryPoint, blip.sprite, blip.scale, blip.color, TranslateCap('parking-blip'))

        created_peds[#created_peds + 1] = Utils.SpawnFrozenPed(garage.ped.model, garage.ped.coords)


        local access_parking = (TranslateCap('access-parking', Keybinds.GetName()))


        ESX.Point:new({
            coords = garage.entryPoint,
            distance = 3,
            enter = function()
                GARAGE_POINT = i
                exports['esx_textui']:TextUI(access_parking)
            end,
            leave = function()
                GARAGE_POINT = nil
                exports['esx_textui']:HideUI()
            end
        })

        local vec3_spawn_point = vec3(garage.spawnPoint.x, garage.spawnPoint.y, garage.spawnPoint.z)

        ESX.Point:new({
            coords = vec3_spawn_point,
            distance = 50,
            enter = function()
                return_vehicle = true
                displayReturn()
            end,
            leave = function()
                return_vehicle = false
            end
        })
    end
end)

AddEventHandler('onResourceStop', function(resource_name)
    if resource_name ~= GetCurrentResourceName() then
        return
    end

    exports['esx_textui']:HideUI()

    for i = 1, #created_peds do
        local ped = created_peds[i]
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
end)
