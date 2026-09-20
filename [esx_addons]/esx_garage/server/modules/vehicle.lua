-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local MAX_PROPS_BYTES <const> = 16384
local MAX_PROPS_DEPTH <const> = 4
local MAX_PAGE <const> = 100
local MAX_SEARCH_LENGTH <const> = 64
local MAX_PLATE_LENGTH <const> = 12
local DEFAULT_PAGE_SIZE <const> = 30
local MAX_ALLOWED_PAGE_SIZE <const> = 100
local HUD_RESOURCE_NAME <const> = "esx_hud"
local VEHICLE_SELECT_COLUMNS <const> = table.concat({
    "`plate`",
    "`vehicle`",
    "`type`",
    "`stored`",
    "`parking`",
    "`pound`",
    "`custom_name`",
    "`is_favorite`",
    "`last_used`",
    "`mileage`",
}, ", ")

---@param p string
---@return string
local function normPlate(p)
    return (p:gsub("%s+$", "")):upper()
end

---@param value any
---@return boolean
local function isFiniteNumber(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

---@param value any
---@return integer
local function storedValue(value)
    return (value == true or value == 1 or value == "1") and 1 or 0
end

---@param value any
---@return boolean
local function isStored(value)
    return storedValue(value) == 1
end

---@param pound any
---@return string?
local function activePound(pound)
    return type(pound) == "string" and pound ~= "" and pound or nil
end

---@param rows OwnedVehicleRow[]
local function applyCachedHudMileage(rows)
    if type(GetResourceState) ~= "function" or GetResourceState(HUD_RESOURCE_NAME) ~= "started" then
        return
    end

    local plates = {}
    for i = 1, #rows do
        plates[#plates + 1] = rows[i].plate
    end

    local ok, mileages = pcall(function()
        return exports[HUD_RESOURCE_NAME]:GetMileages(plates)
    end)

    if not ok or type(mileages) ~= "table" then
        return
    end

    for i = 1, #rows do
        local mileage = tonumber(mileages[rows[i].plate])
        if mileage and mileage >= 0 then
            rows[i].mileage = mileage
        end
    end
end

---@param requested any
---@return integer
local function vehiclePage(requested)
    local page = tonumber(requested)
    if not isFiniteNumber(page) then
        return 1
    end

    page = math.floor(page)
    if page < 1 then
        return 1
    end

    return math.min(page, MAX_PAGE)
end

---@param value any
---@return string
local function vehicleSearch(value)
    if type(value) ~= "string" then
        return ""
    end

    local search = value:gsub("^%s+", ""):gsub("%s+$", "")
    if #search > MAX_SEARCH_LENGTH then
        search = search:sub(1, MAX_SEARCH_LENGTH)
    end

    return search
end

---@param plate any
---@return boolean
local function validPlate(plate)
    if type(plate) ~= "string" then
        return false
    end

    plate = normPlate(plate)

    return #plate >= 1
        and #plate <= MAX_PLATE_LENGTH
        and plate:match("[A-Z0-9]") ~= nil
        and plate:match("^[A-Z0-9 %-]+$") ~= nil
end

---@param values table
---@param value string
local function addUniquePlateValue(values, value)
    if value == "" then
        return
    end

    for i = 1, #values do
        if values[i] == value then
            return
        end
    end

    values[#values + 1] = value
end

---@param plate string
---@return string[]
local function plateValues(plate)
    local normalized = normPlate(plate)
    local values = {}

    addUniquePlateValue(values, plate)
    addUniquePlateValue(values, normalized)

    if #normalized > 0 and #normalized < 8 then
        addUniquePlateValue(values, normalized .. string.rep(" ", 8 - #normalized))
    end

    return values
end

---@param plate string
---@return string, table
local function plateCondition(plate)
    local values = plateValues(plate)

    if #values < 1 then
        return "`plate` = ?", { "" }
    end

    if #values == 1 then
        return "`plate` = ?", values
    end

    local placeholders = {}
    for i = 1, #values do
        placeholders[i] = "?"
    end

    return ("`plate` IN (%s)"):format(table.concat(placeholders, ", ")), values
end

---@param target table
---@param values table
local function appendParams(target, values)
    for i = 1, #values do
        target[#target + 1] = values[i]
    end
end

---@param value string
---@return string
local function escapeLike(value)
    return (value:gsub("([\\%%_])", "\\%1"))
end

---@param identifier string
---@param plate string
---@return OwnedVehicleRow?
local function ownedRow(identifier, plate)
    local condition, plateParams = plateCondition(plate)
    local params = { identifier }
    appendParams(params, plateParams)

    return MySQL.single.await(
        ("SELECT `plate`, `vehicle`, `type`, `stored`, `parking`, `pound`, `custom_name`, `is_favorite`, `last_used`, `mileage` FROM `owned_vehicles` WHERE `owner` = ? AND %s LIMIT 1"):format(condition),
        params)
end

---@param identifier string
---@param plate string
---@return string?
local function ownedPlate(identifier, plate)
    local condition, plateParams = plateCondition(plate)
    local params = { identifier }
    appendParams(params, plateParams)

    return MySQL.scalar.await(
        ("SELECT `plate` FROM `owned_vehicles` WHERE `owner` = ? AND %s LIMIT 1"):format(condition),
        params)
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
---@return number?
local function storedVehicleModel(row)
    if not row or type(row.vehicle) ~= "string" then
        return nil
    end

    local ok, storedProps = pcall(json.decode, row.vehicle)
    if not ok or type(storedProps) ~= "table" then
        return nil
    end

    return tonumber(storedProps.model)
end

---@param row OwnedVehicleRow
---@param entity integer
---@return boolean, number?
local function validateStoredModel(row, entity)
    local storedModel = storedVehicleModel(row)
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

---@param xVehicle table
---@return string?
local function extendedVehicleOwner(xVehicle)
    local ok, owner = pcall(function()
        if type(xVehicle.getOwner) == "function" then
            return xVehicle:getOwner()
        end

        return xVehicle.owner
    end)

    return ok and type(owner) == "string" and owner or nil
end

---@param xPlayer table
---@param amount integer
---@return boolean, string?
local function charge(xPlayer, amount)
    if amount <= 0 then
        return true
    end

    if xPlayer.getMoney() >= amount then
        xPlayer.removeMoney(amount, "Impound fee")
        return true, "money"
    end

    local bank = xPlayer.getAccount("bank")
    if bank and bank.money >= amount then
        xPlayer.removeAccountMoney("bank", amount, "Impound fee")
        return true, "bank"
    end

    return false
end

---@param xPlayer table
---@param amount integer
---@param account string?
local function refundCharge(xPlayer, amount, account)
    if amount <= 0 or not account then
        return
    end

    local ok, err = pcall(function()
        if account == "money" and type(xPlayer.addMoney) == "function" then
            xPlayer.addMoney(amount, "Impound fee refund")
        elseif account == "bank" and type(xPlayer.addAccountMoney) == "function" then
            xPlayer.addAccountMoney("bank", amount, "Impound fee refund")
        end
    end)

    if not ok then
        print(("[esx_garage] failed to refund impound fee for %s: %s"):format(xPlayer.identifier or "unknown", tostring(err)))
    end
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

---@param result any
---@return integer
local function affectedRows(result)
    if type(result) == "number" then
        return result
    end

    if type(result) == "table" then
        return tonumber(result.affectedRows) or 0
    end

    return 0
end

---@param assignments string[]
---@param params table
---@param column string
---@param value any
local function appendNullableAssignment(assignments, params, column, value)
    if value == nil then
        assignments[#assignments + 1] = ("`%s` = NULL"):format(column)
        return
    end

    assignments[#assignments + 1] = ("`%s` = ?"):format(column)
    params[#params + 1] = value
end

---@param conditions string[]
---@param params table
---@param column string
---@param value any
local function appendNullableCondition(conditions, params, column, value)
    if value == nil then
        conditions[#conditions + 1] = ("`%s` IS NULL"):format(column)
        return
    end

    conditions[#conditions + 1] = ("`%s` = ?"):format(column)
    params[#params + 1] = value
end

---@param a any
---@param b any
---@return boolean
local function sameOptionalLocation(a, b)
    return activePound(a) == activePound(b)
end

---@param identifier string
---@param row OwnedVehicleRow
---@param stored integer
---@return string, table
local function retrieveStateCondition(identifier, row, stored)
    local conditions = { "`owner` = ?", "`plate` = ?", "`stored` = ?" }
    local params = { identifier, row.plate, stored }

    appendNullableCondition(conditions, params, "parking", row.parking)
    appendNullableCondition(conditions, params, "pound", row.pound)

    return table.concat(conditions, " AND "), params
end

---@param identifier string
---@param row OwnedVehicleRow
local function restoreRetrieveState(identifier, row)
    local assignments = { "`stored` = ?" }
    local params = { storedValue(row.stored) }

    appendNullableAssignment(assignments, params, "parking", row.parking)
    appendNullableAssignment(assignments, params, "pound", row.pound)
    appendNullableAssignment(assignments, params, "last_used", row.last_used)

    params[#params + 1] = identifier
    params[#params + 1] = row.plate

    local ok, err = pcall(MySQL.update.await,
        ("UPDATE `owned_vehicles` SET %s WHERE `owner` = ? AND `plate` = ?"):format(table.concat(assignments, ", ")),
        params)

    if not ok then
        print(("[esx_garage] failed to rollback retrieve state for %s: %s"):format(row.plate, tostring(err)))
    end
end

---@param xVehicle table
local function deleteRetrievedVehicle(xVehicle)
    local ok, err = pcall(function()
        xVehicle:delete()
    end)

    if not ok then
        print(("[esx_garage] failed to delete retrieved vehicle after failed retrieve: %s"):format(tostring(err)))
    end
end

---@param identifier string
---@param row OwnedVehicleRow
---@return boolean, string?
local function prepareRetrieveSpawn(identifier, row)
    local condition, params = retrieveStateCondition(identifier, row, storedValue(row.stored))
    local ok, result = pcall(MySQL.update.await,
        ("UPDATE `owned_vehicles` SET `stored` = 1 WHERE %s"):format(condition),
        params)

    if not ok then
        return false, "error"
    end

    if affectedRows(result) < 1 then
        return false, "busy"
    end

    return true
end

---@param identifier string
---@param current OwnedVehicleRow
---@param lastUsed integer
---@return boolean, string?
local function finalizeCurrentRetrieveState(identifier, current, lastUsed)
    local condition, params = retrieveStateCondition(identifier, current, storedValue(current.stored))
    local queryParams = { lastUsed }
    appendParams(queryParams, params)

    local ok, result = pcall(MySQL.update.await,
        ("UPDATE `owned_vehicles` SET `stored` = 0, `pound` = NULL, `parking` = NULL, `last_used` = ? WHERE %s"):format(condition),
        queryParams)

    if not ok then
        return false, "error"
    end

    if affectedRows(result) > 0 then
        return true
    end

    local refreshed = ownedRow(identifier, current.plate)
    if refreshed and storedValue(refreshed.stored) == 0 and not activePound(refreshed.pound) then
        return true
    end

    return false, "state_changed"
end

---@param identifier string
---@param row OwnedVehicleRow
---@return boolean, string?
local function commitRetrieveState(identifier, row)
    local lastUsed = os.time()
    local condition, params = retrieveStateCondition(identifier, row, 1)
    local queryParams = { lastUsed }
    appendParams(queryParams, params)

    local ok, result = pcall(MySQL.update.await,
        ("UPDATE `owned_vehicles` SET `stored` = 0, `pound` = NULL, `parking` = NULL, `last_used` = ? WHERE %s"):format(condition),
        queryParams)

    if not ok then
        return false, "error"
    end

    if affectedRows(result) < 1 then
        local current = ownedRow(identifier, row.plate)
        if current then
            local currentStored = storedValue(current.stored)
            local canFinalize = false

            if currentStored == 0 then
                canFinalize = activePound(current.pound) == nil or sameOptionalLocation(current.pound, row.pound)
            elseif currentStored == 1 then
                canFinalize = sameOptionalLocation(current.parking, row.parking)
                    and sameOptionalLocation(current.pound, row.pound)
            end

            if canFinalize then
                return finalizeCurrentRetrieveState(identifier, current, lastUsed)
            end
        end

        return false, "state_changed"
    end

    return true
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
---@param anchor table?
---@return boolean
local function isNearPoint(source, anchor)
    local ped = GetPlayerPed(source)
    if not ped or ped <= 0 then
        return false
    end

    if not anchor then
        return true
    end

    local tolerance = (Config.Settings.interactionDistance or 3.0) + 10.0

    return #(GetEntityCoords(ped) - vec3(anchor.x, anchor.y, anchor.z)) <= tolerance
end

---@param source integer
---@param location table
---@return boolean
local function isNearLocation(source, location)
    return isNearPoint(source, location.entryPoint or location.getOutPoint)
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
---@param expectedModel number?
---@param managedEntity integer?
---@return boolean
local function hasUnmanagedWorldVehicle(plateKey, expectedModel, managedEntity)
    if not expectedModel then
        return false
    end

    local vehicles = GetAllVehicles()

    for i = 1, #vehicles do
        local veh = vehicles[i]
        if veh ~= managedEntity
            and GetEntityModel(veh) == expectedModel
            and normPlate(GetVehicleNumberPlateText(veh) or "") == plateKey then
            return true
        end
    end

    return false
end

---@type table<string, integer>
local retrieving = {}
local vehicleOperationToken = 0

---@param key string
---@return integer?
local function beginVehicleOperation(key)
    if retrieving[key] then
        return nil
    end

    vehicleOperationToken = vehicleOperationToken + 1
    retrieving[key] = vehicleOperationToken

    return vehicleOperationToken
end

---@param key string
---@param token integer?
local function endVehicleOperation(key, token)
    if token and retrieving[key] == token then
        retrieving[key] = nil
    end
end

---@param requested any
---@return integer
local function vehiclePageSize(requested)
    local configured = tonumber(Config.Settings.vehiclesPerPage)
    if not isFiniteNumber(configured) then
        configured = DEFAULT_PAGE_SIZE
    end
    configured = math.floor(configured)

    local maxConfigured = tonumber(Config.Settings.maxVehiclesPerMenu)
    if not isFiniteNumber(maxConfigured) then
        maxConfigured = MAX_ALLOWED_PAGE_SIZE
    end
    maxConfigured = math.floor(maxConfigured)

    local maxPageSize = math.min(math.max(maxConfigured, 1), MAX_ALLOWED_PAGE_SIZE)
    local size = tonumber(requested)
    if not isFiniteNumber(size) then
        size = configured
    end
    size = math.floor(size)

    if size < 1 then
        return DEFAULT_PAGE_SIZE
    end

    return math.min(size, maxPageSize)
end

---@param garageId string?
---@return string, table
local function garageScopeCondition(garageId)
    if not Config.Settings.restrictToGarage or not garageId then
        return "", {}
    end

    local params = { garageId }
    local garageIds = {}

    for id in pairs(Garages) do
        garageIds[#garageIds + 1] = id
    end

    local invalidParkingCondition = ""
    if #garageIds > 0 then
        local placeholders = {}

        for i = 1, #garageIds do
            placeholders[i] = "?"
            params[#params + 1] = garageIds[i]
        end

        invalidParkingCondition = (" OR `parking` NOT IN (%s)"):format(table.concat(placeholders, ", "))
    end

    return (" AND (`stored` <> 1 OR `pound` IS NOT NULL OR `parking` IS NULL OR `parking` = ?%s)")
        :format(invalidParkingCondition), params
end

---@param values table
---@return table
local function copyParams(values)
    local out = {}
    appendParams(out, values)
    return out
end

---@param scopeSql string
---@param params table
---@param search string
---@return string
local function appendSearchCondition(scopeSql, params, search)
    if search == "" then
        return scopeSql
    end

    local like = ("%s%%"):format(escapeLike(search))
    params[#params + 1] = like
    params[#params + 1] = like

    return scopeSql .. " AND (`plate` LIKE ? ESCAPE '\\\\' OR `custom_name` LIKE ? ESCAPE '\\\\')"
end

xLib.callback.registerCompat("esx_garage:getVehicles", function(source, cb, data)
    if rejectRateLimited(source, cb, "esx_garage:getVehicles") then
        return
    end

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

    local request = type(data) == "table" and data or { garageId = data }
    local garageId = request.garageId

    local garage = garageId and Garages[garageId]
    local impound = garageId and Impounds[garageId]
    local location = garage or impound
    if not location then
        return cb({ success = false, error = "no_location" })
    end

    if garage and not CanAccessGarage(source, garage) then
        return cb(false)
    end

    local page = vehiclePage(request.page)
    local pageSize = vehiclePageSize(request.pageSize)
    local offset = (page - 1) * pageSize
    local scopeSql, scopeParams = garageScopeCondition(garageId)
    local baseParams = { xPlayer.identifier }

    for i = 1, #scopeParams do
        baseParams[#baseParams + 1] = scopeParams[i]
    end

    if impound then
        scopeSql = scopeSql .. " AND `pound` = ?"
        baseParams[#baseParams + 1] = garageId
    end

    local filter = type(request.filter) == "table" and request.filter or {}
    local search = vehicleSearch(filter.search)
    scopeSql = appendSearchCondition(scopeSql, baseParams, search)

    local pageSql = scopeSql
    local params = copyParams(baseParams)

    if filter.stored == true then
        pageSql = pageSql .. " AND `stored` = 1 AND `pound` IS NULL"
    elseif filter.stored == false then
        pageSql = pageSql .. " AND `stored` <> 1 AND `pound` IS NULL"
    end

    if filter.impounded == true then
        pageSql = pageSql .. " AND `pound` IS NOT NULL"
    elseif filter.impounded == false then
        pageSql = pageSql .. " AND `pound` IS NULL"
    end

    if filter.favorite == true then
        pageSql = pageSql .. " AND `is_favorite` = 1"
    elseif filter.favorite == false then
        pageSql = pageSql .. " AND `is_favorite` = 0"
    end

    local orderSql = "`plate` ASC"
    if impound or filter.impounded == true then
        orderSql = "`pound` ASC, `plate` ASC"
    end

    params[#params + 1] = pageSize + 1
    params[#params + 1] = offset

    local rows = MySQL.query.await(
        ("SELECT %s FROM `owned_vehicles` WHERE `owner` = ?%s ORDER BY %s LIMIT ? OFFSET ?")
            :format(VEHICLE_SELECT_COLUMNS, pageSql, orderSql),
        params) or {}

    local hasNext = #rows > pageSize
    if hasNext then
        rows[#rows] = nil
    end

    applyCachedHudMileage(rows)

    cb({
        vehicles = rows,
        page = page,
        pageSize = pageSize,
        hasNext = hasNext,
    })
end)

xLib.callback.registerCompat("esx_garage:retrieveVehicle", function(source, cb, data)
    if rejectRateLimited(source, cb, "esx_garage:retrieveVehicle") then
        return
    end

    if not GarageReady then
        return cb({ success = false, error = "error" })
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return cb({ success = false, error = "player" })
    end

    local plate = data and data.plate
    local spawn = data and data.spawn
    if not validPlate(plate) or type(spawn) ~= "table"
        or type(spawn.x) ~= "number" or type(spawn.y) ~= "number" or type(spawn.z) ~= "number"
        or (spawn.w ~= nil and type(spawn.w) ~= "number") or (spawn.h ~= nil and type(spawn.h) ~= "number") then
        return cb({ success = false, error = "invalid" })
    end

    local key = normPlate(plate)
    local operationToken = beginVehicleOperation(key)
    if not operationToken then
        return cb({ success = false, error = "busy" })
    end

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

        local expectedModel = storedVehicleModel(row)
        local hasWorldVehicle = managedEntity ~= nil or hasUnmanagedWorldVehicle(key, expectedModel, managedEntity)

        local fee = 0
        local rowPound = activePound(row.pound)

        if rowPound then
            if not impound then
                return { success = false, error = "use_impound" }
            end
            if rowPound ~= data.garageId then
                return { success = false, error = "wrong_impound" }
            end
            if hasWorldVehicle then
                return { success = false, error = "not_stored" }
            end

            local lot = Impounds[rowPound]
            fee = (lot and lot.cost) or Config.Settings.defaultImpoundFee
        elseif not isStored(row.stored) then
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

        if isSpawnBlocked(spawn) then
            return { success = false, error = "blocked" }
        end

        local transitionApplied = false

        if existing then
            existing:delete()
        elseif not isStored(row.stored) then
            local prepared, prepareError = prepareRetrieveSpawn(xPlayer.identifier, row)
            if not prepared then
                return { success = false, error = prepareError or "error" }
            end
            transitionApplied = true
        end

        local coords = vec4(spawn.x, spawn.y, spawn.z, spawn.w or spawn.h or 0.0)
        local spawned, xVehicle = pcall(ESX.CreateExtendedVehicle, xPlayer.identifier, row.plate, coords)
        if not spawned or not xVehicle then
            restoreRetrieveState(xPlayer.identifier, row)
            return { success = false, error = "spawn_failed" }
        end

        local chargedOk, charged, chargeAccount = pcall(charge, xPlayer, fee)
        if not chargedOk or not charged then
            deleteRetrievedVehicle(xVehicle)
            if transitionApplied then
                restoreRetrieveState(xPlayer.identifier, row)
            end
            return { success = false, error = chargedOk and "no_money" or "error" }
        end

        local committed, commitError = commitRetrieveState(xPlayer.identifier, row)
        if not committed then
            deleteRetrievedVehicle(xVehicle)
            refundCharge(xPlayer, fee, chargeAccount)
            restoreRetrieveState(xPlayer.identifier, row)
            return { success = false, error = commitError or "error" }
        end

        return { success = true, data = { netId = xVehicle:getNetId() } }
    end)

    endVehicleOperation(key, operationToken)

    if not ok then
        return cb({ success = false, error = "error" })
    end

    cb(result)
end)

xLib.callback.registerCompat("esx_garage:storeVehicle", function(source, cb, data)
    if rejectRateLimited(source, cb, "esx_garage:storeVehicle") then
        return
    end

    if not GarageReady then
        return cb({ success = false, error = "error" })
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return cb({ success = false, error = "player" })
    end

    local plate = data and data.plate
    local props = data and data.props
    if not validPlate(plate) or type(props) ~= "table" then
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

    if not isNearPoint(source, garage.storePoint or garage.entryPoint) then
        return cb({ success = false, error = "too_far" })
    end

    local key = normPlate(plate)
    local operationToken = beginVehicleOperation(key)
    if not operationToken then
        return cb({ success = false, error = "busy" })
    end

    local ok, result = pcall(function()
        local row = ownedRow(xPlayer.identifier, plate)
        if not row then
            return { success = false, error = "not_owned" }
        end

        if isStored(row.stored) then
            return { success = false, error = "already_stored" }
        end

        props.plate = row.plate

        local ped = GetPlayerPed(source)
        local pedCoords = (ped and ped > 0) and GetEntityCoords(ped)
        local pedVehicle = (ped and ped > 0) and GetVehiclePedIsIn(ped, false) or 0

        local xVehicle = ESX.GetExtendedVehicleFromPlate(row.plate)
        if xVehicle then
            local managedOwner = extendedVehicleOwner(xVehicle)
            if managedOwner and managedOwner ~= xPlayer.identifier then
                return { success = false, error = "plate_conflict" }
            end

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

        MySQL.update.await("UPDATE `owned_vehicles` SET `last_used` = ? WHERE `owner` = ? AND `plate` = ?",
            { os.time(), xPlayer.identifier, row.plate })

        return { success = true, data = true }
    end)

    endVehicleOperation(key, operationToken)

    if not ok then
        return cb({ success = false, error = "error" })
    end

    cb(result)
end)

xLib.callback.registerCompat("esx_garage:toggleFavorite", function(source, cb, data)
    if rejectRateLimited(source, cb, "esx_garage:toggleFavorite") then
        return
    end

    if not GarageReady then
        return cb({ success = false, error = "error" })
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return cb({ success = false })
    end

    local plate = data and data.plate
    if not validPlate(plate) or type(data.isFavorite) ~= "boolean" then
        return cb({ success = false, error = "invalid" })
    end

    local ok, updated = pcall(function()
        local dbPlate = ownedPlate(xPlayer.identifier, plate)
        if not dbPlate then
            return false
        end

        MySQL.update.await(
            "UPDATE `owned_vehicles` SET `is_favorite` = ? WHERE `owner` = ? AND `plate` = ?",
            { data.isFavorite and 1 or 0, xPlayer.identifier, dbPlate })

        return true
    end)

    if not ok then
        return cb({ success = false, error = "error" })
    end

    if not updated then
        return cb({ success = false, error = "not_owned" })
    end

    cb({ success = true, data = data.isFavorite })
end)

xLib.callback.registerCompat("esx_garage:renameVehicle", function(source, cb, data)
    if rejectRateLimited(source, cb, "esx_garage:renameVehicle") then
        return
    end

    if not GarageReady then
        return cb({ success = false, error = "error" })
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return cb({ success = false })
    end

    local plate = data and data.plate
    local name = data and data.name
    if not validPlate(plate) or type(name) ~= "string" or #name < 1 or #name > 50 then
        return cb({ success = false, error = "invalid" })
    end

    local ok, updated = pcall(function()
        local dbPlate = ownedPlate(xPlayer.identifier, plate)
        if not dbPlate then
            return false
        end

        MySQL.update.await(
            "UPDATE `owned_vehicles` SET `custom_name` = ? WHERE `owner` = ? AND `plate` = ?",
            { name, xPlayer.identifier, dbPlate })

        return true
    end)

    if not ok then
        return cb({ success = false, error = "error" })
    end

    if not updated then
        return cb({ success = false, error = "not_owned" })
    end

    cb({ success = true, data = name })
end)

xLib.callback.registerCompat("esx_garage:transferVehicle", function(source, cb, data)
    if rejectRateLimited(source, cb, "esx_garage:transferVehicle") then
        return
    end

    if not GarageReady then
        return cb({ success = false, error = "error" })
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return cb({ success = false })
    end

    local plate = data and data.plate
    local targetId = tonumber(data and data.targetId)
    if not validPlate(plate) or not targetId then
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
    local operationToken = beginVehicleOperation(key)
    if not operationToken then
        return cb({ success = false, error = "busy" })
    end

    local ok, result = pcall(function()
        local row = ownedRow(xPlayer.identifier, plate)
        if not row then
            return { success = false, error = "not_owned" }
        end

        if not isStored(row.stored) then
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

    endVehicleOperation(key, operationToken)

    if not ok then
        return cb({ success = false, error = "error" })
    end

    cb(result)
end)

xLib.callback.registerCompat("esx_garage:giveKeys", function(source, cb, data)
    if rejectRateLimited(source, cb, "esx_garage:giveKeys") then
        return
    end

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
    if not validPlate(plate) then
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

---@return string?
local function defaultImpoundLot()
    local fallback = Config.Impounds and Config.Impounds[1]
    return fallback and fallback.id or nil
end

---@param plate string
---@param lot string? defaults to the first configured impound
---@return boolean
local function impoundVehicle(plate, lot)
    if not validPlate(plate) then
        return false
    end

    local lotId = (type(lot) == "string" and Impounds[lot]) and lot or nil

    if not lotId then
        if lot ~= nil then
            print(("[esx_garage] impoundVehicle: unknown impound \"%s\", falling back to the default lot"):format(tostring(lot)))
        end

        lotId = defaultImpoundLot()
    end

    if not lotId then
        print("[esx_garage] impoundVehicle: no impound configured, aborting")
        return false
    end

    local xVehicle = ESX.GetExtendedVehicleFromPlate(plate)

    if xVehicle then
        xVehicle:delete(lotId, true)
    else
        local condition, plateParams = plateCondition(plate)
        local params = { lotId }
        appendParams(params, plateParams)

        MySQL.update.await(
            ("UPDATE `owned_vehicles` SET `stored` = 1, `pound` = ?, `parking` = NULL WHERE %s"):format(condition),
            params)
    end

    local condition, plateParams = plateCondition(plate)
    local params = {}
    appendParams(params, plateParams)
    params[#params + 1] = lotId

    local settled = MySQL.scalar.await(
        ("SELECT COUNT(*) FROM `owned_vehicles` WHERE %s AND `stored` = 1 AND `pound` = ?"):format(condition),
        params) or 0

    if settled < 1 then
        return false
    end

    return true
end

local deletedVehicleImpounds = {}

local function queueDeletedVehicleImpound(plate, model)
    if not validPlate(plate) then
        return
    end

    local key = normPlate(plate)
    if deletedVehicleImpounds[key] then
        return
    end

    deletedVehicleImpounds[key] = true

    SetTimeout(1500, function()
        deletedVehicleImpounds[key] = nil

        local lotId = defaultImpoundLot()
        if not lotId then
            return
        end

        local condition, plateParams = plateCondition(plate)
        local ok, row = pcall(MySQL.single.await,
            ("SELECT `stored`, `pound`, `vehicle` FROM `owned_vehicles` WHERE %s AND `stored` = 0 AND `pound` IS NULL LIMIT 1")
            :format(condition),
            plateParams)

        if not ok or not row then
            return
        end

        local storedModel = storedVehicleModel(row)
        if type(model) == "number" and model ~= 0 and storedModel and storedModel ~= model then
            return
        end

        local impounded, err = pcall(impoundVehicle, plate, lotId)
        if not impounded then
            print(("[esx_garage] failed to impound deleted vehicle %s: %s"):format(key, tostring(err)))
        end
    end)
end

AddEventHandler("entityRemoved", function(entity)
    local typeOk, entityType = pcall(GetEntityType, entity)
    if not typeOk or entityType ~= 2 then
        return
    end

    local plateOk, plate = pcall(GetVehicleNumberPlateText, entity)
    if not plateOk then
        return
    end

    local modelOk, model = pcall(GetEntityModel, entity)
    queueDeletedVehicleImpound(plate, modelOk and model or nil)
end)

local function impoundOutVehiclesOnStop()
    local lotId = defaultImpoundLot()
    if not lotId then
        print("[esx_garage] impoundOutVehiclesOnStop: no impound configured, aborting")
        return
    end

    local liveImpounded, seen = 0, {}
    local vehicles = GetAllVehicles()

    for i = 1, #vehicles do
        local plate = GetVehicleNumberPlateText(vehicles[i])
        if type(plate) == "string" then
            local key = normPlate(plate)
            if key ~= "" and not seen[key] then
                seen[key] = true

                local xVehicle = ESX.GetExtendedVehicleFromPlate(plate) or ESX.GetExtendedVehicleFromPlate(key)
                if xVehicle then
                    local deleted, deleteErr = pcall(function()
                        xVehicle:delete(lotId, true)
                    end)

                    if deleted then
                        liveImpounded = liveImpounded + 1
                    else
                        print(("[esx_garage] impoundOutVehiclesOnStop: failed to impound live vehicle %s: %s")
                            :format(key, tostring(deleteErr)))
                    end
                end
            end
        end
    end

    local ok, affected = pcall(MySQL.update.await,
        "UPDATE `owned_vehicles` SET `stored` = 1, `pound` = ?, `parking` = NULL WHERE `stored` = 0",
        { lotId })

    if not ok then
        print(("[esx_garage] impoundOutVehiclesOnStop: failed to impound out vehicles: %s"):format(tostring(affected)))
        return
    end

    if liveImpounded > 0 or (affected or 0) > 0 then
        print(("[esx_garage] impoundOutVehiclesOnStop: impounded %d live vehicle(s) and %d database row(s) at %s")
            :format(liveImpounded, affected or 0, lotId))
    end
end

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        impoundOutVehiclesOnStop()
    end
end)

exports("impoundVehicle", impoundVehicle)
