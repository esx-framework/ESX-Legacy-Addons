-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

ESXCatalog.awaitReady()

local categories, vehicles = {}, {}
local vehiclesByModel = {}
local vehiclesLoaded = false
local normalizePlate = xLib.vehiclePlate.normalize

local function generateServerPlate()
    return xLib.vehiclePlate.generateUnique({
        letters = Config.PlateLetters,
        numbers = Config.PlateNumbers,
        useSpace = Config.PlateUseSpace,
    }, function(plate)
        local owned = MySQL.scalar.await('SELECT plate FROM owned_vehicles WHERE plate = ?', { plate })
        local rented = MySQL.scalar.await('SELECT plate FROM rented_vehicles WHERE plate = ?', { plate })

        return owned ~= nil or rented ~= nil
    end)
end

local function isNear(source, coords, distance)
    local nearby = xLib.player.isNearCoords(source, coords, distance)

    return nearby
end

local getValidCount = xLib.validation.count

local function canUseCardealerStock(xPlayer, source)
    return xPlayer and xPlayer.getJob().name == 'cardealer' and isNear(source, Config.Zones.BossActions.Pos, 8.0)
end

local function canUseCardealerShowroom(xPlayer, source)
    return xPlayer and xPlayer.getJob().name == 'cardealer' and isNear(source, Config.Zones.ShopInside.Pos, 30.0)
end

local function canUseCardealerReseller(xPlayer, source)
    return xPlayer and xPlayer.getJob().name == 'cardealer' and isNear(source, Config.Zones.ResellVehicle.Pos, 12.0)
end

local function getRentalPrice(basePrice)
    basePrice = tonumber(basePrice)

    if not basePrice then
        return nil
    end

    local multiplier = tonumber(Config.RentalPriceMultiplier) or 0.05
    local minimum = tonumber(Config.MinimumRentalPrice) or 1

    return math.max(minimum, ESX.Math.Round(basePrice * multiplier))
end

local function isNearVehicleWithPlate(source, plate, distance)
    local ped = GetPlayerPed(source)

    if not ped or ped <= 0 then
        return false
    end

    local playerCoords = GetEntityCoords(ped)
    local currentVehicle = GetVehiclePedIsIn(ped, false)

    if currentVehicle and currentVehicle ~= 0 and normalizePlate(GetVehicleNumberPlateText(currentVehicle)) == plate then
        return true
    end

    for _, vehicle in ipairs(GetAllVehicles()) do
        if
            DoesEntityExist(vehicle)
            and normalizePlate(GetVehicleNumberPlateText(vehicle)) == plate
            and #(GetEntityCoords(vehicle) - playerCoords) <= (distance or 8.0)
        then
            return true
        end
    end

    return false
end

if Config.EnablePlayerManagement then
    local societyRegistered = false

    local function registerCardealer()
        if societyRegistered then
            return
        end

        exports['esx_society']:registerSociety(
            'cardealer',
            TranslateCap('car_dealer'),
            'society_cardealer',
            'society_cardealer',
            'society_cardealer',
            { type = 'private' }
        )

        societyRegistered = true
    end

    AddEventHandler('onResourceStart', function(resourceName)
        if resourceName == 'esx_society' then
            registerCardealer()
        end
    end)

    AddEventHandler('onResourceStop', function(resourceName)
        if resourceName == 'esx_society' then
            societyRegistered = false
        end
    end)

    CreateThread(function()
        if GetResourceState('esx_society') == 'started' then
            registerCardealer()
        end
    end)
end

CreateThread(function()
    local char = Config.PlateLetters

    char = char + Config.PlateNumbers

    if Config.PlateUseSpace then
        char = char + 1
    end

    if char > 8 then
        print(('[^3WARNING^7] Character Limit Exceeded, ^5%s/8^7!'):format(char))
    end
end)

function RemoveOwnedVehicle(plate)
    MySQL.update('DELETE FROM owned_vehicles WHERE plate = ?', { plate })
