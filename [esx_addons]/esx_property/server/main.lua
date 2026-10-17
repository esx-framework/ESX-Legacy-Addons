-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--[[
      ESX Property - Properties Made Right!
    Copyright (C) 2025 ESX-Framework

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]
local function Log(title, color, fields, Level)
    if Level <= Config.Logs.LogLevel then
        local webHook = Config.Logs.Webhook
        local embedData = {
            {
                ['title'] = title,
                ['color'] = color,
                ['footer'] = {
                    ['text'] = 'ESX-Property | ' .. os.date(),
                    ['icon_url'] = 'https://cdn.discordapp.com/attachments/944789399852417096/1004915039414788116/imageedit_1_2564956129.png',
                },
                ['fields'] = fields,
                ['description'] = '',
                ['author'] = {
                    ['name'] = 'ESX-Framework | Log Level ' .. Level,
                    ['icon_url'] = 'https://cdn.discordapp.com/emojis/939245183621558362.webp?size=128&quality=lossless',
                },
            },
        }

        PerformHttpRequest(
            webHook,
            function(err, text, headers) end,
            'POST',
            json.encode({ username = 'ESX-Framework', embeds = embedData }),
            { ['Content-Type'] = 'application/json' }
        )
    end
end

local PM = Config.PlayerManagement
local Properties = {}
local propertySchemaReady = false
local propertyMigrationPending = true
local PropertyLocks = {}
local PendingPropertySales = {}
local pendingVehicleStores = {}
local storedVehiclePlateOwners = {}
local indexedVehiclePlates = {}
local updateVehiclePlateIndex

local PropertyActionDistance = 6.0
local PropertySaleOfferDuration = 30000
local PropertyRaidCooldown = 30000
local propertyRaidLimiter = xLib.rateLimiter({
    capacity = 1,
    refill = 1,
    interval = PropertyRaidCooldown,
    staleMs = math.max(60000, PropertyRaidCooldown * 4),
})

local saveInProgress = false
local refreshInProgress = false
local refreshPending = false
local saveRequested = false
local saveRetryScheduled = false
local lastSaveSucceeded = true
local propertyStopping = false
local dirtyProperties = {}
local fullSaveRequested = false
local propertyActionLimiter = xLib.rateLimiter({ capacity = 20, refill = 10, interval = 1000 })

local function SavePropertiesToSQL(Reason, changesOnly)
    if not propertySchemaReady then
        return false
    end

    saveRequested = true
    if not changesOnly then fullSaveRequested = true end
    while refreshInProgress do
        Wait(0)
    end

    if not propertySchemaReady then
        return false
    end

    if saveInProgress then
        while saveInProgress do
            Wait(0)
        end

        return lastSaveSucceeded
    end

    saveInProgress = true
    repeat
        saveRequested = false
        local snapshot, full = dirtyProperties, fullSaveRequested
        dirtyProperties, fullSaveRequested = {}, false
        local ok, saved, err = pcall(PropertyStorage.save, Properties, not full and snapshot or nil)
        lastSaveSucceeded = ok and saved == true
        if not lastSaveSucceeded then
            saveRequested = true
            fullSaveRequested = fullSaveRequested or full
            for id in pairs(snapshot) do dirtyProperties[id] = true end
            print(('[esx_property] SQL save failed; changes remain pending: %s'):format(tostring(ok and err or saved)))
            break
        end
    until not saveRequested

    saveInProgress = false

    if not lastSaveSucceeded then
        if not saveRetryScheduled and not propertyStopping then
            saveRetryScheduled = true
            SetTimeout(5000, function()
                saveRetryScheduled = false
                if not propertyStopping then
                    SavePropertiesToSQL('Retry pending SQL save', true)
                end
            end)
        end

        return false
    end

    Log('Properties Saving', 11141375, {
        { name = '**Reason**', value = Reason or 'Immediate SQL save', inline = true },
        { name = '**Property Count**', value = tostring(#Properties), inline = true },
    }, 1)

    return true
end

local function PropertyForPlayer(property, xPlayer)
    local copy = {}

    for key, value in pairs(property) do
        if key ~= 'Keys' and key ~= 'Owner' and key ~= 'plysinside' and key ~= 'furniture' and key ~= 'garage' then
            copy[key] = value
        end
    end

    local access = property.Owner == xPlayer.identifier or (property.Keys and property.Keys[xPlayer.identifier])
    local inside = false

    for _, playerId in ipairs(property.plysinside or {}) do
        if playerId == xPlayer.source then
            inside = true
            break
        end
    end

    copy.Owner = property.Owner == xPlayer.identifier and xPlayer.identifier or ''
    copy.Keys = access and { [xPlayer.identifier] = true } or {}
    copy.furniture = (access or inside) and property.furniture or {}
    copy.garage = {}

    for key, value in pairs(property.garage or {}) do
        if key ~= 'StoredVehicles' then
            copy.garage[key] = value
        end
    end

    return copy
end

local function PropertiesForPlayer(xPlayer)
    local result = {}

    for id, property in pairs(Properties) do
        result[id] = PropertyForPlayer(property, xPlayer)
    end

    return result
end

local saveScheduled = false

local function SchedulePropertiesSave(reason, propertyId)
    saveRequested = true
    if propertyId then dirtyProperties[propertyId] = true else fullSaveRequested = true end
    if saveInProgress then
        return
    end

    if saveScheduled then
        return
    end

    saveScheduled = true

    SetTimeout(1000, function()
        saveScheduled = false
        SavePropertiesToSQL(reason, true)
    end)
end

local function SyncPropertiesAndSave(Reason, propertyId)
    updateVehiclePlateIndex(propertyId and Properties[propertyId] or nil)
    for _, xPlayer in pairs(ESX.GetExtendedPlayers()) do
        if propertyId then
            TriggerClientEvent('esx_property:syncProperty', xPlayer.source, propertyId, PropertyForPlayer(Properties[propertyId], xPlayer))
        else
            TriggerClientEvent('esx_property:syncProperties', xPlayer.source, PropertiesForPlayer(xPlayer))
        end
    end

    SchedulePropertiesSave(Reason, propertyId)
end

local function SyncFurniture(propertyId)
    local property = Properties[propertyId]

    for _, xPlayer in pairs(ESX.GetExtendedPlayers()) do
        local access = property.Owner == xPlayer.identifier or (property.Keys and property.Keys[xPlayer.identifier])
        local inside = false

        for _, playerId in ipairs(property.plysinside or {}) do
            if playerId == xPlayer.source then
                inside = true
                break
            end
        end

        if access or inside then
            TriggerClientEvent('esx_property:syncFurniture', xPlayer.source, propertyId, property.furniture)
        end
    end
end

local function getBankMoney(xPlayer)
    local account = xPlayer and xPlayer.getAccount and xPlayer.getAccount('bank')

    return account and tonumber(account.money) or 0
end

local function clearPendingSaleForProperty(PropertyId)
    for token, offer in pairs(PendingPropertySales) do
        if offer.propertyId == PropertyId then
            PendingPropertySales[token] = nil

            if PropertyLocks[PropertyId] == token then
                PropertyLocks[PropertyId] = nil
            end
        end
    end
end

local function normalizePropertyId(propertyId)
    local id = tonumber(propertyId)

    if not id or id < 1 or id ~= math.floor(id) or not Properties[id] then
        return nil
    end

    return id
end

local function normalizePlate(plate)
    return xLib.vehiclePlate.normalize(plate, {
        maxLength = 12,
        uppercase = false,
    })
end

updateVehiclePlateIndex = function(property)
    if not property then
        storedVehiclePlateOwners, indexedVehiclePlates = {}, {}
        for _, item in pairs(Properties) do updateVehiclePlateIndex(item) end
        return
    end

    for plate in pairs(indexedVehiclePlates[property] or {}) do
        if storedVehiclePlateOwners[plate] == property then storedVehiclePlateOwners[plate] = nil end
    end

    local plates = {}

    for _, item in pairs(property.garage and property.garage.StoredVehicles or {}) do
        local plate = item.vehicle and normalizePlate(item.vehicle.plate)
        if plate then plates[plate], storedVehiclePlateOwners[plate] = true, property end
    end

    indexedVehiclePlates[property] = plates
end

local function isNearCoords(source, coords, maxDistance)
    local nearby = xLib.player.isNearCoords(source, coords, maxDistance)

    return nearby
end

local function hasPropertyAccess(xPlayer, Property)
    return xPlayer and Property and (Property.Owner == xPlayer.identifier or (Property.Keys and Property.Keys[xPlayer.identifier]))
end

local function canEnterProperty(xPlayer, Property)
    if not xPlayer or not Property then
        return false
    end

    if not Property.Owned then
        return not Property.Locked
    end

    if Property.Locked then
        return Config.OwnerCanAlwaysEnter and Property.Owner == xPlayer.identifier
    end

    return true
end

local function isRestoringLastProperty(xPlayer, PropertyId)
    local lastProperty = xPlayer and xPlayer.get and xPlayer.get('lastProperty')

    return lastProperty and tonumber(lastProperty.id) == PropertyId
end

local function isPlayerInsideProperty(player, Property)
    if not Property or not Property.plysinside then
        return false
    end

    for i = 1, #Property.plysinside do
        if Property.plysinside[i] == player then
            return true
        end
    end

    return false
end

local propertyCallbacksWithId = {
    ['esx_property:buyProperty'] = true,
    ['esx_property:attemptSellToPlayer'] = true,
    ['esx_property:buyFurniture'] = true,
    ['esx_property:sellProperty'] = true,
    ['esx_property:toggleLock'] = true,
    ['esx_property:toggleGarage'] = true,
    ['esx_property:toggleCCTV'] = true,
    ['esx_property:SetGaragePos'] = true,
    ['esx_property:SetCCTVangle'] = true,
    ['esx_property:CCTV'] = true,
    ['esx_property:ExitCCTV'] = true,
    ['esx_property:SetPropertyName'] = true,
    ['esx_property:KnockOnDoor'] = true,
    ['esx_property:RemoveCustomName'] = true,
    ['esx_property:deleteProperty'] = true,
    ['esx_property:ChangePrice'] = true,
    ['esx_property:ChangeInterior'] = true,
    ['esx_property:RemoveAllfurniture'] = true,
    ['esx_property:deleteFurniture'] = true,
    ['esx_property:editFurniture'] = true,
    ['esx_property:evictOwner'] = true,
    ['esx_property:CanRaid'] = true,
    ['esx_property:ChangeEntrance'] = true,
    ['esx_property:SetInventoryPosition'] = true,
    ['esx_property:SetWardrobePosition'] = true,
    ['esx_property:GetInsidePlayers'] = true,
    ['esx_property:GetNearbyPlayers'] = true,
    ['esx_property:GetPlayersWithKeys'] = true,
    ['esx_property:ShouldHaveKey'] = true,
    ['esx_property:GetWebhook'] = true,
    ['esx_property:GiveKey'] = true,
    ['esx_property:StoreVehicle'] = true,
    ['esx_property:AccessGarage'] = true,
    ['esx_property:RemoveKey'] = true,
    ['esx_property:CanOpenFurniture'] = true,
}

local tableResponses = {
    ['esx_property:GetInsidePlayers'] = true,
    ['esx_property:GetNearbyPlayers'] = true,
    ['esx_property:GetPlayersWithKeys'] = true,
    ['esx_property:getPlayerDressing'] = true,
}

local function finite(value, limit)
    return type(value) == 'number' and value == value and math.abs(value) <= limit
end

local function validCoords(value)
    return (type(value) == 'table' or type(value) == 'vector3') and finite(value.x, 20000) and finite(value.y, 20000) and finite(value.z, 10000)
end

local function copyVehiclePayload(value)
    local seen, entries, bytes = {}, 0, 0

    local function visit(item, depth)
        entries = entries + 1

        if entries > 2048 or depth > 8 then return false end

        local kind = type(item)

        if kind == 'table' then
            if seen[item] then return false end
            seen[item] = true

            for key, child in pairs(item) do
                if (type(key) ~= 'string' and type(key) ~= 'number')
                    or not visit(key, depth + 1) or not visit(child, depth + 1) then return false end
            end

            seen[item] = nil
        elseif kind == 'string' then
            bytes = bytes + #item + 5
        elseif kind == 'number' then
            if not finite(item, 9007199254740991) then return false end

            bytes = bytes + 24
        elseif kind == 'boolean' then
            bytes = bytes + 5
        else
            return false
        end

        return bytes <= 32768
    end

    if not visit(value, 0) then return nil end

    local ok, encoded = pcall(json.encode, value)
    if not ok or #encoded > 32768 then return nil end

    local decodedOk, decoded = pcall(json.decode, encoded)

    return decodedOk and decoded or nil
end

local function registerPropertyCallback(name, handler)
    xLib.callback.registerCompat(name, function(playerId, cb, ...)
        local args = table.pack(...)

        local function reject()
            return cb(tableResponses[name] and {} or false)
        end

        if not propertySchemaReady or not lastSaveSucceeded or not ESX.GetPlayerFromId(playerId) or not propertyActionLimiter:consume(playerId) then
            return reject()
        end

        if propertyCallbacksWithId[name] then
            local id = normalizePropertyId(args[1])

            if not id then
                return reject()
            end

            args[1] = id

            local property = Properties[id]

            property.Keys = property.Keys or {}

            if
                name == 'esx_property:SetPropertyName'
                and (type(args[2]) ~= 'string' or #args[2] == 0 or #args[2] > Config.MaxNameLength or args[2]:find('[%c]'))
            then
                return reject()
            end

            if name == 'esx_property:SetGaragePos' and not finite(args[2], 360) then
                return reject()
            end

            if name == 'esx_property:buyFurniture' and (not validCoords(args[5]) or not finite(args[6], 360)) then
                return reject()
            end
            if name == 'esx_property:editFurniture' and (not validCoords(args[3]) or not finite(args[4], 360)) then
                return reject()
            end
            if name == 'esx_property:buyFurniture' then
                args[5] = { x = args[5].x, y = args[5].y, z = args[5].z }
            elseif name == 'esx_property:editFurniture' then
                args[3] = { x = args[3].x, y = args[3].y, z = args[3].z }
            end

            if name == 'esx_property:SetCCTVangle' then
                local angles = args[2]

                if type(angles) ~= 'table' or not validCoords(angles.rot) or not finite(angles.maxleft, 360) or not finite(angles.maxright, 360) then
                    return reject()
                end
                args[2] = { rot = { x = angles.rot.x, y = angles.rot.y, z = angles.rot.z }, maxleft = angles.maxleft, maxright = angles.maxright }
            end

            if name == 'esx_property:ChangePrice' and (not finite(args[2], 2147483647) or args[2] < 0 or args[2] % 1 ~= 0) then
                return reject()
            end

            if name == 'esx_property:ChangeInterior' and (type(args[2]) ~= 'string' or not GetInteriorValues(args[2])) then
                return reject()
            end

            if
                name == 'esx_property:ChangeEntrance'
                or name == 'esx_property:SetInventoryPosition'
                or (name == 'esx_property:SetWardrobePosition' and not args[3])
            then
                if not validCoords(args[2]) then
                    return reject()
                end
                args[2] = { x = args[2].x, y = args[2].y, z = args[2].z }
            end

            if
                name == 'esx_property:KnockOnDoor'
                and (GetPlayerRoutingBucket(playerId) ~= 0 or not isNearCoords(playerId, property.Entrance, PropertyActionDistance))
            then
                return reject()
            end
        end

        return handler(playerId, cb, table.unpack(args, 1, args.n))
    end)
end

local cctvSessions = {}

AddEventHandler('playerDropped', function()
    cctvSessions[source] = nil
end)

local function isNearPropertyGarage(source, Property)
    return Property and Property.garage and Property.garage.pos and isNearCoords(source, Property.garage.pos, 12.0)
end

local function isVehicleAlreadyStored(Property, plate)
    if storedVehiclePlateOwners[plate] then return true end

    if not Property or not Property.garage or not Property.garage.StoredVehicles then
        return false
    end

    for i = 1, #Property.garage.StoredVehicles do
        local vehicle = Property.garage.StoredVehicles[i]

        if vehicle.vehicle and normalizePlate(vehicle.vehicle.plate) == plate then
            return true
        end
    end

    return false
end

local function getPlayerVehicleForProps(source, vehicleProps)
    local ped = GetPlayerPed(source)

    if not ped or ped == 0 then
        return nil
    end

    local vehicle = GetVehiclePedIsIn(ped, false)

    if not vehicle or vehicle == 0 then
        return nil
    end

    if normalizePlate(GetVehicleNumberPlateText(vehicle) or '') ~= vehicleProps.plate then
        return nil
    end

    local model = tonumber(vehicleProps.model)

    if not model or GetEntityModel(vehicle) ~= model then
        return nil
    end

    return vehicle
end

local function PrepareProperties(properties)
    for id, property in ipairs(properties) do
        assert(type(property.Name) == 'string' and type(property.Interior) == 'string'
            and GetInteriorValues(property.Interior) and validCoords(property.Entrance)
            and finite(property.Price, 2147483647) and property.Price >= 0, ('Invalid core data for property %d'):format(id))

        if property.Keys == nil then property.Keys = {} end
        assert(type(property.Keys) == 'table', ('Invalid keys for property %d'):format(id))

        if property.Owner == nil then property.Owner = '' end
        if property.Owned == nil then property.Owned = false end
        if property.Locked == nil then property.Locked = false end
        assert(type(property.Owner) == 'string' and type(property.Owned) == 'boolean' and type(property.Locked) == 'boolean',
            ('Invalid ownership data for property %d'):format(id))

        if property.furniture == nil then property.furniture = {} end
        if property.cctv == nil then property.cctv = { enabled = false } end
        if property.garage == nil then property.garage = { enabled = false } end
        assert(type(property.garage) == 'table', ('Invalid garage for property %d'):format(id))
        
        if property.garage.StoredVehicles == nil then property.garage.StoredVehicles = {} end
        assert(type(property.garage.StoredVehicles) == 'table', ('Invalid stored vehicles for property %d'):format(id))
        property.setName = property.setName or ''

        if not property.positions then
            local interior = assert(GetInteriorValues(property.Interior), ('Invalid interior for property %d'):format(id))
            property.positions = json.decode(json.encode(interior.positions))
        end

        assert(type(property.positions) == 'table', ('Invalid positions for property %d'):format(id))
        assert(type(property.furniture) == 'table', ('Invalid furniture for property %d'):format(id))
        assert(type(property.cctv) == 'table', ('Invalid CCTV for property %d'):format(id))

        property.plysinside = {}

        if not Config.OxInventory then
            property.positions.Storage = nil
        end
    end

    return properties
end

function PropertiesRefresh()
    if refreshPending or next(PropertyLocks) then
        return false
    end

    refreshPending = true

    if propertySchemaReady and not SavePropertiesToSQL('Before properties refresh') then
        refreshPending = false
        return false
    end

    local previousSnapshot = json.encode(Properties)
    refreshInProgress = true

    local ok, nextProperties = pcall(function()
        return PrepareProperties(PropertyStorage.load())
    end)

    refreshInProgress = false
    refreshPending = false

    if not ok then
        propertySchemaReady = false
        error(('Could not load SQL properties; current data was kept and writes were disabled: %s'):format(tostring(nextProperties)))
    end

    if propertySchemaReady and (saveRequested or previousSnapshot ~= json.encode(Properties)) then
        return SavePropertiesToSQL('Changes made during properties refresh')
    end

    Properties = nextProperties
    updateVehiclePlateIndex()

    if Config.OxInventory then
        for id, property in ipairs(Properties) do
            if property.Owned then
                exports.ox_inventory:RegisterStash('property-' .. id, property.Name, 15, 100000, property.Owner)
            end
        end
    end

    Log('ESX-Property Loaded', 11141375, {
        { name = 'Property Count', value = #Properties, inline = true },
        { name = 'OX Inventory', value = Config.OxInventory and 'Enabled' or 'Disabled', inline = true },
    }, 1)

    for _, xPlayer in pairs(ESX.GetExtendedPlayers()) do
        TriggerClientEvent('esx_property:syncProperties', xPlayer.source, PropertiesForPlayer(xPlayer), xPlayer.get('lastProperty'))
    end

    return true
end

function IsPlayerAdmin(player, action)
    local xPlayer = ESX.GetPlayerFromId(player)

    if not xPlayer then
        return false
    end

    for i = 1, #Config.AllowedGroups do
        if xPlayer.group == Config.AllowedGroups[i] then
            return true
        end
    end

    if Config.PlayerManagement.Enabled and action and Config.PlayerManagement.Permissions[action] then
        if xPlayer.job.name == Config.PlayerManagement.job and xPlayer.job.grade >= Config.PlayerManagement.Permissions[action] then
            return true
        end
    end

    return false
end

MySQL.ready(function()
    local ok, err = pcall(function()
        xLib.schema.ensureProperty()
        PropertyStorage.initialize(PrepareProperties)
        PropertiesRefresh()
    end)

    propertyMigrationPending = false

    if not ok then
        print(('[esx_property] SQL initialization failed; properties are disabled: %s'):format(tostring(err)))
        return
    end

    propertySchemaReady = true
    print('[esx_property] SQL storage ready')

    -- Check if datastore table exists before to insert values.
    if
        MySQL.scalar.await(
            "SELECT EXISTS (SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_TYPE = 'BASE TABLE' AND TABLE_NAME = 'datastore')"
        ) > 0
    then
        MySQL.insert("INSERT IGNORE INTO `datastore` (name, label, shared) VALUES ('property', 'Property' , 1)", function(affectedRows)
            if affectedRows > 0 then
                print('[^2INFO^7] Added ^5Property^7 into ^5datastore^7 table')
            end
        end)

        MySQL.insert(
            "INSERT INTO `datastore_data` (name, owner, data) SELECT 'property', NULL, '{}' FROM (SELECT COUNT(*) AS matches FROM `datastore_data` WHERE `name` = 'property' AND `owner` IS NULL) AS existing WHERE existing.matches = 0",
            function(affectedRows)
                if affectedRows > 0 then
                    print('[^2INFO^7] Added ^5Property^7 into ^5datastore_data^7 table')
                end
            end
        )
    end

    if PM.Enabled then
        if
            MySQL.scalar.await(
                "SELECT EXISTS (SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_TYPE = 'BASE TABLE' AND TABLE_NAME = 'addon_account')"
            ) > 0
        then
            MySQL.insert('INSERT IGNORE INTO `addon_account` (name, label, shared) VALUES (?, ? , 1)', { PM.society, PM.joblabel }, function(affectedRows)
                if affectedRows > 0 then
                    print('[^2INFO^7] Added ^5' .. PM.society .. ' - ' .. PM.joblabel .. '^7 into ^5addon_account^7 table')
                end
            end)
        end

        if not ESX.DoesJobExist(PM.job, 0) then
            MySQL.insert('INSERT INTO `jobs` SET name = ?, label = ?, whitelisted = 1', { PM.job, PM.joblabel }, function(affectedRows)
                if affectedRows > 0 then
                    print('[^2INFO^7] Inserted ^5' .. PM.job .. ' - ' .. PM.joblabel .. '^7 into ^5jobs^7 table')
                end
            end)
        end

        local QUERIES = {}

        for i = 1, #PM.jobRanks do
            if not ESX.DoesJobExist(PM.job, PM.jobRanks[i].grade) then
                QUERIES[i] = {
                    query = "INSERT INTO `job_grades` SET job_name = ?, grade = ?, name = ?, label = ?, salary = ?, skin_male = '{}', skin_female = '{}'",
                    parameters = {
                        PM.job,
                        PM.jobRanks[i].grade,
                        PM.jobRanks[i].name,
                        PM.jobRanks[i].label,
                        PM.jobRanks[i].salary,
                    },
                }
            end
        end

        MySQL.transaction(QUERIES)

        Wait(10)
        ESX.RefreshJobs()
        exports['esx_society']:registerSociety(
            'realestateagent',
            'realestateagent',
            'society_realestateagent',
            'society_realestateagent',
            'society_realestateagent',
            { type = 'private' }
        )
    end
end)

AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    while propertyMigrationPending do
        Wait(50)
    end

    if not propertySchemaReady then
        TriggerClientEvent('esx_property:syncProperties', playerId, {}, nil)
        return
    end

    local lastProperty = nil

    MySQL.query('SELECT last_property FROM users WHERE identifier = ?', { xPlayer.identifier }, function(result)
        if result then
            if result[1].last_property then
                local Data = json.decode(result[1].last_property)

                xPlayer.set('lastProperty', Data)
                lastProperty = Data
            end
        end

        TriggerClientEvent('esx_property:syncProperties', playerId, PropertiesForPlayer(xPlayer), lastProperty)
    end)
end)

--- Commands
ESX.RegisterCommand(_('refresh_name'), Config.AllowedGroups, function(xPlayer)
    PropertiesRefresh()
end, false, { help = TranslateCap('refresh_desc') })

ESX.RegisterCommand(_('create_name'), 'user', function(xPlayer)
    if IsPlayerAdmin(xPlayer.source) or (PM.Enabled and xPlayer.job.name == PM.job) then
        xPlayer.triggerEvent('esx_property:CreateProperty')
    end
end, false, { help = TranslateCap('create_desc') })

ESX.RegisterCommand(_('admin_name'), Config.AllowedGroups, function(xPlayer)
    xPlayer.triggerEvent('esx_property:AdminMenu')
end, false, { help = TranslateCap('admin_desc') })

-- Buy Property
registerPropertyCallback('esx_property:buyProperty', function(source, cb, PropertyId)
    local xPlayer = ESX.GetPlayerFromId(source)

    PropertyId = normalizePropertyId(PropertyId)

    local Property = PropertyId and Properties[PropertyId]

    if
        not xPlayer
        or not Property
        or PM.Enabled
        or Property.Owned
        or PropertyLocks[PropertyId]
        or not isNearCoords(source, Property.Entrance, PropertyActionDistance)
    then
        return cb(false)
    end

    local Price = tonumber(Property.Price)

    if not Price or Price <= 0 then
        return cb(false)
    end

    local canAfford = getBankMoney(xPlayer) >= Price

    if not canAfford then
        return cb(false)
    end

    PropertyLocks[PropertyId] = true

    if Property.Owned then
        PropertyLocks[PropertyId] = nil
        return cb(false)
    end

    if xPlayer.removeAccountMoney('bank', Price, 'Bought Property') == false then
        PropertyLocks[PropertyId] = nil
        return cb(false)
    end

    Property.Owner = xPlayer.identifier
    Property.OwnerName = xPlayer.getName()
    Property.Owned = true
    Property.Keys = Property.Keys or {}
    clearPendingSaleForProperty(PropertyId)

    Log('Property Bought', 65280, {
        {
            name = '**Property Name**',
            value = Property.Name,
            inline = true,
        },
        {
            name = '**Price**',
            value = ESX.Math.GroupDigits(Price),
            inline = true,
        },
        {
            name = '**Player**',
            value = xPlayer.getName(),
            inline = true,
        },
    }, 1)

    SyncPropertiesAndSave('Property bought', PropertyId)

    if Config.OxInventory then
        exports.ox_inventory:RegisterStash('property-' .. PropertyId, Property.Name, 15, 100000, xPlayer.identifier)
    end

    PropertyLocks[PropertyId] = nil
    cb(true)
end)

registerPropertyCallback('esx_property:attemptSellToPlayer', function(source, cb, PropertyId, PlayerId)
    local xPlayer = ESX.GetPlayerFromId(source)

    PlayerId = tonumber(PlayerId)
    PropertyId = normalizePropertyId(PropertyId)

    if not xPlayer or not PlayerId or PlayerId ~= math.floor(PlayerId) or PlayerId == source or not PM.Enabled or not IsPlayerAdmin(source, 'SellProperty') then
        return cb(false)
    end

    local xTarget = ESX.GetPlayerFromId(PlayerId)
    local Property = PropertyId and Properties[PropertyId]

    if not xTarget or not Property or Property.Owned or PropertyLocks[PropertyId] then
        return cb(false)
    end

    local Price = tonumber(Property.Price)

    if not Price or Price <= 0 or getBankMoney(xTarget) < Price then
        return cb(false)
    end

    if not isNearCoords(source, Property.Entrance, PropertyActionDistance) or not isNearCoords(PlayerId, Property.Entrance, PropertyActionDistance) then
        return cb(false)
    end

    local token = ('%s:%s:%s:%s'):format(source, PlayerId, PropertyId, GetGameTimer())

    PendingPropertySales[token] = {
        seller = source,
        target = PlayerId,
        propertyId = PropertyId,
        price = Price,
        expires = GetGameTimer() + PropertySaleOfferDuration,
    }
    PropertyLocks[PropertyId] = token

    SetTimeout(PropertySaleOfferDuration, function()
        local offer = PendingPropertySales[token]

        if offer and offer.expires <= GetGameTimer() then
            PendingPropertySales[token] = nil

            if PropertyLocks[offer.propertyId] == token then
                PropertyLocks[offer.propertyId] = nil
            end
        end
    end)

    TriggerClientEvent(
        'esx_property:receivePropertyOffer',
        xTarget.source,
        token,
        xPlayer.getName(),
        Property.setName ~= '' and Property.setName or Property.Name,
        Price
    )
    xPlayer.showNotification('Property sale offer sent.', 'success')
    cb(true)
end)

registerPropertyCallback('esx_property:respondToSaleOffer', function(source, cb, token, accepted)
    if type(token) ~= 'string' then
        return cb(false)
    end

    accepted = accepted == true

    local offer = PendingPropertySales[token]

    if not offer or offer.target ~= source then
        return cb(false)
    end

    PendingPropertySales[token] = nil

    local xTarget = ESX.GetPlayerFromId(source)
    local xSeller = ESX.GetPlayerFromId(offer.seller)
    local PropertyId = normalizePropertyId(offer.propertyId)
    local Property = PropertyId and Properties[PropertyId]

    if not accepted then
        if PropertyLocks[offer.propertyId] == token then
            PropertyLocks[offer.propertyId] = nil
        end

        if xSeller then
            xSeller.showNotification('Property sale declined.', 'error')
        end

        return cb(false)
    end

    if
        not xTarget
        or not xSeller
        or not Property
        or offer.expires < GetGameTimer()
        or Property.Owned
        or (PropertyLocks[PropertyId] and PropertyLocks[PropertyId] ~= token)
    then
        if PropertyLocks[offer.propertyId] == token then
            PropertyLocks[offer.propertyId] = nil
        end

        return cb(false)
    end

    if not PM.Enabled or not IsPlayerAdmin(offer.seller, 'SellProperty') then
        if PropertyLocks[PropertyId] == token then
            PropertyLocks[PropertyId] = nil
        end

        return cb(false)
    end

    local Price = tonumber(Property.Price)

    if not Price or Price <= 0 or Price ~= offer.price or getBankMoney(xTarget) < Price then
        if PropertyLocks[PropertyId] == token then
            PropertyLocks[PropertyId] = nil
        end

        return cb(false)
    end

    if not isNearCoords(offer.seller, Property.Entrance, PropertyActionDistance) or not isNearCoords(source, Property.Entrance, PropertyActionDistance) then
        if PropertyLocks[PropertyId] == token then
            PropertyLocks[PropertyId] = nil
        end

        return cb(false)
    end

    PropertyLocks[PropertyId] = true

    if Property.Owned or xTarget.removeAccountMoney('bank', Price, 'Sold Property') == false then
        PropertyLocks[PropertyId] = nil
        return cb(false)
    end

    Property.Owner = xTarget.identifier
    Property.OwnerName = xTarget.getName()
    Property.Owned = true
    Property.Keys = Property.Keys or {}
    clearPendingSaleForProperty(PropertyId)

    Log('Property Sold To Player', 65280, {
        { name = '**Property Name**', value = Property.Name, inline = true },
        { name = '**Price**', value = ESX.Math.GroupDigits(Price), inline = true },
        { name = '**Player**', value = xTarget.getName(), inline = true },
        { name = '**Agent**', value = xSeller.getName(), inline = true },
    }, 1)
    SyncPropertiesAndSave('Property sold to player', PropertyId)

    if Config.OxInventory then
        exports.ox_inventory:RegisterStash('property-' .. PropertyId, Property.Name, 15, 100000, xTarget.identifier)
    end

    local PlayerPrice = ESX.Math.Round(Price * PM.SalePercentage)
    local SocietyPrice = Price - PlayerPrice

    TriggerEvent('esx_addonaccount:getSharedAccount', PM.society, function(account)
        account.addMoney(SocietyPrice)
    end)

    xSeller.addAccountMoney('bank', PlayerPrice, 'Sold Property')

    PropertyLocks[PropertyId] = nil

    if xSeller then
        xSeller.showNotification('Property sale accepted.', 'success')
    end

    cb(true)
end)

-- Buy Property
registerPropertyCallback('esx_property:buyFurniture', function(source, cb, PropertyId, PropName, PropIndex, PropCatagory, pos, heading)
    local xPlayer = ESX.GetPlayerFromId(source)

    PropertyId = normalizePropertyId(PropertyId)
    PropIndex = tonumber(PropIndex)

    if not PropIndex or PropIndex ~= math.floor(PropIndex) then
        return cb(false)
    end

    local Property = PropertyId and Properties[PropertyId]
    local Catagory = Config.FurnitureCatagories[PropCatagory]
    local FurnitureItem = Catagory and Catagory[PropIndex]

    if not xPlayer or not Property or not FurnitureItem then
        return cb(false)
    end

    local hasAccess = xPlayer.identifier == Property.Owner or IsPlayerAdmin(source) or (Property.Keys and Property.Keys[xPlayer.identifier])

    if not hasAccess then
        return cb(false)
    end

    local Price = tonumber(FurnitureItem.price)

    if not Price or Price <= 0 then
        return cb(false)
    end

    local furnitureCount = 0
    for _ in pairs(Property.furniture or {}) do furnitureCount = furnitureCount + 1 end
    if furnitureCount >= (Config.MaxFurniturePerProperty or 500) then return cb(false) end

    if getBankMoney(xPlayer) < Price then
        xPlayer.showNotification(TranslateCap('furni_cannot_afford'))
        return cb(false)
    end

    if xPlayer.removeAccountMoney('bank', Price, 'Furniture') == false then
        return cb(false)
    end

    cb(true)
    Property.furniture = Property.furniture or {}
    Property.plysinside = Property.plysinside or {}

    local furniture = {
        Name = FurnitureItem.name,
        Index = PropIndex,
        Catagory = PropCatagory,
        Pos = pos,
        Heading = heading,
        Price = Price,
    }

    table.insert(Property.furniture, furniture)

    for i = 1, #Property.plysinside do
        TriggerClientEvent('esx_property:placeFurniture', Property.plysinside[i], PropertyId, furniture, #Property.furniture)
    end

    SyncFurniture(PropertyId)
    SchedulePropertiesSave('Furniture bought', PropertyId)

    Log('Furniture Bought', 3640511, {
        { name = '**Property Name**', value = Property.Name, inline = true },
        { name = '**Player**', value = xPlayer.getName(), inline = true },
        {
            name = '**Has Access**',
            value = hasAccess and 'Yes' or 'No',
            inline = true,
        },
        { name = '**Prop Name**', value = FurnitureItem.title, inline = true },
        { name = '**Price**', value = tostring(Price), inline = true },
        { name = '**Can Afford**', value = 'Yes', inline = true },
    }, 1)
end)

-- Selling Property

registerPropertyCallback('esx_property:sellProperty', function(source, cb, PropertyId)
    local xPlayer = ESX.GetPlayerFromId(source)

    PropertyId = normalizePropertyId(PropertyId)

    local Property = PropertyId and Properties[PropertyId]

    if
        not xPlayer
        or not Property
        or Property.Owner ~= xPlayer.identifier
        or PropertyLocks[PropertyId]
        or not isNearCoords(source, Property.Entrance, PropertyActionDistance)
    then
        return cb(false)
    end

    PropertyLocks[PropertyId] = true

    local BasePrice = tonumber(Property.Price)

    if not BasePrice or BasePrice <= 0 then
        PropertyLocks[PropertyId] = nil
        return cb(false)
    end

    local Price = ESX.Math.Round(BasePrice * 0.6)

    xPlayer.addAccountMoney('bank', Price, 'Sold Property')
    Property.Owner = ''
    Property.OwnerName = ''
    Property.Owned = false
    Property.Locked = false
    Property.Keys = {}

    local furn = #Property.furniture

    if Config.WipeFurnitureOnSell then
        Property.furniture = {}
    end

    if Config.WipeCustomNameOnSell then
        Property.setName = ''
    end

    Property.plysinside = {}
    clearPendingSaleForProperty(PropertyId)

    local StoredVehicles = Property.garage and Property.garage.StoredVehicles

    Log('Property Sold', 16711680, {
        { name = '**Property Name**', value = Property.Name, inline = true },
        { name = '**Price**', value = ESX.Math.GroupDigits(Price), inline = true },
        { name = '**Owner**', value = xPlayer.getName(), inline = true },
        { name = '**Furniture Count**', value = tostring(furn), inline = true },
        {
            name = '**Vehicle Count**',
            value = tostring(StoredVehicles and #StoredVehicles or 'N/A'),
            inline = true,
        },
    }, 1)

    if StoredVehicles then
        Property.garage.StoredVehicles = {}
    end

    SyncPropertiesAndSave('Property sold', PropertyId)

    if Config.OxInventory then
        exports.ox_inventory:ClearInventory('property-' .. PropertyId)
    end

    PropertyLocks[PropertyId] = nil
    cb(true)
end)

-- Admin Menu Options

registerPropertyCallback('esx_property:toggleLock', function(source, cb, PropertyId)
    local xPlayer = ESX.GetPlayerFromId(source)
    local Owner = Properties[PropertyId].Owner

    if
        xPlayer.identifier == Owner
        or IsPlayerAdmin(source, 'ToggleLock')
        or (Properties[PropertyId].Keys and Properties[PropertyId].Keys[xPlayer.identifier])
    then
        Properties[PropertyId].Locked = not Properties[PropertyId].Locked
        SyncPropertiesAndSave('Property lock toggled', PropertyId)
    end

    Log('Lock Toggled', 3640511, {
        { name = '**Property Name**', value = Properties[PropertyId].Name, inline = true },
        { name = '**Owner**', value = Properties[PropertyId].OwnerName, inline = true },
        { name = '**Executing User**', value = xPlayer.getName(), inline = true },
        {
            name = '**Status**',
            value = Properties[PropertyId].Locked and 'Locked' or 'Unlocked',
            inline = true,
        },
    }, 3)
    cb(xPlayer.identifier == Owner or IsPlayerAdmin(source, 'ToggleLock') or (Properties[PropertyId].Keys and Properties[PropertyId].Keys[xPlayer.identifier]))
end)

registerPropertyCallback('esx_property:toggleGarage', function(source, cb, PropertyId)
    local xPlayer = ESX.GetPlayerFromId(source)

    if IsPlayerAdmin(source, 'ToggleGarage') then
        Properties[PropertyId].garage.enabled = not Properties[PropertyId].garage.enabled
        SyncPropertiesAndSave('Property garage toggled', PropertyId)
        Log('Property Garage Toggled', 3640511, {
            { name = '**Property Name**', value = Properties[PropertyId].Name, inline = true },
            { name = '**Owner**', value = Properties[PropertyId].OwnerName, inline = true },
            { name = '**Admin**', value = xPlayer.getName(), inline = true },
            {
                name = '**Status**',
                value = Properties[PropertyId].garage.enabled and 'Enabled' or 'Disabled',
                inline = true,
            },
        }, 2)
        cb(true, Properties[PropertyId].garage.enabled)
    else
        cb(false)
    end
end)

registerPropertyCallback('esx_property:toggleCCTV', function(source, cb, PropertyId)
    local xPlayer = ESX.GetPlayerFromId(source)

    if IsPlayerAdmin(source, 'ToggleCCTV') then
        Properties[PropertyId].cctv.enabled = not Properties[PropertyId].cctv.enabled
        SyncPropertiesAndSave('Property CCTV toggled', PropertyId)
        cb(true, Properties[PropertyId].cctv.enabled)
        Log('Property CCTV Toggled', 3640511, {
            { name = '**Property Name**', value = Properties[PropertyId].Name, inline = true },
            { name = '**Owner**', value = Properties[PropertyId].OwnerName, inline = true },
            { name = '**Admin**', value = xPlayer.getName(), inline = true },
            {
                name = '**Status**',
                value = Properties[PropertyId].cctv.enabled and 'Enabled' or 'Disabled',
                inline = true,
            },
        }, 2)
    else
        cb(false)
    end
end)

registerPropertyCallback('esx_property:SetGaragePos', function(source, cb, PropertyId, heading)
    local xPlayer = ESX.GetPlayerFromId(source)

    if IsPlayerAdmin(source, 'ToggleGarage') then
        local PlayerPed = GetPlayerPed(source)
        local PlayerPos = GetEntityCoords(PlayerPed)
        local Property = Properties[PropertyId]
        local Original = Properties[PropertyId].garage.pos
                and Properties[PropertyId].garage.pos.x .. ', ' .. Properties[PropertyId].garage.pos.y .. ', ' .. Properties[PropertyId].garage.pos.z
            or 'N/A'

        Properties[PropertyId].garage.pos = PlayerPos
        Properties[PropertyId].garage.Heading = heading
        SyncPropertiesAndSave('Property garage position changed', PropertyId)
        Log('Property Garage Location Changed', 3640511, {
            { name = '**Property Name**', value = Properties[PropertyId].Name, inline = true },
            { name = '**Owner**', value = Properties[PropertyId].OwnerName, inline = true },
            { name = '**Admin**', value = xPlayer.getName(), inline = true },
            { name = '**Original Position**', value = tostring(Original), inline = true },
            { name = '**New Position**', value = tostring(PlayerPos), inline = true },
        }, 2)
        cb(true)
    else
        cb(false)
    end
end)

registerPropertyCallback('esx_property:SetCCTVangle', function(source, cb, PropertyId, angles)
    local xPlayer = ESX.GetPlayerFromId(source)

    if IsPlayerAdmin(source, 'ToggleCCTV') then
        local Property = Properties[PropertyId]

        Properties[PropertyId].cctv.rot = angles.rot
        Properties[PropertyId].cctv.maxleft = angles.maxleft
        Properties[PropertyId].cctv.maxright = angles.maxright
        SyncPropertiesAndSave('Property CCTV angle changed', PropertyId)

        cb(true)

        Log('Property CCTV Angle Changed', 3640511, {
            { name = '**Property Name**', value = Properties[PropertyId].Name, inline = true },
            { name = '**Owner**', value = Properties[PropertyId].OwnerName, inline = true },
            { name = '**Admin**', value = xPlayer.getName(), inline = true },
        }, 2)
    else
        cb(false)
    end
end)

registerPropertyCallback('esx_property:CCTV', function(source, cb, PropertyId)
    local player = ESX.GetPlayerFromId(source)
    local property = Properties[PropertyId]

    if
        not Config.CCTV.Enabled
        or not property.cctv
        or not property.cctv.enabled
        or cctvSessions[source]
        or not (hasPropertyAccess(player, property) or IsPlayerAdmin(source))
        or not isPlayerInsideProperty(source, property)
        or GetPlayerRoutingBucket(source) ~= PropertyId + 1
    then
        return cb(false)
    end

    local interior = GetInteriorValues(property.Interior)

    if not interior then
        return cb(false)
    end

    local origin = interior.type == 'shell' and vector3(property.Entrance.x, property.Entrance.y, 2001) or interior.pos

    if not origin or not isNearCoords(source, origin, 100.0) then
        return cb(false)
    end

    cctvSessions[source] = {
        id = PropertyId,
        identifier = player.identifier,
        coords = GetEntityCoords(GetPlayerPed(source)),
        bucket = GetPlayerRoutingBucket(source),
    }

    SetEntityCoords(GetPlayerPed(source), vector3(property.Entrance.x, property.Entrance.y, property.Entrance.z + 5.0))
    SetPlayerRoutingBucket(source, 0)
    cb(true)
end)

registerPropertyCallback('esx_property:ExitCCTV', function(source, cb, PropertyId)
    local player = ESX.GetPlayerFromId(source)
    local property = Properties[PropertyId]
    local session = cctvSessions[source]

    if
        not session
        or session.id ~= PropertyId
        or session.identifier ~= player.identifier
        or GetPlayerRoutingBucket(source) ~= 0
        or not isNearCoords(source, property.Entrance, 15.0)
    then
        return cb(false)
    end

    cctvSessions[source] = nil

    if hasPropertyAccess(player, property) or IsPlayerAdmin(source) then
        SetEntityCoords(GetPlayerPed(source), session.coords)
        SetPlayerRoutingBucket(source, session.bucket)
    else
        SetEntityCoords(GetPlayerPed(source), vector3(property.Entrance.x, property.Entrance.y, property.Entrance.z))
        SetPlayerRoutingBucket(source, 0)
    end

    cb(true)
end)

registerPropertyCallback('esx_property:SetPropertyName', function(source, cb, PropertyId, name)
    local xPlayer = ESX.GetPlayerFromId(source)
    local Owner = Properties[PropertyId].Owner
    local Property = Properties[PropertyId]

    if xPlayer.identifier == Owner or IsPlayerAdmin(source) then
        if name and #name <= Config.MaxNameLength then
            Properties[PropertyId].setName = name
            SyncPropertiesAndSave('Property name changed', PropertyId)
            Log('Property Name Changed', 3640511, {
                {
                    name = '**Property Name**',
                    value = Properties[PropertyId].Name,
                    inline = true,
                },
                { name = '**Player**', value = xPlayer.getName(), inline = true },
                { name = '**New Name**', value = name, inline = true },
            }, 2)
        end
    end

    cb((xPlayer.identifier == Owner or IsPlayerAdmin(source, 'SetPropertyName')) and name and #name <= Config.MaxNameLength)
end)

registerPropertyCallback('esx_property:KnockOnDoor', function(source, cb, PropertyId, name)
    local xPlayer = ESX.GetPlayerFromId(source)
    local Property = Properties[PropertyId]
    local Owner = ESX.GetPlayerFromIdentifier(Property.Owner)

    if Owner then
        for i = 1, #Property.plysinside do
            if Property.plysinside[i] == Owner.source then
                Owner.showNotification(TranslateCap('knocking'), 'info')
                Log('Player Knocked On Door', 3640511, {
                    {
                        name = '**Property Name**',
                        value = Properties[PropertyId].Name,
                        inline = true,
                    },
                    {
                        name = '**Owner**',
                        value = Properties[PropertyId].OwnerName,
                        inline = true,
                    },
                    { name = '**Player**', value = xPlayer.getName(), inline = true },
                }, 3)
                return cb(true)
            end
        end

        cb(false)
    else
        cb(false)
    end
end)

registerPropertyCallback('esx_property:RemoveCustomName', function(source, cb, PropertyId, name)
    local Property = Properties[PropertyId]
    local xPlayer = ESX.GetPlayerFromId(source)

    if IsPlayerAdmin(source, 'RemovePropertyName') then
        local n = Properties[PropertyId].setName

        Properties[PropertyId].setName = ''
        SyncPropertiesAndSave('Property name reset', PropertyId)
        Log('Property Name Reset', 3640511, {
            { name = '**Property Name**', value = Properties[PropertyId].Name, inline = true },
            { name = '**Owner**', value = Properties[PropertyId].OwnerName, inline = true },
            { name = '**Admin**', value = xPlayer.getName(), inline = true },
            { name = '**Removed Name**', value = n, inline = true },
        }, 3)
        cb(true)
    else
        cb(false)
    end
end)

registerPropertyCallback('esx_property:deleteProperty', function(source, cb, PropertyId)
    local xPlayer = ESX.GetPlayerFromId(source)

    if next(PropertyLocks) then return cb(false) end

    if IsPlayerAdmin(source, 'DeleteProperty') then
        Log('Property Deleted', 16711680, {
            { name = '**Property Name**', value = Properties[PropertyId].Name, inline = true },
            { name = '**Admin**', value = xPlayer.getName(), inline = true },
            {
                name = '**Owner**',
                value = Properties[PropertyId].OwnerName ~= '' and Properties[PropertyId].OwnerName or 'N/A',
                inline = true,
            },
            {
                name = '**Furniture Count**',
                value = #Properties[PropertyId].furniture,
                inline = true,
            },
            {
                name = '**Vehicle Count**',
                value = Properties[PropertyId].garage.StoredVehicles and #Properties[PropertyId].garage.StoredVehicles or 'N/A',
                inline = true,
            },
        }, 1)
        table.remove(Properties, PropertyId)
        clearPendingSaleForProperty(PropertyId)
        SyncPropertiesAndSave('Property deleted')

        if Config.OxInventory then
            exports.ox_inventory:ClearInventory('property-' .. PropertyId)
        end
    end

    cb(IsPlayerAdmin(source, 'DeleteProperty'))
end)

registerPropertyCallback('esx_property:ChangePrice', function(source, cb, PropertyId, NewPrice)
    local xPlayer = ESX.GetPlayerFromId(source)

    if IsPlayerAdmin(source, 'SetPropertyPrice') then
        local Original = Properties[PropertyId].Price

        Properties[PropertyId].Price = NewPrice
        SyncPropertiesAndSave('Property price changed', PropertyId)
        Log('Property Price Changed', 3640511, {
            { name = '**Property Name**', value = Properties[PropertyId].Name, inline = true },
            { name = '**Admin**', value = xPlayer.getName(), inline = true },
            { name = '**Original Price**', value = tostring(Original), inline = true },
            { name = '**New Price**', value = tostring(NewPrice), inline = true },
        }, 2)
    end

    cb(IsPlayerAdmin(source, 'SetPropertyPrice'))
end)

registerPropertyCallback('esx_property:ChangeInterior', function(source, cb, PropertyId, Interior)
    local xPlayer = ESX.GetPlayerFromId(source)

    if IsPlayerAdmin(source, 'ChangeInterior') then
        local Original = GetInteriorValues(Properties[PropertyId].Interior).label

        Properties[PropertyId].Interior = Interior
        Properties[PropertyId].furniture = {}
        Properties[PropertyId].positions = GetInteriorValues(Interior).positions

        if not Config.OxInventory then
            Properties[PropertyId].positions.Storage = nil
        end

        SyncPropertiesAndSave('Property interior changed', PropertyId)
        Log('Property Interior Changed', 3640511, {
            { name = '**Property Name**', value = Properties[PropertyId].Name, inline = true },
            { name = '**Admin**', value = xPlayer.getName(), inline = true },
            { name = '**Original**', value = tostring(Original), inline = true },
            {
                name = '**New Interior**',
                value = GetInteriorValues(Properties[PropertyId].Interior).label,
                inline = true,
            },
        }, 2)
    end

    cb(IsPlayerAdmin(source, 'ChangeInterior'))
end)

registerPropertyCallback('esx_property:RemoveAllfurniture', function(source, cb, PropertyId)
    local xPlayer = ESX.GetPlayerFromId(source)

    PropertyId = normalizePropertyId(PropertyId)

    local Property = PropertyId and Properties[PropertyId]

    if not xPlayer or not Property then
        return cb(false)
    end

    local hasAccess = xPlayer.identifier == Property.Owner or IsPlayerAdmin(source, 'ResetFurniture') or (Property.Keys and Property.Keys[xPlayer.identifier])

    if hasAccess then
        Property.plysinside = Property.plysinside or {}
        Property.furniture = Property.furniture or {}

        for i = 1, #Property.plysinside do
            for furniture = 1, #Property.furniture do
                TriggerClientEvent('esx_property:removeFurniture', Property.plysinside[i], PropertyId, furniture)
            end
        end

        Property.furniture = {}
        SyncFurniture(PropertyId)
        SchedulePropertiesSave('Property furniture reset', PropertyId)
    end

    Log('Property Furniture Reset', 16711680, {
        { name = '**Property Name**', value = Property.Name, inline = true },
        { name = '**Admin**', value = xPlayer.getName(), inline = true },
    }, 1)
    cb(hasAccess)
end)

registerPropertyCallback('esx_property:deleteFurniture', function(source, cb, PropertyId, furnitureIndex)
    local xPlayer = ESX.GetPlayerFromId(source)

    PropertyId = normalizePropertyId(PropertyId)
    furnitureIndex = tonumber(furnitureIndex)

    local Property = PropertyId and Properties[PropertyId]

    if not xPlayer or not Property or not furnitureIndex or furnitureIndex ~= math.floor(furnitureIndex) then
        return cb(false)
    end

    local hasAccess = xPlayer.identifier == Property.Owner or IsPlayerAdmin(source) or (Property.Keys and Property.Keys[xPlayer.identifier])

    if hasAccess then
        Property.furniture = Property.furniture or {}
        Property.plysinside = Property.plysinside or {}

        if Property.furniture[furnitureIndex] then
            Property.furniture[furnitureIndex] = nil
            SyncFurniture(PropertyId)
            SchedulePropertiesSave('Property furniture deleted', PropertyId)
        end

        for i = 1, #Property.plysinside do
            TriggerClientEvent('esx_property:removeFurniture', Property.plysinside[i], PropertyId, furnitureIndex)
        end
    end

    Log('Property Furniture Deleted', 16711680, {
        { name = '**Property Name**', value = Property.Name, inline = true },
        { name = '**Admin**', value = xPlayer.getName(), inline = true },
        { name = '**Furniture Name**', value = xPlayer.getName(), inline = true },
    }, 3)
    cb(hasAccess)
end)

registerPropertyCallback('esx_property:editFurniture', function(source, cb, PropertyId, furnitureIndex, Pos, Heading)
    local xPlayer = ESX.GetPlayerFromId(source)

    PropertyId = normalizePropertyId(PropertyId)
    furnitureIndex = tonumber(furnitureIndex)

    local Property = PropertyId and Properties[PropertyId]

    if not xPlayer or not Property or not furnitureIndex or furnitureIndex ~= math.floor(furnitureIndex) then
        return cb(false)
    end

    local hasAccess = xPlayer.identifier == Property.Owner or IsPlayerAdmin(source) or (Property.Keys and Property.Keys[xPlayer.identifier])

    if hasAccess then
        Property.furniture = Property.furniture or {}
        Property.plysinside = Property.plysinside or {}

        if Property.furniture[furnitureIndex] then
            Property.furniture[furnitureIndex].Pos = Pos
            Property.furniture[furnitureIndex].Heading = Heading
            SyncFurniture(PropertyId)
            SchedulePropertiesSave('Property furniture edited', PropertyId)

            for i = 1, #Property.plysinside do
                TriggerClientEvent('esx_property:editFurniture', Property.plysinside[i], PropertyId, furnitureIndex, Pos, Heading)
            end
        end
    end

    cb(hasAccess)
end)

registerPropertyCallback('esx_property:evictOwner', function(source, cb, PropertyId, Interior)
    local xPlayer = ESX.GetPlayerFromId(source)

    if IsPlayerAdmin(source, 'EvictOwner') then
        local xOwner = ESX.GetPlayerFromIdentifier(Properties[PropertyId].Owner)

        if xOwner then
            xOwner.showNotification('Your Have Been ~r~Evicted~s~.', 'error')
        end

        local pName = Properties[PropertyId].OwnerName

        Properties[PropertyId].Owner = ''
        Properties[PropertyId].Owned = false
        Properties[PropertyId].OwnerName = ''
        Properties[PropertyId].Locked = false
        Properties[PropertyId].Keys = {}

        if Config.WipeFurnitureOnSell then
            Properties[PropertyId].furniture = {}
        end

        Properties[PropertyId].setName = ''
        Properties[PropertyId].plysinside = {}

        if Properties[PropertyId].garage.StoredVehicles then
            Properties[PropertyId].garage.StoredVehicles = {}
        end

        clearPendingSaleForProperty(PropertyId)
        SyncPropertiesAndSave('Property owner evicted', PropertyId)

        if Config.OxInventory then
            exports.ox_inventory:ClearInventory('property-' .. PropertyId)
        end

        Log('Property Owner Evicted', 3640511, {
            { name = '**Property Name**', value = Properties[PropertyId].Name, inline = true },
            { name = '**Owner**', value = pName, inline = true },
            { name = '**Admin**', value = xPlayer.getName(), inline = true },
            {
                name = '**Has Access**',
                value = IsPlayerAdmin(source, 'EvictOwner') and 'Yes' or 'No',
                inline = true,
            },
        }, 1)
    end

    cb(IsPlayerAdmin(source, 'EvictOwner'))
end)

registerPropertyCallback('esx_property:CanRaid', function(source, cb, PropertyId, Interior)
    local xPlayer = ESX.GetPlayerFromId(source)

    PropertyId = normalizePropertyId(PropertyId)

    local Property = PropertyId and Properties[PropertyId]

    if
        not xPlayer
        or not Property
        or not Config.Raiding.Enabled
        or PropertyLocks[PropertyId]
        or not isNearCoords(source, Property.Entrance, PropertyActionDistance)
    then
        return cb(false)
    end

    if propertyRaidLimiter:retryAfter(source) > 0 then
        return cb(false)
    end

    local isPolice = xPlayer.job and xPlayer.job.name == 'police' and xPlayer.job.onDuty ~= false
    local isAdminRaid = Config.Raiding.CanAdminsRaid and IsPlayerAdmin(source)

    if not isAdminRaid and not isPolice then
        return cb(false)
    end

    if Config.Raiding.ItemRequired then
        local required = Config.Raiding.ItemRequired
        local item = xPlayer.getInventoryItem(required.name)
        local itemCount = item and item.count or 0

        if itemCount < required.ItemCount then
            xPlayer.showNotification(TranslateCap('raid_notify_error', required.ItemCount, required.name), 'error')
            return cb(false)
        end

        if required.RemoveItem then
            xPlayer.removeInventoryItem(required.name, required.ItemCount)
        end
    end

    PropertyLocks[PropertyId] = true
    propertyRaidLimiter:consume(source)
    cb(true)

    CreateThread(function()
        local xOwner = ESX.GetPlayerFromIdentifier(Property.Owner)

        if xOwner then
            xOwner.showNotification(TranslateCap('raid_notify_success'), 'error')
        end

        Wait(15000)

        if Properties[PropertyId] and isNearCoords(source, Properties[PropertyId].Entrance, PropertyActionDistance) then
            Properties[PropertyId].Locked = false
            SyncPropertiesAndSave('Property raided', PropertyId)
        end

        PropertyLocks[PropertyId] = nil
    end)
end)

registerPropertyCallback('esx_property:ChangeEntrance', function(source, cb, PropertyId, Coords)
    local xPlayer = ESX.GetPlayerFromId(source)

    if IsPlayerAdmin(source, 'ChangeEntrance') then
        local Origonal = Properties[PropertyId].Entrance.x .. ',' .. Properties[PropertyId].Entrance.y .. ',' .. Properties[PropertyId].Entrance.z

        Properties[PropertyId].Entrance = {
            x = ESX.Math.Round(Coords.x, 2),
            y = ESX.Math.Round(Coords.y, 2),
            z = ESX.Math.Round(Coords.z, 2) - 0.8,
        }
        clearPendingSaleForProperty(PropertyId)
        SyncPropertiesAndSave('Property entrance changed', PropertyId)
        Log('Property Entrance Changed', 3640511, {
            { name = '**Property Name**', value = Properties[PropertyId].Name, inline = true },
            { name = '**Owner**', value = Properties[PropertyId].OwnerName, inline = true },
            { name = '**Admin**', value = xPlayer.getName(), inline = true },
            {
                name = '**Has Access**',
                value = IsPlayerAdmin(source, 'ChangeEntrance') and 'Yes' or 'No',
                inline = true,
            },
            { name = '**Original**', value = Origonal, inline = true },
            {
                name = '**New**',
                value = Properties[PropertyId].Entrance.x .. ',' .. Properties[PropertyId].Entrance.y .. ',' .. Properties[PropertyId].Entrance.z,
                inline = true,
            },
        }, 1)
    end

    cb(IsPlayerAdmin(source, 'ChangeEntrance'))
end)

registerPropertyCallback('esx_property:SetInventoryPosition', function(source, cb, PropertyId, Coords, Reset)
    if Config.OxInventory then
        local Property = Properties[PropertyId]
        local xPlayer = ESX.GetPlayerFromId(source)

        if IsPlayerAdmin(source, 'EditInteriorPositions') or (Property.Owner == xPlayer.identifier or Properties[PropertyId].Keys[xPlayer.identifier]) then
            local Interior = GetInteriorValues(Property.Interior)

            if Reset then
                Properties[PropertyId].positions.Storage = {
                    x = ESX.Math.Round(Coords.x, 2),
                    y = ESX.Math.Round(Coords.y, 2),
                    z = ESX.Math.Round(Coords.z, 2),
                }
            else
                if Interior.type == 'ipl' then
                    Properties[PropertyId].positions.Storage = {
                        x = ESX.Math.Round(Coords.x, 2),
                        y = ESX.Math.Round(Coords.y, 2),
                        z = ESX.Math.Round(Coords.z, 2),
                    }
                else
                    Properties[PropertyId].positions.Storage = vector3(Property.Entrance.x, Property.Entrance.y, 2000) - Coords
                end
            end

            Log('Property Storage Location Set', 3640511, {
                { name = '**Property Name**', value = Property.Name, inline = true },
                { name = '**Owner**', value = Property.OwnerName, inline = true },
                { name = '**Player**', value = xPlayer.getName(), inline = true },
                {
                    name = '**Has Access**',
                    value = (
                        IsPlayerAdmin(source, 'EditInteriorPositions')
                        or (Property.Owner == xPlayer.identifier or Properties[PropertyId].Keys[xPlayer.identifier])
                    )
                            and 'Yes'
                        or 'No',
                    inline = true,
                },
                { name = '**Reset?**', value = Reset and 'Yes' or 'No', inline = true },
            }, 1)
            SyncPropertiesAndSave('Property storage position changed', PropertyId)
        end

        cb(IsPlayerAdmin(source, 'EditInteriorPositions') or (Property.Owner == xPlayer.identifier or Properties[PropertyId].Keys[xPlayer.identifier]))
    else
        cb(false)
    end
end)

-- Wardrobe
registerPropertyCallback('esx_property:SetWardrobePosition', function(source, cb, PropertyId, Coords, Reset)
    local Property = Properties[PropertyId]
    local xPlayer = ESX.GetPlayerFromId(source)

    if IsPlayerAdmin(source, 'EditInteriorPositions') or (Property.Owner == xPlayer.identifier or Properties[PropertyId].Keys[xPlayer.identifier]) then
        local Interior = GetInteriorValues(Property.Interior)

        if Reset then
            Properties[PropertyId].positions.Wardrobe = Interior.positions.Wardrobe
        else
            if Interior.type == 'ipl' then
                Properties[PropertyId].positions.Wardrobe = {
                    x = ESX.Math.Round(Coords.x, 2),
                    y = ESX.Math.Round(Coords.y, 2),
                    z = ESX.Math.Round(Coords.z, 2),
                }
            else
                Properties[PropertyId].positions.Wardrobe = vector3(Property.Entrance.x, Property.Entrance.y, 1999.8) - Coords
            end

            Log('Property Wardrobe Location Set', 3640511, {
                { name = '**Property Name**', value = Property.Name, inline = true },
                { name = '**Owner**', value = Property.OwnerName, inline = true },
                { name = '**Player**', value = xPlayer.getName(), inline = true },
                {
                    name = '**Has Access**',
                    value = (
                        IsPlayerAdmin(source, 'EditInteriorPositions')
                        or (Property.Owner == xPlayer.identifier or Properties[PropertyId].Keys[xPlayer.identifier])
                    )
                            and 'Yes'
                        or 'No',
                    inline = true,
                },
                { name = '**Reset?**', value = Reset and 'Yes' or 'No', inline = true },
            }, 1)
        end

        SyncPropertiesAndSave('Property wardrobe position changed', PropertyId)
    end

    cb(IsPlayerAdmin(source, 'EditInteriorPositions') or (Property.Owner == xPlayer.identifier or Properties[PropertyId].Keys[xPlayer.identifier]))
end)

registerPropertyCallback('esx_property:getPlayerDressing', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)

    TriggerEvent('esx_datastore:getDataStore', 'property', xPlayer.identifier, function(store)
        local count = store.count('dressing')
        local labels = {}

        for i = 1, count, 1 do
            local entry = store.get('dressing', i)

            table.insert(labels, entry.label)
        end

        cb(labels)
    end)
end)

registerPropertyCallback('esx_property:GetInsidePlayers', function(source, cb, property)
    property = normalizePropertyId(property)

    local Property = property and Properties[property]
    local Players = {}
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer or not Property then
        return cb(Players)
    end

    local NearbyPlayers = Property.plysinside or {}

    for k, v in pairs(NearbyPlayers) do
        local xPlayer = ESX.GetPlayerFromId(v)

        if xPlayer then
            if not Properties[property].Keys then
                Properties[property].Keys = {}
            end

            if xPlayer.identifier ~= Property.Owner and not Properties[property].Keys[xPlayer.identifier] then
                Players[#Players + 1] = { Name = xPlayer.getName(), Id = xPlayer.source }
            end
        end
    end

    cb(Players)
end)

registerPropertyCallback('esx_property:GetNearbyPlayers', function(source, cb, property)
    property = normalizePropertyId(property)

    local Property = property and Properties[property]
    local Players = {}
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer or not Property or not IsPlayerAdmin(source, 'SellProperty') or not isNearCoords(source, Property.Entrance, PropertyActionDistance) then
        return cb(Players)
    end

    local NearbyPlayers = ESX.OneSync.GetPlayersInArea(vector3(Property.Entrance.x, Property.Entrance.y, Property.Entrance.z), 5.0) or {}

    Wait(100)

    for k, v in pairs(NearbyPlayers) do
        local xTarget = ESX.GetPlayerFromId(v.id)

        if xTarget and xPlayer.identifier ~= xTarget.identifier and isNearCoords(xTarget.source, Property.Entrance, PropertyActionDistance) then
            Players[#Players + 1] = { name = xTarget.getName(), source = xTarget.source }
        end
    end

    cb(Players)
end)

registerPropertyCallback('esx_property:GetPlayersWithKeys', function(source, cb, property)
    property = normalizePropertyId(property)

    local Property = property and Properties[property]
    local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer and Property and xPlayer.identifier == Property.Owner then
        return cb(Property.Keys or {})
    end

    cb({})
end)

registerPropertyCallback('esx_property:ShouldHaveKey', function(source, cb, property)
    local xPlayer = ESX.GetPlayerFromId(source)

    property = normalizePropertyId(property)

    local Property = property and Properties[property]

    cb(xPlayer and Property and Property.Keys and Property.Keys[xPlayer.identifier])
end)

registerPropertyCallback('esx_property:GetWebhook', function(source, cb, property)
    cb(false)
end)

registerPropertyCallback('esx_property:RemoveLastProperty', function(source, cb, property)
    local xPlayer = ESX.GetPlayerFromId(source)

    MySQL.query('UPDATE `users` SET `last_property` = NULL WHERE `identifier` = ?', { xPlayer.identifier }) -- Remove Saved Data
    SetPlayerRoutingBucket(source, 0) -- Reset Routing Bucket
    xPlayer.set('lastProperty', nil)
    cb()
end)

registerPropertyCallback('esx_property:GiveKey', function(source, cb, property, player)
    local xPlayer = ESX.GetPlayerFromId(source)

    property = normalizePropertyId(property)
    player = tonumber(player)

    if not player or player ~= math.floor(player) then
        return cb(false)
    end

    local xTarget = ESX.GetPlayerFromId(player)
    local Property = property and Properties[property]

    if not xPlayer or not xTarget or not Property then
        return cb(false)
    end

    if Property.Owner == xPlayer.identifier and isPlayerInsideProperty(xTarget.source, Property) then
        if not Property.Keys then
            Properties[property].Keys = {}
        end

        local id = xTarget.identifier

        if not Properties[property].Keys[id] then
            Property.Keys[id] = { name = xTarget.getName(), identifier = id }
            xTarget.showNotification(TranslateCap('you_granted', Property.Name), 'success')
            xTarget.triggerEvent('esx_property:giveKeyAccess', property)
            SyncPropertiesAndSave('Property key given', property)
            cb(true)
        else
            xPlayer.showNotification(TranslateCap('already_has'), 'error')
            cb(false)
        end
    else
        xPlayer.showNotification(TranslateCap('do_not_own'), 'error')
        cb(false)
    end

    Log('Property Key Given', 3640511, {
        { name = '**Property Name**', value = Property.Name, inline = true },
        { name = '**Owner**', value = Property.OwnerName, inline = true },
        { name = '**Player**', value = xPlayer.getName(), inline = true },
        {
            name = '**Has Access**',
            value = Property.Owner == xPlayer.identifier and 'Yes' or 'No',
            inline = true,
        },
    }, 1)
end)

registerPropertyCallback('esx_property:StoreVehicle', function(source, cb, PropertyId, VehicleProperties)
    local xPlayer = ESX.GetPlayerFromId(source)

    PropertyId = normalizePropertyId(PropertyId)

    local Property = Properties[PropertyId]

    if not xPlayer or not Property or type(VehicleProperties) ~= 'table' then
        return cb(false)
    end

    VehicleProperties.plate = normalizePlate(VehicleProperties.plate)

    if not VehicleProperties.plate or not VehicleProperties.model or not getPlayerVehicleForProps(source, VehicleProperties) then
        return cb(false)
    end

    if not hasPropertyAccess(xPlayer, Property) then
        xPlayer.showNotification(TranslateCap('cannot_access_property'), 'error')
        return cb(false)
    end

    if not Property.garage or not Property.garage.enabled or not isNearPropertyGarage(source, Property) then
        xPlayer.showNotification(TranslateCap('garage_not_enabled'), 'error')
        return cb(false)
    end

    VehicleProperties = copyVehiclePayload(VehicleProperties)
    if not VehicleProperties or type(VehicleProperties.DisplayName) ~= 'string' or #VehicleProperties.DisplayName > 128
        or #(Property.garage.StoredVehicles or {}) >= (Config.MaxVehiclesPerProperty or 100) then
        return cb(false)
    end

    if PropertyLocks[PropertyId] or pendingVehicleStores[VehicleProperties.plate] or isVehicleAlreadyStored(Property, VehicleProperties.plate) then
        return cb(false)
    end

    local reservation = { player = source, cancelled = false }
    pendingVehicleStores[VehicleProperties.plate] = reservation
    PropertyLocks[PropertyId] = reservation

    local function done(success)
        if pendingVehicleStores[VehicleProperties.plate] == reservation then pendingVehicleStores[VehicleProperties.plate] = nil end
        if PropertyLocks[PropertyId] == reservation then PropertyLocks[PropertyId] = nil end

        cb(success)
    end
    SetTimeout(30000, function()
        if pendingVehicleStores[VehicleProperties.plate] == reservation and not reservation.committing then
            reservation.cancelled = true
            done(false)
        end
    end)

    local function finishStore(owner)
        Properties[PropertyId].garage.StoredVehicles = Properties[PropertyId].garage.StoredVehicles or {}
        Properties[PropertyId].garage.StoredVehicles[#Properties[PropertyId].garage.StoredVehicles + 1] = {
            owner = owner,
            vehicle = VehicleProperties,
        }

        SyncPropertiesAndSave('Property vehicle stored', PropertyId)
        Log('User Attempted To Store Vehicle', 3640511, {
            { name = '**Property Name**', value = Property.Name, inline = true },
            { name = '**Owner**', value = Property.OwnerName, inline = true },
            { name = '**Player**', value = xPlayer.getName(), inline = true },
            {
                name = '**Has Access**',
                value = hasPropertyAccess(xPlayer, Property) and 'Yes' or 'No',
                inline = true,
            },
            {
                name = '**Garage Status**',
                value = Property.garage.enabled and 'Enabled' or 'Disabled',
                inline = true,
            },
            {
                name = '**Vehicle Name**',
                value = VehicleProperties.DisplayName,
                inline = true,
            },
        }, 2)
    end

    if Config.Garage.OwnedVehiclesOnly then
        MySQL.single('SELECT `owner`, `vehicle` FROM `owned_vehicles` WHERE `plate` = ?', { VehicleProperties.plate }, function(result)
            local current = ESX.GetPlayerFromId(source)

            if reservation.cancelled or not propertySchemaReady or not lastSaveSucceeded
                or Properties[PropertyId] ~= Property or not current or current.identifier ~= xPlayer.identifier
                or not hasPropertyAccess(current, Property) or not isNearPropertyGarage(source, Property)
                or not getPlayerVehicleForProps(source, VehicleProperties) then return done(false) end

            if not result or not (result.owner == xPlayer.identifier or result.owner == Property.Owner or (Property.Keys and Property.Keys[result.owner])) then
                return done(false)
            end

            local decoded, storedVehicle = pcall(json.decode, result.vehicle)
            if not decoded or type(storedVehicle) ~= 'table' then return done(false) end

            if storedVehicle and tonumber(storedVehicle.model) and tonumber(storedVehicle.model) ~= tonumber(VehicleProperties.model) then
                return done(false)
            end

            reservation.committing = true
            MySQL.update(
                'UPDATE `owned_vehicles` SET `stored` = ? WHERE `plate` = ? AND `owner` = ? AND `stored` = 0',
                { 1, VehicleProperties.plate, result.owner },
                function(rowsChanged)
                    if rowsChanged and rowsChanged > 0 then
                        finishStore(result.owner)
                        return done(true)
                    end

                    done(false)
                end
            )
        end)
    else
        finishStore(xPlayer.identifier)
        MySQL.query(Config.Garage.MySQLquery, { 1, VehicleProperties.plate })
        done(true)
    end
end)

registerPropertyCallback('esx_property:AccessGarage', function(source, cb, PropertyId, VehicleProperties)
    local xPlayer = ESX.GetPlayerFromId(source)

    PropertyId = normalizePropertyId(PropertyId)

    local Property = Properties[PropertyId]

    if not xPlayer or not Property then
        return cb(false)
    end

    if hasPropertyAccess(xPlayer, Property) then
        if Property.garage and Property.garage.enabled and isNearPropertyGarage(source, Property) then
            cb(Property.garage.StoredVehicles)
        else
            xPlayer.showNotification(TranslateCap('garage_not_enabled'), 'error')
            cb(false)
        end
    else
        xPlayer.showNotification(TranslateCap('cannot_access_property'), 'error')
        cb(false)
    end

    Log('User Opened Garage Menu', 3640511, {
        { name = '**Property Name**', value = Property.Name, inline = true },
        { name = '**Owner**', value = Property.OwnerName, inline = true },
        { name = '**Player**', value = xPlayer.getName(), inline = true },
        {
            name = '**Garage Status**',
            value = Property.garage.enabled and 'Enabled' or 'Disabled',
            inline = true,
        },
    }, 2)
end)

registerPropertyCallback('esx_property:RemoveKey', function(source, cb, property, player)
    local xPlayer = ESX.GetPlayerFromId(source)

    property = normalizePropertyId(property)

    local xTarget = ESX.GetPlayerFromIdentifier(player)
    local Property = property and Properties[property]

    if not xPlayer or not Property or type(player) ~= 'string' then
        return cb(false)
    end

    if Property.Owner == xPlayer.identifier then
        if Property.Keys then
            if Properties[property].Keys[player] then
                Log('Property Key Revoked', 3640511, {
                    { name = '**Property Name**', value = Property.Name, inline = true },
                    { name = '**Owner**', value = xPlayer.getName(), inline = true },
                    {
                        name = '**Removed From**',
                        value = tostring(Properties[property].Keys[player].name),
                        inline = true,
                    },
                }, 3)
                Properties[property].Keys[player] = nil

                if xTarget then
                    xTarget.showNotification(TranslateCap('key_revoked', Property.Name), 'error')
                    xTarget.triggerEvent('esx_property:RemoveKey', property)
                end

                SyncPropertiesAndSave('Property key removed', property)
                cb(true)
            else
                xPlayer.showNotification(TranslateCap('no_keys'), 'error')
                cb(false)
            end
        else
            cb(false)
        end
    else
        xPlayer.showNotification(TranslateCap('do_not_own'), 'error')
        cb(false)
    end
end)

registerPropertyCallback('esx_property:CanOpenFurniture', function(source, cb, property)
    local xPlayer = ESX.GetPlayerFromId(source)

    property = normalizePropertyId(property)

    local Property = property and Properties[property]

    cb(xPlayer and Property and (Property.Owner == xPlayer.identifier or (Property.Keys and Property.Keys[xPlayer.identifier])) or false)
end)

registerPropertyCallback('esx_property:getPlayerOutfit', function(source, cb, num)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer or type(num) ~= 'number' or num ~= num or num % 1 ~= 0 or num < 1 or num > 100 then
        return cb(false)
    end

    TriggerEvent('esx_datastore:getDataStore', 'property', xPlayer.identifier, function(store)
        local outfit = store and store.get('dressing', num)

        if ESX.GetPlayerFromId(source) ~= xPlayer or type(outfit) ~= 'table' or type(outfit.skin) ~= 'table' then
            return cb(false)
        end

        exports.esx_skin:SaveOutfit(source, outfit.skin, function(saved, appliedSkin)
            cb(saved and appliedSkin or false)
        end)
    end)
end)

-- Player Management
if PM.Enabled then
    registerPropertyCallback('esx_property:PMenterOffice', function(source, cb)
        local xPlayer = ESX.GetPlayerFromId(source)
        local PlayerPed = GetPlayerPed(source)

        if xPlayer.job.name == PM.job then
            SetEntityCoords(PlayerPed, PM.Locations.Exit)
            SetPlayerRoutingBucket(source, 1)
            cb(true)
        else
            cb(false)
        end
    end)

    registerPropertyCallback('esx_property:PMexitOffice', function(source, cb)
        local xPlayer = ESX.GetPlayerFromId(source)
        local PlayerPed = GetPlayerPed(source)

        if xPlayer.job.name == PM.job then
            SetEntityCoords(PlayerPed, PM.Locations.Entrance)
            SetPlayerRoutingBucket(source, 0)
            cb(true)
        else
            cb(false)
        end
    end)
end

-- Enter/leave Events

RegisterNetEvent('esx_property:enter', function(PropertyId)
    if not propertySchemaReady or not lastSaveSucceeded or not propertyActionLimiter:consume(source) then
        return
    end

    local player = source
    local PlayerPed = GetPlayerPed(player)
    local xPlayer = ESX.GetPlayerFromId(player)

    PropertyId = normalizePropertyId(PropertyId)

    local Property = Properties[PropertyId]

    if not xPlayer or not Property or not canEnterProperty(xPlayer, Property) then
        return
    end
    
    if isPlayerInsideProperty(player, Property) then return end

    if not isRestoringLastProperty(xPlayer, PropertyId) and not isNearCoords(player, Property.Entrance, 6.0) then
        return
    end

    local Interior = GetInteriorValues(Property.Interior)

    if not Properties[PropertyId].plysinside then
        Properties[PropertyId].plysinside = {}
    end

    if not isPlayerInsideProperty(player, Property) then
        table.insert(Properties[PropertyId].plysinside, player)
    end

    TriggerClientEvent('esx_property:loadFurniture', player, PropertyId, Property.furniture or {})

    local PropertyData = { id = PropertyId, coords = Property.Entrance }

    MySQL.query('UPDATE `users` SET `last_property` = ? WHERE `identifier` = ?', { json.encode(PropertyData), xPlayer.identifier })
    xPlayer.set('lastProperty', PropertyData)

    if Interior.type == 'shell' then
        SetEntityCoords(PlayerPed, vector3(Property.Entrance.x, Property.Entrance.y, 2001))
    else
        SetEntityCoords(PlayerPed, Interior.pos)
        SetEntityHeading(PlayerPed, 0.0)
    end

    SetPlayerRoutingBucket(player, PropertyId + 1)
    Log('Player Entered Property', 3640511, {
        { name = '**Property Name**', value = Properties[PropertyId].Name, inline = true },
        { name = '**Player**', value = xPlayer.getName(), inline = true },
        {
            name = '**Property Player Count**',
            value = tostring(#Properties[PropertyId].plysinside),
            inline = true,
        },
    }, 3)
end)

RegisterNetEvent('esx_property:leave', function(PropertyId)
    if not propertySchemaReady then
        return
    end

    local player = source

    PropertyId = normalizePropertyId(PropertyId)

    local Property = Properties[PropertyId]
    local xPlayer = ESX.GetPlayerFromId(player)

    if not xPlayer or not Property or not isPlayerInsideProperty(player, Property) then
        return
    end

    MySQL.query('UPDATE `users` SET `last_property` = NULL WHERE `identifier` = ?', { xPlayer.identifier }) -- Remove Saved Data
    xPlayer.set('lastProperty', nil)

    local PlayerPed = GetPlayerPed(player)

    SetEntityCoords(PlayerPed, vector3(Property.Entrance.x, Property.Entrance.y, Property.Entrance.z))
    SetEntityHeading(PlayerPed, 0.0)
    SetPlayerRoutingBucket(player, 0)

    if not hasPropertyAccess(xPlayer, Property) then
        TriggerClientEvent('esx_property:syncFurniture', player, PropertyId, {})
    end

    for i = 1, #Properties[PropertyId].plysinside do
        if Properties[PropertyId].plysinside[i] == player then
            table.remove(Properties[PropertyId].plysinside, i)
            break
        end
    end

    Log('Player Left Property', 3640511, {
        { name = '**Property Name**', value = Properties[PropertyId].Name, inline = true },
        { name = '**Player**', value = xPlayer.getName(), inline = true },
        {
            name = '**Property Player Count**',
            value = tostring(#Properties[PropertyId].plysinside),
            inline = true,
        },
    }, 3)
end)

RegisterNetEvent('esx_property:SetVehicleOut', function(PropertyId, VehIndex)
    if not propertySchemaReady or not lastSaveSucceeded or not propertyActionLimiter:consume(source) then return end
    local player = source
    local xPlayer = ESX.GetPlayerFromId(player)

    PropertyId = normalizePropertyId(PropertyId)
    VehIndex = tonumber(VehIndex)

    if not xPlayer or not PropertyId or not VehIndex or VehIndex ~= math.floor(VehIndex) then
        return
    end

    local Property = Properties[PropertyId]

    if PropertyLocks[PropertyId] then return end
    if not hasPropertyAccess(xPlayer, Property) or not Property.garage or not Property.garage.enabled or not isNearPropertyGarage(player, Property) then
        return
    end

    if not Property.garage.StoredVehicles then
        return
    end

    local VehicleData = Property.garage.StoredVehicles[VehIndex]

    if not VehicleData or type(VehicleData.vehicle) ~= 'table' then
        return
    end

    local plate = normalizePlate(VehicleData.vehicle.plate)

    if not plate then
        return
    end

    table.remove(Properties[PropertyId].garage.StoredVehicles, VehIndex)
    SyncPropertiesAndSave('Property vehicle checked out', PropertyId)

    if VehicleData.owner then
        MySQL.update('UPDATE `owned_vehicles` SET `stored` = ? WHERE `plate` = ? AND `owner` = ?', { 0, plate, VehicleData.owner })
    else
        MySQL.query(Config.Garage.MySQLquery, { 0, plate }) -- Set vehicle as no longer stored
    end
end)

AddEventHandler('playerDropped', function()
    local source = source
    propertyActionLimiter:reset(source)
    for _, reservation in pairs(pendingVehicleStores) do
        if reservation.player == source and not reservation.committing then reservation.cancelled = true end
    end

    for token, offer in pairs(PendingPropertySales) do
        if offer.seller == source or offer.target == source then
            PendingPropertySales[token] = nil

            if PropertyLocks[offer.propertyId] == token then
                PropertyLocks[offer.propertyId] = nil
            end
        end
    end

    for PropertyId = 1, #Properties do
        for i = 1, #Properties[PropertyId].plysinside do
            if Properties[PropertyId].plysinside[i] == source then
                table.remove(Properties[PropertyId].plysinside, i)
                break
            end
        end
    end
end)

registerPropertyCallback('esx_property:CanCreateProperty', function(source, cb)
    local Re = false
    local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer then
        if IsPlayerAdmin(source, 'CreateProperty') then
            Re = true
        end
    end

    cb(Re)
end)

registerPropertyCallback('esx_property:IsAdmin', function(source, cb)
    cb(IsPlayerAdmin(source, 'ViewProperties'))
end)

registerPropertyCallback('esx_property:CanAccessRealEstateMenu', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer or not xPlayer.job then
        return cb(false)
    end

    local Re = (
        Config.PlayerManagement.Enabled
        and xPlayer.job.name == Config.PlayerManagement.job
        and xPlayer.job.grade >= Config.PlayerManagement.Permissions.ManagePropertiesFromQuickActions
    )
            and true
        or false

    cb(Re)
end)

RegisterNetEvent('esx_property:server:createProperty', function(Property)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)

    if
        not propertySchemaReady
        or not lastSaveSucceeded
        or not xPlayer
        or not IsPlayerAdmin(source, 'CreateProperty')
        or not propertyActionLimiter:consume(source)
        or type(Property) ~= 'table'
        or type(Property.garage) ~= 'table'
        or type(Property.cctv) ~= 'table'
        or type(Property.entrance) ~= 'table'
    then
        return
    end

    if type(Property.interior) ~= 'string' then return end
    local Interior = GetInteriorValues(Property.interior)
    local Price = tonumber(Property.price)

    if
        not Interior
        or not finite(Price, 2147483647)
        or Price <= 0 or Price % 1 ~= 0
        or type(Property.name) ~= 'string'
        or Property.name == ''
        or #Property.name > Config.MaxNameLength
        or Property.name:find('[%c]')
        or type(Property.garage.enabled) ~= 'boolean'
        or type(Property.cctv.enabled) ~= 'boolean'
        or not validCoords(Property.entrance)
    then
        return
    end

    if
        Property.garage.enabled
        and (not validCoords(Property.garage.pos) or not finite(Property.garage.heading, 360))
    then
        return
    end

    local garageData = Property.garage.enabled
            and {
                enabled = true,
                pos = { x = Property.garage.pos.x, y = Property.garage.pos.y, z = Property.garage.pos.z },
                Heading = Property.garage.heading,
                StoredVehicles = {},
            }
        or { enabled = false }

    local ActualProperty = {
        Name = Property.name,
        setName = '',
        Price = Price,
        furniture = {},
        plysinside = {},
        Interior = Property.interior,
        Entrance = { x = Property.entrance.x, y = Property.entrance.y, z = Property.entrance.z },
        Owner = '',
        Keys = {},
        positions = json.decode(json.encode(Interior.positions)),
        cctv = { enabled = Property.cctv.enabled },
        garage = garageData,
        Owned = false,
        Locked = false,
    }

    Properties[#Properties + 1] = ActualProperty

    Log('Property Created', 65280, {
        { name = '**Admin**', value = xPlayer.getName(), inline = true },
        { name = '**Name**', value = Property.name, inline = true },
        { name = '**Price**', value = ESX.Math.GroupDigits(Price), inline = true },
        { name = '**Interior**', value = Interior.label, inline = true },
        {
            name = '**Garage Status**',
            value = Property.garage.enabled and 'Enabled' or 'Disabled',
            inline = true,
        },
        {
            name = '**CCTV Status**',
            value = Property.cctv.enabled and 'Enabled' or 'Disabled',
            inline = true,
        },
        {
            name = '**Entrance**',
            value = tostring(Property.entrance.x .. ', ' .. Property.entrance.y .. ', ' .. Property.entrance.z),
            inline = true,
        },
    }, 1)

    SyncPropertiesAndSave('Property created', #Properties)
end)

-- SQL persistence

--- Save Properties On Server Scheduled Restart
AddEventHandler('txAdmin:events:scheduledRestart', function(eventData)
    if eventData.secondsRemaining == 60 then
        CreateThread(function()
            Wait(50000)
            PropertySave('Scheduled Server Restart')
        end)
    end
end)

function PropertySave(Reason)
    return SavePropertiesToSQL(Reason)
end

--- Save Properties On Server Stop/Restart
AddEventHandler('txAdmin:events:serverShuttingDown', function()
    PropertySave(TranslateCap('server_shutdown'))
end)

--- Save Properties On Resource Stop/Restart

AddEventHandler('onResourceStop', function(ResourceName)
    if ResourceName == GetCurrentResourceName() then
        propertyStopping = true
        PropertySave(TranslateCap('resource_stop'))
    end
end)

AddEventHandler('onServerResourceStop', function(ResourceName)
    if ResourceName == GetCurrentResourceName() then
        propertyStopping = true
        PropertySave(TranslateCap('resource_stop'))
    end
end)

CreateThread(function()
    while true do
        Wait(60000 * Config.SaveInterval)
        PropertySave(TranslateCap('interval_saving'))
    end
end)

ESX.RegisterCommand(_('save_name'), Config.AllowedGroups, function(xPlayer)
    PropertySave(TranslateCap('manual_save', GetPlayerName(xPlayer.source)))
end, false, { help = TranslateCap('save_desc') })

----- Exports -----

exports('GetProperties', function()
    return Properties
end)

exports('GetOwnedProperties', function()
    local OwnedProperties = {}

    for i = 1, #Properties do
        if Properties[i].Owned then
            OwnedProperties[#OwnedProperties + 1] = Properties[i]
        end
    end

    return OwnedProperties
end)

exports('GetNonOwnedProperties', function()
    local NonOwnedProperties = {}

    for i = 1, #Properties do
        if not Properties[i].Owned then
            NonOwnedProperties[#NonOwnedProperties + 1] = Properties[i]
        end
    end

    return NonOwnedProperties
end)

exports('GetPlayerProperties', function(identifier)
    local PlayerProperties = {}

    for i = 1, #Properties do
        if Properties[i].Owned and Properties[i].Owner == identifier then
            PlayerProperties[#PlayerProperties + 1] = Properties[i]
        end
    end

    return PlayerProperties
end)

exports('GetPropertyKeys', function(PropertyId)
    local Property = Properties[PropertyId]

    if Property.Keys then
        return Property.Keys
    end

    return {}
end)

exports('DoesPlayerHaveKeys', function(PropertyId, Identifier)
    local Property = Properties[PropertyId]

    if Property.Keys then
        return Property.Keys[Identifier] and true or false
    end

    return {}
end)

exports('ForceSaveProperties', function()
    local ExecutingResource = GetInvokingResource()

    PropertySave(TranslateCap('forced_save', ExecutingResource))
end)
