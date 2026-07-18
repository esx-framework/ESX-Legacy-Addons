---@param identifier string
---@param plate string
---@return OwnedVehicleRow?
local function ownedRow(identifier, plate)
    return MySQL.single.await(
        'SELECT `plate`, `vehicle`, `type`, `stored`, `parking`, `pound`, `custom_name`, `is_favorite`, `last_used`, `mileage` FROM `owned_vehicles` WHERE `owner` = ? AND `plate` = ?',
        { identifier, plate })
end

---@param p string
---@return string
local function normPlate(p)
    return (p:gsub('%s+$', '')):upper()
end

---@param xPlayer table
---@param amount integer
---@return boolean
local function charge(xPlayer, amount)
    if amount <= 0 then
        return true
    end

    if xPlayer.getMoney() >= amount then
        xPlayer.removeMoney(amount, 'Impound fee')
        return true
    end

    local bank = xPlayer.getAccount('bank')
    if bank and bank.money >= amount then
        xPlayer.removeAccountMoney('bank', amount, 'Impound fee')
        return true
    end

    return false
end

---@param xPlayer table
---@param amount integer
---@return boolean
local function canAfford(xPlayer, amount)
    if amount <= 0 then
        return true
    end

    if xPlayer.getMoney() >= amount then
        return true
    end

    local bank = xPlayer.getAccount('bank')
    return bank ~= nil and bank.money >= amount
end

---@param location table
---@param spawn table
---@return boolean
local function isConfiguredSpawn(location, spawn)
    local spawns = location.spawns
    if type(spawns) ~= 'table' then
        return false
    end

    for i = 1, #spawns do
        local s = spawns[i]
        if #(vec3(s.x, s.y, s.z) - vec3(spawn.x, spawn.y, spawn.z)) < 1.0 then
            return true
        end
    end

    return false
end

---@param source integer
---@param location table
---@return boolean
local function isNearLocation(source, location)
    local ped = GetPlayerPed(source)
    if not ped or ped <= 0 then
        return false
    end

    local anchor = location.entryPoint or location.getOutPoint
    if not anchor then
        return true
    end

    local tolerance = (Config.Settings.interactionDistance or 3.0) + 10.0

    return #(GetEntityCoords(ped) - vec3(anchor.x, anchor.y, anchor.z)) <= tolerance
end

---@param plateKey string
local function purgeWorldVehicle(plateKey)
    local vehicles = GetAllVehicles()

    for i = 1, #vehicles do
        local veh = vehicles[i]
        if normPlate(GetVehicleNumberPlateText(veh) or '') == plateKey then
            DeleteEntity(veh)
        end
    end
end

---@type table<string, boolean>
local retrieving = {}