end

function SQLVehiclesAndCategories()
    local loadedCategories = MySQL.query.await('SELECT * FROM vehicle_categories')
    local loadedVehicles = MySQL.query.await(
        'SELECT vehicles.*, vehicle_categories.label AS categoryLabel FROM vehicles JOIN vehicle_categories ON vehicles.category = vehicle_categories.name'
    )
    local loadedModels = {}

    for _, vehicle in ipairs(loadedVehicles) do
        loadedModels[vehicle.model] = vehicle
    end

    categories = loadedCategories
    vehicles = loadedVehicles
    vehiclesByModel = loadedModels
    vehiclesLoaded = true

    if #vehicles == 0 then
        print('[esx_vehicleshop] No vehicles matched the catalog. Check vehicles and their matching vehicle_categories entries.')
    end

    TriggerClientEvent('esx_vehicleshop:updateVehiclesAndCategories', -1, vehicles, categories, vehiclesByModel)
end

CreateThread(function()
    SQLVehiclesAndCategories()
end)

function getVehicleFromModel(model)
    return vehiclesByModel[model]
end

RegisterNetEvent('esx_vehicleshop:getVehiclesAndCategories', function()
    if not vehiclesLoaded then
        return
    end

    TriggerClientEvent('esx_vehicleshop:updateVehiclesAndCategories', source, vehicles, categories, vehiclesByModel)
end)

RegisterNetEvent('esx_vehicleshop:setVehicleOwnedPlayerId')

AddEventHandler('esx_vehicleshop:setVehicleOwnedPlayerId', function(playerId, vehicleProps, model, label)
    if not VehicleShopDatabaseReady then
        return
    end

    local xPlayer, xTarget = ESX.Player(source), ESX.Player(playerId)
    local vehicleData = type(model) == 'string' and getVehicleFromModel(model)

    if not canUseCardealerShowroom(xPlayer, source) or not xTarget or type(vehicleProps) ~= 'table' or not vehicleData then
        return
    end

    local plate = generateServerPlate()

    if not plate then
        return
    end

    vehicleProps = { plate = plate, model = joaat(model) }

    local owner, targetName = xTarget.getIdentifier(), xTarget.getName()
    local id = MySQL.scalar.await('SELECT id FROM cardealer_vehicles WHERE vehicle = ? ORDER BY id LIMIT 1', { model })

    if not id then
        return
    end

    local ok, committed = pcall(MySQL.transaction.await, {
        { query = 'SELECT id FROM cardealer_vehicles WHERE id = ? FOR UPDATE', values = { id } },
        {
            query = 'INSERT INTO owned_vehicles (owner, plate, vehicle) SELECT ?, ?, ? FROM cardealer_vehicles WHERE id = ? AND vehicle = ?',
            values = { owner, plate, json.encode(vehicleProps), id, model },
        },
        {
            query = 'INSERT INTO vehicle_sold (client, model, plate, soldby, date) SELECT ?, ?, plate, ?, CURRENT_TIMESTAMP FROM owned_vehicles WHERE plate = ? AND owner = ?',
            values = { targetName, vehicleData.name or model, xPlayer.getName(), plate, owner },
        },
        {
            query = 'DELETE FROM cardealer_vehicles WHERE id = ? AND EXISTS (SELECT 1 FROM owned_vehicles WHERE plate = ? AND owner = ?)',
            values = { id, plate, owner },
        },
    })

    if not ok or not committed then
        return
    end

    if not MySQL.scalar.await('SELECT 1 FROM owned_vehicles WHERE plate = ? AND owner = ?', { plate, owner }) then
        return
    end

    xPlayer.showNotification(TranslateCap('vehicle_set_owned', plate, targetName))
    xTarget.showNotification(TranslateCap('vehicle_belongs', plate))
end)

