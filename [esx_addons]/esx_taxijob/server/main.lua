-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local lastPlayerSuccess = {}
local activeMissions = {}

if Config.MaxInService ~= -1 then
    TriggerEvent('esx_service:activateService', 'taxi', Config.MaxInService)
end

TriggerEvent('esx_phone:registerNumber', 'taxi', TranslateCap('taxi_client'), true, true)
TriggerEvent('esx_society:registerSociety', 'taxi', 'Taxi', 'society_taxi', 'society_taxi', 'society_taxi', {
    type = 'public'
})

local function toVector3(coords)
    if not coords or not coords.x or not coords.y or not coords.z then
        return nil
    end

    return vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
end

local function isNear(source, coords, distance)
    local nearby = xLib.player.isNearCoords(source, coords, distance)
    return nearby
end

local function getDrivenVehicle(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then
        return nil
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if not vehicle or vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        return nil
    end

    return vehicle
end

local function isAuthorizedTaxiVehicle(source, xPlayer)
    local vehicle = getDrivenVehicle(source)
    if not vehicle then
        return false
    end

    local job = xPlayer.getJob()
    if job.grade >= 3 then
        return true
    end

    local model = GetEntityModel(vehicle)
    for i = 1, #Config.AuthorizedVehicles do
        if model == joaat(Config.AuthorizedVehicles[i].model) then
            return true
        end
    end

    return false
end

local function getAuthorizedTaxiModel(model)
    local modelHash

    if type(model) == 'number' then
        modelHash = model
    elseif type(model) == 'string' and model ~= '' then
        modelHash = joaat(model)
    else
        return nil
    end

    for i = 1, #Config.AuthorizedVehicles do
        if modelHash == joaat(Config.AuthorizedVehicles[i].model) then
            return modelHash
        end
    end

    return nil
end

local function normalizeSocietyPlate(plate)
    return xLib.vehiclePlate.normalize(plate, {
        maxLength = 12
    })
end

local function getSocietyVehicleModel(vehicle)
    local model = vehicle.model

    if type(model) == 'number' and model ~= 0 then
        return model
    elseif type(model) == 'string' and model ~= '' then
        return tonumber(model) or joaat(model)
    end

    return nil
end

local function takeSocietyVehicle(plate)
    plate = normalizeSocietyPlate(plate)
    if not plate then
        return nil
    end

    local societyVehicle

    TriggerEvent('esx_datastore:getSharedDataStore', 'society_taxi', function(store)
        if not store then
            return
        end

        local garage = store.get('garage') or {}

        for i = 1, #garage do
            if type(garage[i]) == 'table' and normalizeSocietyPlate(garage[i].plate) == plate then
                societyVehicle = table.remove(garage, i)
                store.set('garage', garage)
                break
            end
        end
    end)

    return societyVehicle
end

local function returnSocietyVehicle(vehicle)
    local plate = normalizeSocietyPlate(vehicle.plate)

    TriggerEvent('esx_datastore:getSharedDataStore', 'society_taxi', function(store)
        if not store then
            return
        end

        local garage = store.get('garage') or {}

        for i = 1, #garage do
            if type(garage[i]) == 'table' and normalizeSocietyPlate(garage[i].plate) == plate then
                return
            end
        end

        garage[#garage + 1] = vehicle
        store.set('garage', garage)
    end)
end

local function isConfiguredDropoff(coords)
    for i = 1, #Config.JobLocations do
        if #(coords - Config.JobLocations[i]) <= 5.0 then
            return true
        end
    end

    return false
end

local getValidCount = xLib.validation.count

local function isNearTaxiActions(source)
    return isNear(source, vector3(Config.Zones.TaxiActions.Pos.x, Config.Zones.TaxiActions.Pos.y, Config.Zones.TaxiActions.Pos.z), 8.0)
end

RegisterNetEvent('esx_taxijob:startMission', function(pickupCoords, dropoffCoords)
    local source = source
    local xPlayer = ESX.Player(source)
    if not xPlayer or xPlayer.getJob().name ~= 'taxi' or not isAuthorizedTaxiVehicle(source, xPlayer) then
        return
    end

    local pickup = toVector3(pickupCoords)
    local dropoff = toVector3(dropoffCoords)
    if not pickup or not dropoff or not isConfiguredDropoff(dropoff) then
        return
    end

    if not isNear(source, pickup, 80.0) or #(pickup - dropoff) < Config.MinimumDistance then
        return
    end

    activeMissions[source] = {
        dropoff = dropoff,
        started = os.clock()
    }
end)

RegisterNetEvent('esx_taxijob:success', function()
    local xPlayer = ESX.Player(source)
    local timeNow = os.clock()
    local job = xPlayer and xPlayer.getJob()
    if not job or job.name ~= 'taxi' then
        print(('[^3WARNING^7] Player ^5%s^7 attempted to ^5esx_taxijob:success^7 (cheating)'):format(source))
        return
    end

    local mission = activeMissions[source]
    if not mission or not isAuthorizedTaxiVehicle(source, xPlayer) or not isNear(source, mission.dropoff, 18.0) then
        print(('[^3WARNING^7] Player ^5%s^7 attempted invalid taxi payout!'):format(source))
        return
    end

    if not lastPlayerSuccess[source] or timeNow - lastPlayerSuccess[source] > 10 then
        lastPlayerSuccess[source] = timeNow
        activeMissions[source] = nil

        local total = math.random(Config.NPCJobEarnings.min, Config.NPCJobEarnings.max)

        if job.grade >= 3 then
            total = total * 2
        end

        TriggerEvent('esx_addonaccount:getSharedAccount', 'society_taxi', function(account)
            if account then
                local playerMoney = ESX.Math.Round(total / 100 * 30)
                local societyMoney = ESX.Math.Round(total / 100 * 70)

                xPlayer.addMoney(playerMoney, "Taxi Fair")
                account.addMoney(societyMoney)

                xPlayer.showNotification(TranslateCap('comp_earned', societyMoney, playerMoney))
            else
                xPlayer.addMoney(total, "Taxi Fair")
                xPlayer.showNotification(TranslateCap('have_earned', total))
            end
        end)
    end
end)

AddEventHandler('playerDropped', function()
    activeMissions[source] = nil
    lastPlayerSuccess[source] = nil
end)

xLib.callback.registerCompat("esx_taxijob:SpawnVehicle", function(source, cb, model , props)
    local xPlayer = ESX.Player(source)

    if not xPlayer or xPlayer.getJob().name ~= "taxi" then 
        print(('[^3WARNING^7] Player ^5%s^7 attempted to Exploit Vehicle Spawing!!'):format(source))
        return cb(false)
    end

    if not isNear(source, vector3(Config.Zones.VehicleSpawner.Pos.x, Config.Zones.VehicleSpawner.Pos.y, Config.Zones.VehicleSpawner.Pos.z), 15.0) then
        return cb(false)
    end

    local SpawnPoint = vector3(Config.Zones.VehicleSpawnPoint.Pos.x, Config.Zones.VehicleSpawnPoint.Pos.y, Config.Zones.VehicleSpawnPoint.Pos.z)
    if #ESX.OneSync.GetVehiclesInArea(SpawnPoint, 5.0) > 0 then
        xPlayer.showNotification(TranslateCap('spawnpoint_blocked'))
        return cb(false)
    end

    local modelHash, societyVehicle

    if Config.EnableSocietyOwnedVehicles then
        societyVehicle = takeSocietyVehicle(type(props) == 'table' and props.plate)
        modelHash = societyVehicle and getSocietyVehicleModel(societyVehicle)
        props = societyVehicle
    else
        modelHash = getAuthorizedTaxiModel(model)
        props = { plate = 'TAXI JOB' }
    end

    if not modelHash then
        if societyVehicle then
            returnSocietyVehicle(societyVehicle)
        end

        print(('[^3WARNING^7] Player ^5%s^7 attempted to spawn invalid taxi model ^5%s^7!'):format(source, tostring(model)))
        return cb(false)
    end

    ESX.OneSync.SpawnVehicle(modelHash, SpawnPoint, Config.Zones.VehicleSpawnPoint.Heading, props, function(vehicle)
        local vehicle = vehicle and NetworkGetEntityFromNetworkId(vehicle)
        if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
            if societyVehicle then
                returnSocietyVehicle(societyVehicle)
            end
            return
        end
        local deadline = GetGameTimer() + 3000
        while props and props.plate and GetVehicleNumberPlateText(vehicle) ~= props.plate and GetGameTimer() < deadline do
            Wait(0)
        end
        TaskWarpPedIntoVehicle(GetPlayerPed(source), vehicle, -1)
    end)
    cb(true)
end)

RegisterNetEvent('esx_taxijob:getStockItem', function(itemName, count)
    local xPlayer = ESX.Player(source)
    count = getValidCount(count)
    
    if not xPlayer or xPlayer.getJob().name ~= 'taxi' or not count or not isNearTaxiActions(source) then
        print(('[^3WARNING^7] Player ^5%s^7 attempted ^5esx_taxijob:getStockItem^7 (cheating)'):format(source))
        return
    end

    TriggerEvent('esx_addoninventory:getSharedInventory', 'society_taxi', function(inventory)
        local item = inventory.getItem(itemName)
        
        if not xPlayer.canCarryItem(itemName, count) then
            xPlayer.showNotification(TranslateCap('player_cannot_hold'))
            return
        end

        if item.count < count then
            xPlayer.showNotification(TranslateCap('quantity_invalid'))
            return
        end

        inventory.removeItem(itemName, count)
        xPlayer.addInventoryItem(itemName, count)
        xPlayer.showNotification(TranslateCap('have_withdrawn', count, item.label))
    end)
end)

xLib.callback.registerCompat('esx_taxijob:getStockItems', function(source, cb)
    local xPlayer = ESX.Player(source)
    if not xPlayer or xPlayer.getJob().name ~= 'taxi' or not isNearTaxiActions(source) then
        return cb({})
    end

    TriggerEvent('esx_addoninventory:getSharedInventory', 'society_taxi', function(inventory)
        cb(inventory.items)
    end)
end)

RegisterNetEvent('esx_taxijob:putStockItems', function(itemName, count)
    local xPlayer = ESX.Player(source)
    count = getValidCount(count)
    if not xPlayer or xPlayer.getJob().name ~= 'taxi' or not count or not isNearTaxiActions(source) then
        print(('[^3WARNING^7] Player ^5%s^7 attempted ^5esx_taxijob:putStockItems^7 (cheating)'):format(source))
        return
    end

	local sourceItem = xPlayer.getInventoryItem(itemName)

    TriggerEvent('esx_addoninventory:getSharedInventory', 'society_taxi', function(inventory)
        local item = inventory.getItem(itemName)
        
        if sourceItem.count < count then
            return xPlayer.showNotification(TranslateCap('quantity_invalid'))
        end

        xPlayer.removeInventoryItem(itemName, count)
        inventory.addItem(itemName, count)
        xPlayer.showNotification(TranslateCap('have_deposited', count, item.label))
    end)
end)

xLib.callback.registerCompat('esx_taxijob:getPlayerInventory', function(source, cb)
    local xPlayer = ESX.Player(source)
    if not xPlayer or xPlayer.getJob().name ~= 'taxi' or not isNearTaxiActions(source) then
        return cb({items = {}})
    end

    local items = xPlayer.getInventory(false)
    cb({
        items = items
    })
end)