ESX.RegisterServerCallback('esx_garage:getVehicles', function(source, cb, garageId)
    local waited = 0
    while not GarageReady and waited < 10000 do
        Wait(50)
        waited = waited + 50
    end

    if not GarageReady then
        return cb(false)
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return cb(false)
    end

    local garage = garageId and Garages[garageId]
    if garage and not CanAccessGarage(source, garage) then
        return cb(false)
    end

    local rows = MySQL.query.await('SELECT * FROM `owned_vehicles` WHERE `owner` = ?', { xPlayer.identifier }) or {}

    if Config.Settings.restrictToGarage and garageId then
        local filtered = {}

        for i = 1, #rows do
            local row = rows[i]
            if row.stored ~= 1 or row.pound ~= nil
                or not row.parking or not Garages[row.parking] or row.parking == garageId then
                filtered[#filtered + 1] = row
            end
        end

        rows = filtered
    end

    cb(rows)
end)

ESX.RegisterServerCallback('esx_garage:retrieveVehicle', function(source, cb, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return cb({ success = false, error = 'player' })
    end

    local plate = data and data.plate
    local spawn = data and data.spawn
    if type(plate) ~= 'string' or type(spawn) ~= 'table'
        or type(spawn.x) ~= 'number' or type(spawn.y) ~= 'number' or type(spawn.z) ~= 'number' then
        return cb({ success = false, error = 'invalid' })
    end

    local key = normPlate(plate)
    if retrieving[key] then
        return cb({ success = false, error = 'busy' })
    end
    retrieving[key] = true

    local ok, result = pcall(function()
        local row = ownedRow(xPlayer.identifier, plate)
        if not row then
            return { success = false, error = 'not_owned' }
        end

        local location = data.garageId and (Garages[data.garageId] or Impounds[data.garageId])
        if not location then
            return { success = false, error = 'no_location' }
        end

        local garage = Garages[data.garageId]
        if garage and not CanAccessGarage(source, garage) then
            return { success = false, error = 'not_allowed' }
        end

        if not isConfiguredSpawn(location, spawn) then
            return { success = false, error = 'bad_spawn' }
        end

        if not isNearLocation(source, location) then
            return { success = false, error = 'too_far' }
        end

        local outOfSync = row.stored ~= 1
        local fee = 0

        if row.pound or outOfSync then
            if not Impounds[data.garageId] then
                return { success = false, error = 'use_impound' }
            end

            local lot = Impounds[row.pound] or Impounds[data.garageId]
            fee = (lot and lot.cost) or Config.Settings.defaultImpoundFee
            if not canAfford(xPlayer, fee) then
                return { success = false, error = 'no_money' }
            end
        elseif Config.Settings.restrictToGarage and row.parking and Garages[row.parking]
            and row.parking ~= data.garageId then
            return { success = false, error = 'wrong_garage' }
        end

        local existing = ESX.GetExtendedVehicleFromPlate(row.plate)
        if existing then
            existing:delete()
        elseif row.stored ~= 1 then
            MySQL.update.await('UPDATE `owned_vehicles` SET `stored` = 1 WHERE `owner` = ? AND `plate` = ?',
                { xPlayer.identifier, plate })
        end

        purgeWorldVehicle(key)

        local coords = vec4(spawn.x, spawn.y, spawn.z, spawn.w or spawn.h or 0.0)
        local xVehicle = ESX.CreateExtendedVehicle(xPlayer.identifier, row.plate, coords)
        if not xVehicle then
            return { success = false, error = 'spawn_failed' }
        end

        if fee > 0 and not charge(xPlayer, fee) then
            xVehicle:delete()
            return { success = false, error = 'no_money' }
        end

        MySQL.update('UPDATE `owned_vehicles` SET `pound` = NULL, `last_used` = ? WHERE `owner` = ? AND `plate` = ?',
            { os.time(), xPlayer.identifier, plate })

        return { success = true, data = { netId = xVehicle:getNetId() } }
    end)

    retrieving[key] = nil

    if not ok then
        return cb({ success = false, error = 'error' })
    end

    cb(result)
end)

ESX.RegisterServerCallback('esx_garage:storeVehicle', function(source, cb, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return cb({ success = false, error = 'player' })
    end

    local plate = data and data.plate
    local props = data and data.props
    if type(plate) ~= 'string' or type(props) ~= 'table' then
        return cb({ success = false, error = 'invalid' })
    end

    local garageId = data.garageId
    local garage = garageId and Garages[garageId]
    if not garage then
        return cb({ success = false, error = 'no_location' })
    end

    if not CanAccessGarage(source, garage) then
        return cb({ success = false, error = 'not_allowed' })
    end

    if not isNearLocation(source, garage) then
        return cb({ success = false, error = 'too_far' })
    end

    local key = normPlate(plate)
    if retrieving[key] then
        return cb({ success = false, error = 'busy' })
    end
    retrieving[key] = true

    local ok, result = pcall(function()
        local row = ownedRow(xPlayer.identifier, plate)
        if not row then
            return { success = false, error = 'not_owned' }
        end

        if row.stored == 1 then
            return { success = false, error = 'already_stored' }
        end

        props.plate = row.plate

        local xVehicle = ESX.GetExtendedVehicleFromPlate(row.plate)
        if xVehicle then
            local ent = xVehicle:getEntity()
            if ent and ent > 0 then
                props.model = GetEntityModel(ent)
            end

            xVehicle:delete(garageId)

            MySQL.update.await('UPDATE `owned_vehicles` SET `vehicle` = ? WHERE `owner` = ? AND `plate` = ?',
                { json.encode(props), xPlayer.identifier, plate })
        else
            local ped = GetPlayerPed(source)
            local entity = (ped and ped > 0) and GetVehiclePedIsIn(ped, false) or 0

            if not (entity and entity > 0 and DoesEntityExist(entity)) then
                local netEntity = data.netId and NetworkGetEntityFromNetworkId(data.netId) or 0
                local pedCoords = (ped and ped > 0) and GetEntityCoords(ped)
                if netEntity and netEntity > 0 and DoesEntityExist(netEntity)
                    and pedCoords and #(pedCoords - GetEntityCoords(netEntity)) < 6.0 then
                    entity = netEntity
                else
                    return { success = false, error = 'no_vehicle' }
                end
            end

            local entPlate = normPlate(GetVehicleNumberPlateText(entity) or '')
            if entPlate ~= key then
                return { success = false, error = 'plate_mismatch' }
            end

            props.model = GetEntityModel(entity)
            DeleteEntity(entity)

            MySQL.update.await(
                'UPDATE `owned_vehicles` SET `stored` = 1, `parking` = ?, `pound` = NULL, `vehicle` = ? WHERE `owner` = ? AND `plate` = ?',
                { garageId, json.encode(props), xPlayer.identifier, plate })
        end

        MySQL.update('UPDATE `owned_vehicles` SET `last_used` = ? WHERE `owner` = ? AND `plate` = ?',
            { os.time(), xPlayer.identifier, plate })

        return { success = true, data = true }
    end)

    retrieving[key] = nil

    if not ok then
        return cb({ success = false, error = 'error' })
    end

    cb(result)
end)

ESX.RegisterServerCallback('esx_garage:toggleFavorite', function(source, cb, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return cb({ success = false })
    end

    local plate = data and data.plate
    if type(plate) ~= 'string' or type(data.isFavorite) ~= 'boolean' then
        return cb({ success = false, error = 'invalid' })
    end

    local affected = MySQL.update.await('UPDATE `owned_vehicles` SET `is_favorite` = ? WHERE `owner` = ? AND `plate` = ?',
        { data.isFavorite and 1 or 0, xPlayer.identifier, plate })

    cb({ success = (affected or 0) > 0, data = data.isFavorite })
end)

ESX.RegisterServerCallback('esx_garage:renameVehicle', function(source, cb, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return cb({ success = false })
    end

    local plate = data and data.plate
    local name = data and data.name
    if type(plate) ~= 'string' or type(name) ~= 'string' or #name < 1 or #name > 50 then
        return cb({ success = false, error = 'invalid' })
    end

    local affected = MySQL.update.await('UPDATE `owned_vehicles` SET `custom_name` = ? WHERE `owner` = ? AND `plate` = ?',
        { name, xPlayer.identifier, plate })

    cb({ success = (affected or 0) > 0, data = name })
end)

ESX.RegisterServerCallback('esx_garage:transferVehicle', function(source, cb, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return cb({ success = false })
    end

    local plate = data and data.plate
    local targetId = tonumber(data and data.targetId)
    if type(plate) ~= 'string' or not targetId then
        return cb({ success = false, error = 'invalid' })
    end

    local target = ESX.GetPlayerFromId(targetId)
    if not target then
        return cb({ success = false, error = 'target_offline' })
    end

    if target.identifier == xPlayer.identifier then
        return cb({ success = false, error = 'self' })
    end

    local key = normPlate(plate)
    if retrieving[key] then
        return cb({ success = false, error = 'busy' })
    end
    retrieving[key] = true

    local ok, result = pcall(function()
        local row = ownedRow(xPlayer.identifier, plate)
        if not row then
            return { success = false, error = 'not_owned' }
        end

        if row.stored ~= 1 then
            return { success = false, error = 'not_stored' }
        end

        local affected = MySQL.update.await('UPDATE `owned_vehicles` SET `owner` = ? WHERE `owner` = ? AND `plate` = ?',
            { target.identifier, xPlayer.identifier, plate })

        if (affected or 0) < 1 then
            return { success = false }
        end

        TriggerEvent('esx_garage:vehicleTransferred', source, targetId, plate, xPlayer.identifier, target.identifier)

        return { success = true }
    end)

    retrieving[key] = nil

    if not ok then
        return cb({ success = false, error = 'error' })
    end

    cb(result)
end)

ESX.RegisterServerCallback('esx_garage:giveKeys', function(source, cb, data)
    if not Config.Settings.vehicleKeys then
        return cb({ success = false, error = 'disabled' })
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return cb({ success = false })
    end

    local plate = data and data.plate
    if type(plate) ~= 'string' then
        return cb({ success = false, error = 'invalid' })
    end

    local row = ownedRow(xPlayer.identifier, plate)
    if not row then
        return cb({ success = false, error = 'not_owned' })
    end

    TriggerEvent('esx_garage:giveKeys', source, plate)

    cb({ success = true })
end)

---@param plate string
---@param lot string? defaults to the first configured impound
---@return boolean
local function impoundVehicle(plate, lot)
    if type(plate) ~= 'string' then
        return false
    end

    local lotId = (type(lot) == 'string' and Impounds[lot]) and lot or nil

    if not lotId then
        if lot ~= nil then
            print(('[esx_garage] impoundVehicle: unknown impound "%s", falling back to the default lot'):format(tostring(lot)))
        end

        local fallback = Config.Impounds and Config.Impounds[1]
        lotId = fallback and fallback.id or nil
    end

    if not lotId then
        print('[esx_garage] impoundVehicle: no impound configured, aborting')
        return false
    end

    local xVehicle = ESX.GetExtendedVehicleFromPlate(plate)

    if xVehicle then
        xVehicle:delete(lotId, true)
    else
        MySQL.update.await(
            'UPDATE `owned_vehicles` SET `stored` = 1, `pound` = ?, `parking` = NULL WHERE `plate` = ?',
            { lotId, plate })
    end

    local settled = MySQL.scalar.await(
        'SELECT COUNT(*) FROM `owned_vehicles` WHERE `plate` = ? AND `stored` = 1 AND `pound` = ?',
        { plate, lotId }) or 0

    if settled < 1 then
        return false
    end

    purgeWorldVehicle(normPlate(plate))

    return true
end

exports('impoundVehicle', impoundVehicle)