xLib.callback.registerCompat('esx_vehicleshop:getSoldVehicles', function(source, cb, page)
    local xPlayer = ESX.Player(source)

    if not canUseCardealerStock(xPlayer, source) and not canUseCardealerReseller(xPlayer, source) then
        return cb({})
    end

    page = tonumber(page) or 1

    if page ~= page or page % 1 ~= 0 or page < 1 or page > 10000 then
        return cb({})
    end

    MySQL.query(
        'SELECT client, model, plate, soldby, date FROM vehicle_sold ORDER BY date DESC, plate DESC LIMIT 51 OFFSET ?',
        { (page - 1) * 50 },
        function(result)
            local more = #result > 50

            if more then
                result[51] = nil
            end

            cb(result, more, page)
        end
    )
end)

RegisterNetEvent('esx_vehicleshop:rentVehicle')

AddEventHandler('esx_vehicleshop:rentVehicle', function(vehicle, plate, rentPrice, playerId)
    if not VehicleShopDatabaseReady then
        return
    end

    local xPlayer, xTarget = ESX.Player(source), ESX.Player(playerId)

    if not canUseCardealerShowroom(xPlayer, source) or not xTarget or not getVehicleFromModel(vehicle) then
        return
    end

    local result = MySQL.single.await('SELECT id, price FROM cardealer_vehicles WHERE vehicle = ? ORDER BY id LIMIT 1', { vehicle })

    if not result then
        return
    end

    local generatedPlate, price = generateServerPlate(), getRentalPrice(result.price)

    if not generatedPlate or not price then
        return
    end

    local owner = xTarget.getIdentifier()
    local ok, committed = pcall(MySQL.transaction.await, {
        { query = 'SELECT id FROM cardealer_vehicles WHERE id = ? FOR UPDATE', values = { result.id } },
        {
            query = 'INSERT INTO rented_vehicles (vehicle, plate, player_name, base_price, rent_price, owner) SELECT vehicle, ?, ?, price, ?, ? FROM cardealer_vehicles WHERE id = ? AND vehicle = ? AND price = ?',
            values = { generatedPlate, xTarget.getName(), price, owner, result.id, vehicle, result.price },
        },
        {
            query = 'DELETE FROM cardealer_vehicles WHERE id = ? AND EXISTS (SELECT 1 FROM rented_vehicles WHERE plate = ? AND owner = ?)',
            values = { result.id, generatedPlate, owner },
        },
    })

    if not ok or not committed then
        return
    end

    if MySQL.scalar.await('SELECT 1 FROM rented_vehicles WHERE plate = ? AND owner = ?', { generatedPlate, owner }) then
        xPlayer.showNotification(TranslateCap('vehicle_set_rented', generatedPlate, xTarget.getName()))
    end
end)

RegisterNetEvent('esx_vehicleshop:getStockItem')

AddEventHandler('esx_vehicleshop:getStockItem', function(itemName, count)
    local source = source
    local xPlayer = ESX.Player(source)

    count = getValidCount(count)

    if not count or (not canUseCardealerStock(xPlayer, source) and not canUseCardealerReseller(xPlayer, source)) then
        print(('[^3WARNING^7] Player ^5%s^7 attempted invalid cardealer stock withdrawal!'):format(source))
        return
    end

    TriggerEvent('esx_addoninventory:getSharedInventory', 'society_cardealer', function(inventory)
        local item = inventory.getItem(itemName)

        -- is there enough in the society?
        if count > 0 and item.count >= count then
            -- can the player carry the said amount of x item?
            if not xPlayer.canCarryItem(itemName, count) then
                return xPlayer.showNotification(TranslateCap('player_cannot_hold'))
            end

            inventory.removeItem(itemName, count)
            xPlayer.addInventoryItem(itemName, count)
            xPlayer.showNotification(TranslateCap('have_withdrawn', count, item.label))
        else
            xPlayer.showNotification(TranslateCap('not_enough_in_society'))
        end
    end)
end)

RegisterNetEvent('esx_vehicleshop:putStockItems')

