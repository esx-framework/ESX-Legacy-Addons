local MAX_PROPS_BYTES <const> = 16384
local MAX_PROPS_DEPTH <const> = 4

---@param p string
---@return string
local function normPlate(p)
    return (p:gsub("%s+$", "")):upper()
end

---@param identifier string
---@param plate string
---@return OwnedVehicleRow?
local function ownedRow(identifier, plate)
    return MySQL.single.await(
        "SELECT `plate`, `vehicle`, `type`, `stored`, `parking`, `pound`, `custom_name`, `is_favorite`, `last_used`, `mileage` FROM `owned_vehicles` WHERE `owner` = ? AND TRIM(TRAILING ' ' FROM `plate`) = ?",
        { identifier, normPlate(plate) })
end

---Strips anything a vehicle props table cannot legitimately contain: exotic
---types, oversized strings, deep nesting. Returns nil when the input is not a
---table at all.
---@param value any
---@param depth integer
---@return any
local function cleanPropsValue(value, depth)
    local valueType = type(value)

    if valueType == "number" or valueType == "boolean" or valueType == "vector3" or valueType == "vector4" then
        return value
    end

    if valueType == "string" then
        return #value <= 128 and value or nil
    end

    if valueType == "table" and depth < MAX_PROPS_DEPTH then
        local out = {}
        for k, v in pairs(value) do
            local keyType = type(k)
            if keyType == "number" or (keyType == "string" and #k <= 64) then
                local cleaned = cleanPropsValue(v, depth + 1)
                if cleaned ~= nil then
                    out[k] = cleaned
                end
            end
        end
        return out
    end

    return nil
end

---@param props table
---@return string?
local function encodeProps(props)
    local encoded = json.encode(props)
    if not encoded or #encoded > MAX_PROPS_BYTES then
        return nil
    end

    return encoded
end

---@param row OwnedVehicleRow
---@param entity integer
---@return boolean, number?
local function validateStoredModel(row, entity)
    if not row or type(row.vehicle) ~= "string" then
        return false, nil
    end

    local ok, storedProps = pcall(json.decode, row.vehicle)
    if not ok or type(storedProps) ~= "table" then
        return false, nil
    end

    local storedModel = tonumber(storedProps.model)
    if not storedModel then
        return false, nil
    end

    local entityModel = GetEntityModel(entity)
    if not entityModel then
        return false, nil
    end

    if entityModel ~= storedModel then
        return false, nil
    end

    return true, storedModel
end

---@param xPlayer table
---@param amount integer
---@return boolean
local function charge(xPlayer, amount)
    if amount <= 0 then
        return true
    end

    if xPlayer.getMoney() >= amount then
        xPlayer.removeMoney(amount, "Impound fee")
        return true
    end

    local bank = xPlayer.getAccount("bank")
    if bank and bank.money >= amount then
        xPlayer.removeAccountMoney("bank", amount, "Impound fee")
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

    local bank = xPlayer.getAccount("bank")
    return bank ~= nil and bank.money >= amount
end

---@param location table
---@param spawn table
---@return boolean
local function isConfiguredSpawn(location, spawn)
    local spawns = location.spawns
    if type(spawns) ~= "table" then
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

---@param spawn table
---@return boolean
local function isSpawnBlocked(spawn)
    local spawnCoords = vec3(spawn.x, spawn.y, spawn.z)
    local vehicles = GetAllVehicles()

    for i = 1, #vehicles do
        if #(GetEntityCoords(vehicles[i]) - spawnCoords) < 2.0 then
            return true
        end
    end

    return false
end

---@param plateKey string
---@param managedEntity integer?
---@return boolean
local function hasUnmanagedWorldVehicle(plateKey, managedEntity)
    local vehicles = GetAllVehicles()

    for i = 1, #vehicles do
        local veh = vehicles[i]
        if veh ~= managedEntity and normPlate(GetVehicleNumberPlateText(veh) or "") == plateKey then
            return true
        end
    end

    return false
end

---@type table<string, boolean>
local retrieving = {}

ESX.RegisterServerCallback("esx_garage:getVehicles", function(source, cb, garageId)
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

    local rows = MySQL.query.await("SELECT * FROM `owned_vehicles` WHERE `owner` = ?", { xPlayer.identifier }) or {}

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

ESX.RegisterServerCallback("esx_garage:retrieveVehicle", function(source, cb, data)
    if not GarageReady then
        return cb({ success = false, error = "error" })
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return cb({ success = false, error = "player" })
    end

    local plate = data and data.plate
    local spawn = data and data.spawn
    if type(plate) ~= "string" or type(spawn) ~= "table"
        or type(spawn.x) ~= "number" or type(spawn.y) ~= "number" or type(spawn.z) ~= "number"
        or (spawn.w ~= nil and type(spawn.w) ~= "number") or (spawn.h ~= nil and type(spawn.h) ~= "number") then
        return cb({ success = false, error = "invalid" })
    end

    local key = normPlate(plate)
    if retrieving[key] then
        return cb({ success = false, error = "busy" })
    end
    retrieving[key] = true

    local ok, result = pcall(function()
        local row = ownedRow(xPlayer.identifier, plate)
        if not row then
            return { success = false, error = "not_owned" }
        end

        local location = data.garageId and (Garages[data.garageId] or Impounds[data.garageId])
        if not location then
            return { success = false, error = "no_location" }
        end

        local garage = Garages[data.garageId]
        local impound = Impounds[data.garageId]

        if garage and not CanAccessGarage(source, garage) then
            return { success = false, error = "not_allowed" }
        end

        if not isConfiguredSpawn(location, spawn) then
            return { success = false, error = "bad_spawn" }
        end

        if not isNearLocation(source, location) then
            return { success = false, error = "too_far" }
        end

        local existing = ESX.GetExtendedVehicleFromPlate(row.plate)
        local managedEntity = nil

        if existing then
            local entity = existing:getEntity()
            if entity and entity > 0 and DoesEntityExist(entity) then
                managedEntity = entity
            end
        end

        local hasWorldVehicle = managedEntity ~= nil or hasUnmanagedWorldVehicle(key, managedEntity)

        local fee = 0

        if row.pound then
            if not impound then
                return { success = false, error = "use_impound" }
            end
            if row.pound ~= data.garageId then
                return { success = false, error = "wrong_impound" }
            end
            if hasWorldVehicle then
                return { success = false, error = "not_stored" }
            end

            local lot = Impounds[row.pound]
            fee = (lot and lot.cost) or Config.Settings.defaultImpoundFee
        elseif row.stored ~= 1 then
            if hasWorldVehicle then
                return { success = false, error = "not_stored" }
            end
            if not impound then
                return { success = false, error = "use_impound" }
            end

            local lot = Impounds[data.garageId]
            fee = (lot and lot.cost) or Config.Settings.defaultImpoundFee
        else
            if impound then
                return { success = false, error = "not_impounded" }
            end
            if hasWorldVehicle then
                return { success = false, error = "not_stored" }
            end
            if Config.Settings.restrictToGarage and row.parking and Garages[row.parking]
                and row.parking ~= data.garageId then
                return { success = false, error = "wrong_garage" }
            end
        end

        if fee > 0 and not canAfford(xPlayer, fee) then
            return { success = false, error = "no_money" }
        end

        if existing then
            existing:delete()
        elseif row.stored ~= 1 then
            MySQL.update.await("UPDATE `owned_vehicles` SET `stored` = 1 WHERE `owner` = ? AND `plate` = ?",
                { xPlayer.identifier, row.plate })
        end

        if isSpawnBlocked(spawn) then
            return { success = false, error = "blocked" }
        end

        local coords = vec4(spawn.x, spawn.y, spawn.z, spawn.w or spawn.h or 0.0)
        local xVehicle = ESX.CreateExtendedVehicle(xPlayer.identifier, row.plate, coords)
        if not xVehicle then
            return { success = false, error = "spawn_failed" }
        end

        if fee > 0 and not charge(xPlayer, fee) then
            xVehicle:delete()
            return { success = false, error = "no_money" }
        end

        MySQL.update("UPDATE `owned_vehicles` SET `pound` = NULL, `parking` = NULL, `last_used` = ? WHERE `owner` = ? AND `plate` = ?",
            { os.time(), xPlayer.identifier, row.plate })

        return { success = true, data = { netId = xVehicle:getNetId() } }
    end)

    retrieving[key] = nil

    if not ok then
        return cb({ success = false, error = "error" })
    end

    cb(result)
end)

ESX.RegisterServerCallback("esx_garage:storeVehicle", function(source, cb, data)
    if not GarageReady then
        return cb({ success = false, error = "error" })
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return cb({ success = false, error = "player" })
    end

    local plate = data and data.plate
    local props = data and data.props
    if type(plate) ~= "string" or type(props) ~= "table" then
        return cb({ success = false, error = "invalid" })
    end

    props = cleanPropsValue(props, 0)
    if type(props) ~= "table" then
        return cb({ success = false, error = "invalid" })
    end

    local garageId = data.garageId
    local garage = garageId and Garages[garageId]
    if not garage then
        return cb({ success = false, error = "no_location" })
    end

    if not CanAccessGarage(source, garage) then
        return cb({ success = false, error = "not_allowed" })
    end

    if not isNearLocation(source, garage) then
        return cb({ success = false, error = "too_far" })
    end

    local key = normPlate(plate)
    if retrieving[key] then
        return cb({ success = false, error = "busy" })
    end
    retrieving[key] = true

    local ok, result = pcall(function()
        local row = ownedRow(xPlayer.identifier, plate)
        if not row then
            return { success = false, error = "not_owned" }
        end

        if row.stored == 1 then
            return { success = false, error = "already_stored" }
        end

        props.plate = row.plate

        local ped = GetPlayerPed(source)
        local pedCoords = (ped and ped > 0) and GetEntityCoords(ped)
        local pedVehicle = (ped and ped > 0) and GetVehiclePedIsIn(ped, false) or 0

        local xVehicle = ESX.GetExtendedVehicleFromPlate(row.plate)
        if xVehicle then
            local entity = xVehicle:getEntity()
            if not (entity and entity > 0 and DoesEntityExist(entity)) then
                return { success = false, error = "no_vehicle" }
            end

            if pedVehicle ~= entity and (not pedCoords or #(pedCoords - GetEntityCoords(entity)) > 6.0) then
                return { success = false, error = "no_vehicle" }
            end

            local modelOk, storedModel = validateStoredModel(row, entity)
            if not modelOk then
                return { success = false, error = "model_mismatch" }
            end

            props.model = storedModel

            local encoded = encodeProps(props)
            if not encoded then
                return { success = false, error = "invalid" }
            end

            xVehicle:delete(garageId)

            MySQL.update.await("UPDATE `owned_vehicles` SET `vehicle` = ? WHERE `owner` = ? AND `plate` = ?",
                { encoded, xPlayer.identifier, row.plate })
        else
            local entity = pedVehicle

            if not (entity and entity > 0 and DoesEntityExist(entity)) then
                local netEntity = data.netId and NetworkGetEntityFromNetworkId(data.netId) or 0
                if netEntity and netEntity > 0 and DoesEntityExist(netEntity)
                    and pedCoords and #(pedCoords - GetEntityCoords(netEntity)) < 6.0 then
                    entity = netEntity
                else
                    return { success = false, error = "no_vehicle" }
                end
            end

            local entPlate = normPlate(GetVehicleNumberPlateText(entity) or "")
            if entPlate ~= key then
                return { success = false, error = "plate_mismatch" }
            end

            local modelOk, storedModel = validateStoredModel(row, entity)
            if not modelOk then
                return { success = false, error = "model_mismatch" }
            end

            props.model = storedModel

            local encoded = encodeProps(props)
            if not encoded then
                return { success = false, error = "invalid" }
            end

            DeleteEntity(entity)

            MySQL.update.await(
                "UPDATE `owned_vehicles` SET `stored` = 1, `parking` = ?, `pound` = NULL, `vehicle` = ? WHERE `owner` = ? AND `plate` = ?",
                { garageId, encoded, xPlayer.identifier, row.plate })
        end

        MySQL.update("UPDATE `owned_vehicles` SET `last_used` = ? WHERE `owner` = ? AND `plate` = ?",
            { os.time(), xPlayer.identifier, row.plate })

        return { success = true, data = true }
    end)

    retrieving[key] = nil

    if not ok then
        return cb({ success = false, error = "error" })
    end

    cb(result)
end)

ESX.RegisterServerCallback("esx_garage:toggleFavorite", function(source, cb, data)
    if not GarageReady then
        return cb({ success = false, error = "error" })
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return cb({ success = false })
    end

    local plate = data and data.plate
    if type(plate) ~= "string" or type(data.isFavorite) ~= "boolean" then
        return cb({ success = false, error = "invalid" })
    end

    local ok, affected = pcall(MySQL.update.await,
        "UPDATE `owned_vehicles` SET `is_favorite` = ? WHERE `owner` = ? AND TRIM(TRAILING ' ' FROM `plate`) = ?",
        { data.isFavorite and 1 or 0, xPlayer.identifier, normPlate(plate) })

    if not ok then
        return cb({ success = false, error = "error" })
    end

    cb({ success = (affected or 0) > 0, data = data.isFavorite })
end)

ESX.RegisterServerCallback("esx_garage:renameVehicle", function(source, cb, data)
    if not GarageReady then
        return cb({ success = false, error = "error" })
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return cb({ success = false })
    end

    local plate = data and data.plate
    local name = data and data.name
    if type(plate) ~= "string" or type(name) ~= "string" or #name < 1 or #name > 50 then
        return cb({ success = false, error = "invalid" })
    end

    local ok, affected = pcall(MySQL.update.await,
        "UPDATE `owned_vehicles` SET `custom_name` = ? WHERE `owner` = ? AND TRIM(TRAILING ' ' FROM `plate`) = ?",
        { name, xPlayer.identifier, normPlate(plate) })

    if not ok then
        return cb({ success = false, error = "error" })
    end

    cb({ success = (affected or 0) > 0, data = name })
end)

ESX.RegisterServerCallback("esx_garage:transferVehicle", function(source, cb, data)
    if not GarageReady then
        return cb({ success = false, error = "error" })
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return cb({ success = false })
    end

    local plate = data and data.plate
    local targetId = tonumber(data and data.targetId)
    if type(plate) ~= "string" or not targetId then
        return cb({ success = false, error = "invalid" })
    end

    local target = ESX.GetPlayerFromId(targetId)
    if not target then
        return cb({ success = false, error = "target_offline" })
    end

    if target.identifier == xPlayer.identifier then
        return cb({ success = false, error = "self" })
    end

    local xPlayerPed = GetPlayerPed(source)
    local targetPed = GetPlayerPed(targetId)

    if xPlayerPed <= 0 or targetPed <= 0 or not DoesEntityExist(xPlayerPed) or not DoesEntityExist(targetPed) then
        return cb({ success = false, error = "player_ped" })
    end

    local dist = #(GetEntityCoords(xPlayerPed) - GetEntityCoords(targetPed))
    if dist > 10.0 then
        return cb({ success = false, error = "too_far" })
    end

    local key = normPlate(plate)
    if retrieving[key] then
        return cb({ success = false, error = "busy" })
    end
    retrieving[key] = true

    local ok, result = pcall(function()
        local row = ownedRow(xPlayer.identifier, plate)
        if not row then
            return { success = false, error = "not_owned" }
        end

        if row.stored ~= 1 then
            return { success = false, error = "not_stored" }
        end

        local affected = MySQL.update.await("UPDATE `owned_vehicles` SET `owner` = ? WHERE `owner` = ? AND `plate` = ?",
            { target.identifier, xPlayer.identifier, row.plate })

        if (affected or 0) < 1 then
            return { success = false }
        end

        target.showNotification(TranslateCap("received_vehicle", row.plate))

        TriggerEvent("esx_garage:vehicleTransferred", source, targetId, row.plate, xPlayer.identifier, target.identifier)

        return { success = true }
    end)

    retrieving[key] = nil

    if not ok then
        return cb({ success = false, error = "error" })
    end

    cb(result)
end)

ESX.RegisterServerCallback("esx_garage:giveKeys", function(source, cb, data)
    if not Config.Settings.vehicleKeys then
        return cb({ success = false, error = "disabled" })
    end

    if not GarageReady then
        return cb({ success = false, error = "error" })
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return cb({ success = false })
    end

    local plate = data and data.plate
    if type(plate) ~= "string" then
        return cb({ success = false, error = "invalid" })
    end

    local ok, row = pcall(ownedRow, xPlayer.identifier, plate)
    if not ok then
        return cb({ success = false, error = "error" })
    end

    if not row then
        return cb({ success = false, error = "not_owned" })
    end

    TriggerEvent("esx_garage:giveKeys", source, row.plate)

    cb({ success = true })
end)

---@param plate string
---@param lot string? defaults to the first configured impound
---@return boolean
local function impoundVehicle(plate, lot)
    if type(plate) ~= "string" then
        return false
    end

    local lotId = (type(lot) == "string" and Impounds[lot]) and lot or nil

    if not lotId then
        if lot ~= nil then
            print(("[esx_garage] impoundVehicle: unknown impound \"%s\", falling back to the default lot"):format(tostring(lot)))
        end

        local fallback = Config.Impounds and Config.Impounds[1]
        lotId = fallback and fallback.id or nil
    end

    if not lotId then
        print("[esx_garage] impoundVehicle: no impound configured, aborting")
        return false
    end

    local xVehicle = ESX.GetExtendedVehicleFromPlate(plate)

    if xVehicle then
        xVehicle:delete(lotId, true)
    else
        MySQL.update.await(
            "UPDATE `owned_vehicles` SET `stored` = 1, `pound` = ?, `parking` = NULL WHERE TRIM(TRAILING ' ' FROM `plate`) = ?",
            { lotId, normPlate(plate) })
    end

    local settled = MySQL.scalar.await(
        "SELECT COUNT(*) FROM `owned_vehicles` WHERE TRIM(TRAILING ' ' FROM `plate`) = ? AND `stored` = 1 AND `pound` = ?",
        { normPlate(plate), lotId }) or 0

    if settled < 1 then
        return false
    end

    return true
end

exports("impoundVehicle", impoundVehicle)
