-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

ESXCatalog.awaitReady()

local DataStores = {}
local DataStoresIndex = {}
local DataStoresByOwner = {}
local noOwner = {}
local SharedDataStores = {}
local catalogsReady = false
local catalogRefreshPending = false
local catalogRefreshing = false
local refreshCatalogs

local function storedData(value)
    if value == nil or value == "'{}'" then
        return {}
    end

    return json.decode(value)
end

local function addDataStore(name, owner, data)
    local store = CreateDataStore(name, owner, data)
    local owners = DataStoresByOwner[name]

    if not owners then
        owners = {}
        DataStoresByOwner[name] = owners
    end

    local key = owner == nil and noOwner or owner

    if not owners[key] then
        owners[key] = store
    end

    DataStores[name][#DataStores[name] + 1] = store

    return store
end

MySQL.ready(function()
    do
        local dataStore = MySQL.query.await(
            'SELECT * FROM datastore_data LEFT JOIN datastore ON datastore_data.name = datastore.name UNION SELECT * FROM datastore_data RIGHT JOIN datastore ON datastore_data.name = datastore.name'
        )

        local newData = {}
        for i = 1, #dataStore do
            local data = dataStore[i]
            if data.shared == 0 then
                if not DataStores[data.name] then
                    DataStoresIndex[#DataStoresIndex + 1] = data.name
                    DataStores[data.name] = {}
                end
                addDataStore(data.name, data.owner, storedData(data.data))
            else
                if data.data then
                    SharedDataStores[data.name] =
                        CreateDataStore(data.name, nil, storedData(data.data))
                else
                    newData[#newData + 1] = { data.name, '{}' }
                end
            end
        end

        if next(newData) then
            MySQL.prepare('INSERT INTO datastore_data (name, data) VALUES (?, ?)', newData)
            for i = 1, #newData do
                local new = newData[i]
                SharedDataStores[new[1]] = CreateDataStore(new[1], nil, {})
            end
        end
    end
    catalogsReady = true

    if catalogRefreshPending then
        refreshCatalogs()
    end
end)

function GetDataStore(name, owner)
    local owners = DataStoresByOwner[name]

    if owners then
        return owners[owner == nil and noOwner or owner]
    end
end

function GetDataStoreOwners(name)
    local identifiers = {}

    for i = 1, #(DataStores[name] or {}), 1 do
        table.insert(identifiers, DataStores[name][i].owner)
    end

    return identifiers
end

function GetSharedDataStore(name)
    return SharedDataStores[name]
end

AddEventHandler('esx_datastore:getDataStore', function(name, owner, cb)
    cb(GetDataStore(name, owner))
end)

AddEventHandler('esx_datastore:getDataStoreOwners', function(name, cb)
    cb(GetDataStoreOwners(name))
end)

AddEventHandler('esx_datastore:getSharedDataStore', function(name, cb)
    cb(GetSharedDataStore(name))
end)

AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    for i = 1, #DataStoresIndex, 1 do
        local name = DataStoresIndex[i]
        local dataStore = GetDataStore(name, xPlayer.identifier)

        if not dataStore then
            MySQL.insert(
                'INSERT INTO datastore_data (name, owner, data) VALUES (?, ?, ?)',
                { name, xPlayer.identifier, '{}' }
            )

            addDataStore(name, xPlayer.identifier, {})
        end
    end
end)

refreshCatalogs = function()
    catalogRefreshPending = true

    if not catalogsReady or catalogRefreshing then
        return
    end

    catalogRefreshing = true

    local ok, err = pcall(function()
        repeat
            catalogRefreshPending = false

            local definitions = MySQL.query.await('SELECT name, shared FROM datastore')

            for _, definition in ipairs(definitions) do
                local name = definition.name

                if definition.shared == 1 then
                    if not SharedDataStores[name] then
                        local row = MySQL.single.await(
                            'SELECT data FROM datastore_data WHERE name = ? AND owner IS NULL LIMIT 1',
                            { name }
                        )

                        if not row then
                            MySQL.insert.await(
                                "INSERT INTO datastore_data (name, owner, data) SELECT ?, NULL, '{}' FROM (SELECT COUNT(*) AS matches FROM datastore_data WHERE name = ? AND owner IS NULL) AS existing WHERE existing.matches = 0",
                                { name, name }
                            )
                        end

                        SharedDataStores[name] =
                            CreateDataStore(name, nil, row and storedData(row.data) or {})
                    end
                else
                    if not DataStores[name] then
                        DataStores[name] = {}
                        DataStoresIndex[#DataStoresIndex + 1] = name

                        local rows = MySQL.query.await(
                            'SELECT owner, data FROM datastore_data WHERE name = ? AND owner IS NOT NULL',
                            { name }
                        )

                        for _, row in ipairs(rows) do
                            addDataStore(name, row.owner, storedData(row.data))
                        end
                    end

                    for _, player in pairs(ESX.GetExtendedPlayers()) do
                        if not GetDataStore(name, player.identifier) then
                            MySQL.insert.await(
                                "INSERT INTO datastore_data (name, owner, data) SELECT ?, ?, '{}' FROM (SELECT COUNT(*) AS matches FROM datastore_data WHERE name = ? AND owner = ?) AS existing WHERE existing.matches = 0",
                                {
                                    name,
                                    player.identifier,
                                    name,
                                    player.identifier,
                                }
                            )

                            addDataStore(name, player.identifier, {})
                        end
                    end
                end
            end
        until not catalogRefreshPending
    end)

    catalogRefreshing = false

    if not ok then
        print(('[esx_datastore] Catalog refresh failed: %s'):format(tostring(err)))
    end
end

AddEventHandler('esx:sqlCatalogReady', function(tables)
    if tables.datastore then
        refreshCatalogs()
    end
end)