AddEventHandler('esx_vehicleshop:putStockItems', function(itemName, count)
    local source = source
    local xPlayer = ESX.Player(source)

    count = getValidCount(count)

    if not count or (not canUseCardealerStock(xPlayer, source) and not canUseCardealerReseller(xPlayer, source)) then
        print(('[^3WARNING^7] Player ^5%s^7 attempted invalid cardealer stock deposit!'):format(source))
        return
    end

    TriggerEvent('esx_addoninventory:getSharedInventory', 'society_cardealer', function(inventory)
        local item = inventory.getItem(itemName)
        local sourceItem = xPlayer.getInventoryItem(itemName)

        if sourceItem and sourceItem.count >= count then
            xPlayer.removeInventoryItem(itemName, count)
            inventory.addItem(itemName, count)
            xPlayer.showNotification(TranslateCap('have_deposited', count, item.label))
        else
            xPlayer.showNotification(TranslateCap('invalid_amount'))
        end
    end)
end)

xLib.callback.registerCompat('esx_vehicleshop:buyVehicle', function(source, cb, model, plate)
    local xPlayer = ESX.Player(source)
    local vehicleData = type(model) == 'string' and getVehicleFromModel(model)
    local modelPrice = vehicleData and tonumber(vehicleData.price)

    plate = generateServerPlate()

    if not xPlayer or not modelPrice or not plate or not isNear(source, Config.Zones.ShopInside.Pos, 30.0) then
        return cb(false)
    end

    if modelPrice and xPlayer.getMoney() >= modelPrice then
        xPlayer.removeMoney(modelPrice, 'Vehicle Purchase')

        MySQL.insert(
            'INSERT INTO owned_vehicles (owner, plate, vehicle) VALUES (?, ?, ?)',
            { xPlayer.getIdentifier(), plate, json.encode({ model = joaat(model), plate = plate }) },
            function(insertId)
                if not insertId then
                    xPlayer.addMoney(modelPrice, 'Vehicle Purchase Refund')
                    return cb(false)
                end

                xPlayer.showNotification(TranslateCap('vehicle_belongs', plate))

                ESX.OneSync.SpawnVehicle(joaat(model), Config.Zones.ShopOutside.Pos, Config.Zones.ShopOutside.Heading, { plate = plate }, function(vehicle)
                    Wait(100)

                    local vehicle = NetworkGetEntityFromNetworkId(vehicle)

                    Wait(300)
                    TaskWarpPedIntoVehicle(GetPlayerPed(source), vehicle, -1)
                end)

                cb(true)
            end
        )
    else
        cb(false)
    end
end)

xLib.callback.registerCompat('esx_vehicleshop:getCommercialVehicles', function(source, cb)
    local xPlayer = ESX.Player(source)

    if not canUseCardealerShowroom(xPlayer, source) and not canUseCardealerStock(xPlayer, source) and not canUseCardealerReseller(xPlayer, source) then
        return cb({})
    end

    MySQL.query('SELECT price, vehicle FROM cardealer_vehicles ORDER BY vehicle ASC', function(result)
        cb(result)
    end)
end)

xLib.callback.registerCompat('esx_vehicleshop:buyCarDealerVehicle', function(source, cb, model)
    local xPlayer = ESX.Player(source)

    if not canUseCardealerShowroom(xPlayer, source) then
        return cb(false)
    end

    local vehicleData = type(model) == 'string' and getVehicleFromModel(model)
    local modelPrice = vehicleData and tonumber(vehicleData.price)

    if not modelPrice then
        return cb(false)
    end

    TriggerEvent('esx_addonaccount:getSharedAccount', 'society_cardealer', function(account)
        if not account or account.money < modelPrice then
            return cb(false)
        end

        account.removeMoney(modelPrice)

        MySQL.insert('INSERT INTO cardealer_vehicles (vehicle, price) VALUES (?, ?)', { model, modelPrice }, function(insertId)
            if not insertId then
                account.addMoney(modelPrice)
                return cb(false)
            end

            cb(true)
        end)
    end)
end)

