-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

ESXCatalog.awaitReady()

if ESX.GetConfig().OxInventory then
    AddEventHandler('onServerResourceStart', function(resourceName)
        if resourceName == 'ox_inventory' or resourceName == GetCurrentResourceName() then
            local stashes = MySQL.query.await('SELECT * FROM addon_inventory')

            for i = 1, #stashes do
                local stash = stashes[i]
                local jobStash = stash.name:find('society') and string.sub(stash.name, 9)
                exports.ox_inventory:RegisterStash(
                    stash.name,
                    stash.label,
                    100,
                    200000,
                    stash.shared == 0 and true or false,
                    jobStash
                )
            end
        end
    end)

    AddEventHandler('esx:sqlCatalogReady', function(tables)
        if not tables.addon_inventory then
            return
        end

        local stashes = MySQL.query.await('SELECT * FROM addon_inventory')

        for _, stash in ipairs(stashes) do
            local job = stash.name:find('society') and string.sub(stash.name, 9)
            exports.ox_inventory:RegisterStash(
                stash.name,
                stash.label,
                100,
                200000,
                stash.shared == 0 and true or false,
                job
            )
        end
    end)
    return
end

Items = {}
local InventoriesIndex = {}
local Inventories = {}
local InventoriesByOwner = {}
local noOwner = {}
local SharedInventories = {}
local catalogsReady = false
local catalogRefreshPending = false
local catalogRefreshing = false
local refreshCatalogs

local function addInventory(name, owner, items)
    local inventory = CreateAddonInventory(name, owner, items)
    local owners = InventoriesByOwner[name]

    if not owners then
        owners = {}
        InventoriesByOwner[name] = owners
    end

    local key = owner == nil and noOwner or owner

    if not owners[key] then
        owners[key] = inventory
    end

    Inventories[name][#Inventories[name] + 1] = inventory

    return inventory
end

MySQL.ready(function()
    local items = MySQL.query.await('SELECT * FROM items')

    for i = 1, #items, 1 do
        Items[items[i].name] = items[i].label
    end

    local result = MySQL.query.await('SELECT * FROM addon_inventory')

    for i = 1, #result, 1 do
        local name = result[i].name
        local label = result[i].label
        local shared = result[i].shared

        local result2 = MySQL.query.await(
            'SELECT * FROM addon_inventory_items WHERE inventory_name = @inventory_name',
            {
                ['@inventory_name'] = name,
            }
        )

        if shared == 0 then

            table.insert(InventoriesIndex, name)

            Inventories[name] = {}
            local items = {}

            for j = 1, #result2, 1 do
                local itemName = result2[j].name
                local itemCount = result2[j].count
                local itemOwner = result2[j].owner

                if items[itemOwner] == nil then
                    items[itemOwner] = {}
                end

                table.insert(items[itemOwner], {
                    name = itemName,
                    count = itemCount,
                    label = Items[itemName],
                })
            end

            for k, v in pairs(items) do
                addInventory(name, k, v)
            end

        else
            local items = {}

            for j = 1, #result2, 1 do
                table.insert(items, {
                    name = result2[j].name,
                    count = result2[j].count,
                    label = Items[result2[j].name],
                })
            end

            local addonInventory = CreateAddonInventory(name, nil, items)
            SharedInventories[name] = addonInventory
            GlobalState.SharedInventories = SharedInventories
        end
    end
    catalogsReady = true

    if catalogRefreshPending then
        refreshCatalogs()
    end
end)

function GetInventory(name, owner)
    local owners = InventoriesByOwner[name]

    if owners then
        return owners[owner == nil and noOwner or owner]
    end
end

function GetSharedInventory(name)
    return SharedInventories[name]
end

function AddSharedInventory(society)
    if type(society) ~= 'table' or not society?.name or not society?.label then
        return
    end
    -- society (array) containing name (string) and label (string)

    -- addon inventory:
    MySQL.Async.execute(
        'INSERT INTO addon_inventory (name, label, shared) VALUES (@name, @label, @shared)',
        {
            ['name'] = society.name,
            ['label'] = society.label,
            ['shared'] = 1,
        }
    )

    SharedInventories[society.name] = CreateAddonInventory(society.name, nil, {})
end

AddEventHandler('esx_addoninventory:getInventory', function(name, owner, cb)
    cb(GetInventory(name, owner))
end)

AddEventHandler('esx_addoninventory:getSharedInventory', function(name, cb)
    cb(GetSharedInventory(name))
end)

AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    local addonInventories = {}

    for i = 1, #InventoriesIndex, 1 do
        local name = InventoriesIndex[i]
        local inventory = GetInventory(name, xPlayer.identifier)

        if inventory == nil then
            inventory = addInventory(name, xPlayer.identifier, {})
        end

        table.insert(addonInventories, inventory)
    end

    xPlayer.set('addonInventories', addonInventories)
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

            for _, item in ipairs(MySQL.query.await('SELECT name, label FROM items')) do
                Items[item.name] = item.label
            end

            for _, definition in
                ipairs(MySQL.query.await('SELECT name, shared FROM addon_inventory'))
            do
                local name = definition.name
                local missing = definition.shared == 1 and not SharedInventories[name]
                    or definition.shared == 0 and not Inventories[name]

                if missing then
                    local rows = MySQL.query.await(
                        'SELECT name, count, owner FROM addon_inventory_items WHERE inventory_name = ?',
                        { name }
                    )

                    if definition.shared == 1 then
                        local items = {}

                        for _, row in ipairs(rows) do
                            items[#items + 1] = {
                                name = row.name,
                                count = row.count,
                                label = Items[row.name],
                            }
                        end

                        SharedInventories[name] = CreateAddonInventory(name, nil, items)
                    else
                        Inventories[name] = {}
                        InventoriesIndex[#InventoriesIndex + 1] = name
                        local owners = {}

                        for _, row in ipairs(rows) do
                            if row.owner then
                                owners[row.owner] = owners[row.owner] or {}
                                owners[row.owner][#owners[row.owner] + 1] = {
                                    name = row.name,
                                    count = row.count,
                                    label = Items[row.name],
                                }
                            end
                        end

                        for owner, items in pairs(owners) do
                            addInventory(name, owner, items)
                        end
                    end
                end
            end

            for _, player in pairs(ESX.GetExtendedPlayers()) do
                local inventories = {}

                for _, name in ipairs(InventoriesIndex) do
                    local inventory = GetInventory(name, player.identifier)

                    if not inventory then
                        inventory = addInventory(name, player.identifier, {})
                    end

                    inventories[#inventories + 1] = inventory
                end

                player.set('addonInventories', inventories)
            end

            GlobalState.SharedInventories = SharedInventories
        until not catalogRefreshPending
    end)

    catalogRefreshing = false

    if not ok then
        print(('[esx_addoninventory] Catalog refresh failed: %s'):format(tostring(err)))
    end
end

AddEventHandler('esx:sqlCatalogReady', function(tables)
    if tables.addon_inventory or tables.items then
        refreshCatalogs()
    end
end)