RegisterNetEvent('esx_vehicleshop:returnProvider')

AddEventHandler('esx_vehicleshop:returnProvider', function(vehicleModel)
    local xPlayer = ESX.Player(source)

    if not canUseCardealerStock(xPlayer, source) and not canUseCardealerReseller(xPlayer, source) then
        return
    end

    MySQL.single('SELECT id, price FROM cardealer_vehicles WHERE vehicle = ?', { vehicleModel }, function(result)
        if not result then
            return print(('[^3WARNING^7] Player ^5%s^7 Attempted To Sell Invalid Vehicle - ^5%s^7!'):format(source, vehicleModel))
        end

        local id = result.id

        MySQL.update('DELETE FROM cardealer_vehicles WHERE id = ?', { id }, function(rowsChanged)
            if rowsChanged ~= 1 then
                return
            end

            TriggerEvent('esx_addonaccount:getSharedAccount', 'society_cardealer', function(account)
                local price = ESX.Math.Round(result.price * 0.75)
                local vehicleLabel = getVehicleFromModel(vehicleModel).name

                account.addMoney(price)
                xPlayer.showNotification(TranslateCap('vehicle_sold_for', vehicleLabel, ESX.Math.GroupDigits(price)))
            end)
        end)
    end)
end)

xLib.callback.registerCompat('esx_vehicleshop:getRentedVehicles', function(source, cb)
    local xPlayer = ESX.Player(source)

    if not canUseCardealerStock(xPlayer, source) then
        return cb({})
    end

    MySQL.query('SELECT * FROM rented_vehicles ORDER BY player_name ASC', function(result)
        local vehicles = {}

        for i = 1, #result do
            local vehicle = result[i]

            vehicles[#vehicles + 1] = {
                name = vehicle.vehicle,
                plate = vehicle.plate,
                playerName = vehicle.player_name,
            }
        end

        cb(vehicles)
    end)
end)

xLib.callback.registerCompat('esx_vehicleshop:giveBackVehicle', function(source, cb, plate)
    if not VehicleShopDatabaseReady then
        return cb(false)
    end

    local xPlayer = ESX.Player(source)

    plate = normalizePlate(plate)

    if not xPlayer or not plate or not isNear(source, Config.Zones.GiveBackVehicle.Pos, 12.0) or not isNearVehicleWithPlate(source, plate, 8.0) then
        return cb(false)
    end

    local owner = xPlayer.getIdentifier()

    if not MySQL.scalar.await('SELECT 1 FROM rented_vehicles WHERE owner = ? AND plate = ?', { owner, plate }) then
        return cb(false)
    end

    local ok, committed = pcall(MySQL.transaction.await, {
        { query = 'SELECT plate FROM rented_vehicles WHERE owner = ? AND plate = ? FOR UPDATE', values = { owner, plate } },
        {
            query = 'INSERT INTO cardealer_vehicles (vehicle, price) SELECT vehicle, base_price FROM rented_vehicles WHERE owner = ? AND plate = ?',
            values = { owner, plate },
        },
        {
            query = 'DELETE FROM owned_vehicles WHERE owner = ? AND plate = ? AND EXISTS (SELECT 1 FROM rented_vehicles WHERE owner = ? AND plate = ?)',
            values = { owner, plate, owner, plate },
        },
        { query = 'DELETE FROM rented_vehicles WHERE owner = ? AND plate = ?', values = { owner, plate } },
    })

    cb(ok and committed == true)
end)

xLib.callback.registerCompat('esx_vehicleshop:resellVehicle', function(source, cb, plate, model)
    local xPlayer, resellPrice = ESX.Player(source)

    plate = normalizePlate(plate)

    if
        xPlayer
        and plate
        and isNear(source, Config.Zones.ResellVehicle.Pos, 12.0)
        and (xPlayer.getJob().name == 'cardealer' or not Config.EnablePlayerManagement)
    then
        -- calculate the resell price
        for i = 1, #vehicles, 1 do
            if joaat(vehicles[i].model) == model then
                resellPrice = ESX.Math.Round(vehicles[i].price / 100 * Config.ResellPercentage)
                break
            end
        end

        if not resellPrice then
            print(('[^3WARNING^7] Player ^5%s^7 Attempted To Resell Invalid Vehicle - ^5%s^7!'):format(source, model))
            return cb(false)
        end

        MySQL.single('SELECT * FROM rented_vehicles WHERE plate = ?', { plate }, function(result)
            if result then -- is it a rented vehicle?
                return cb(false) -- it is, don't let the player sell it since he doesn't own it
            end

            MySQL.single('SELECT * FROM owned_vehicles WHERE owner = ? AND plate = ?', { xPlayer.getIdentifier(), plate }, function(result)
                if not result then -- does the owner match?
                    return cb(false)
                end

                local vehicle = json.decode(result.vehicle or '{}')

                if not vehicle or vehicle.model ~= model then
                    print(('[^3WARNING^7] Player ^5%s^7 Attempted To Resell Vehicle With Invalid Model - ^5%s^7!'):format(source, model))
                    return cb(false)
                end

                if normalizePlate(vehicle.plate) ~= plate then
                    print(('[^3WARNING^7] Player ^5%s^7 Attempted To Resell Vehicle With Invalid Plate - ^5%s^7!'):format(source, plate))
                    return cb(false)
                end

                MySQL.update('DELETE FROM owned_vehicles WHERE owner = ? AND plate = ?', { xPlayer.getIdentifier(), plate }, function(rowsChanged)
                    if rowsChanged ~= 1 then
                        return cb(false)
                    end

                    xPlayer.addMoney(resellPrice, 'Sold Vehicle')
                    cb(true)
                end)
            end)
        end)
    else
        cb(false)
    end
end)

xLib.callback.registerCompat('esx_vehicleshop:getStockItems', function(source, cb)
    local xPlayer = ESX.Player(source)

    if not canUseCardealerStock(xPlayer, source) and not canUseCardealerReseller(xPlayer, source) then
        return cb({})
    end

    TriggerEvent('esx_addoninventory:getSharedInventory', 'society_cardealer', function(inventory)
        cb(inventory.items)
    end)
end)

xLib.callback.registerCompat('esx_vehicleshop:getPlayerInventory', function(source, cb)
    local xPlayer = ESX.Player(source)
    local items = xPlayer.getInventory(true)

    cb({ items = items })
end)

xLib.callback.registerCompat('esx_vehicleshop:isPlateTaken', function(source, cb, plate)
    MySQL.scalar('SELECT plate FROM owned_vehicles WHERE plate = ?', { plate }, function(result)
        cb(result ~= nil)
    end)
end)

xLib.callback.registerCompat('esx_vehicleshop:retrieveJobVehicles', function(source, cb, type)
    local xPlayer = ESX.Player(source)

    if not xPlayer then
        return cb({})
    end

    MySQL.query(
        'SELECT * FROM owned_vehicles WHERE owner = ? AND type = ? AND job = ?',
        { xPlayer.getIdentifier(), type, xPlayer.getJob().name },
        function(result)
            cb(result)
        end
    )
end)

RegisterNetEvent('esx_vehicleshop:setJobVehicleState')

AddEventHandler('esx_vehicleshop:setJobVehicleState', function(plate, state)
    local source = source
    local xPlayer = ESX.Player(source)

    plate = normalizePlate(plate)

    if state ~= true and state ~= false and state ~= 0 and state ~= 1 then
        return
    end

    state = state == true or state == 1

    if not xPlayer or not plate or not isNearVehicleWithPlate(source, plate, 12.0) then
        return
    end

    if state then
        return
    end

    MySQL.update(
        'UPDATE owned_vehicles SET stored = 0 WHERE owner = ? AND plate = ? AND job = ? AND stored = 1',
        { xPlayer.getIdentifier(), plate, xPlayer.getJob().name }
    )
end)
