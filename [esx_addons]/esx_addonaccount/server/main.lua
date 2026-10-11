-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

ESXCatalog.awaitReady()

local AccountsIndex = {}
local Accounts = {}
local SharedAccounts = {}
local loadConnectedAccounts
local accountsReady = false
local catalogRefreshPending = false
local catalogRefreshing = false
local refreshCatalogs

MySQL.ready(function()
    local ok, err = pcall(function()
        MigrateAddonAccountSchema()
        local definitions = MySQL.query.await('SELECT name, label, shared FROM addon_account')
        local sharedNames = {}

        for i = 1, #definitions do
            local account = definitions[i]

            if account.shared == 0 then
                AccountsIndex[#AccountsIndex + 1] = account.name
                Accounts[account.name] = Accounts[account.name] or {}
            else
                sharedNames[#sharedNames + 1] = account.name
            end
        end

        local sharedData = {}
        if #sharedNames > 0 then
            local placeholders = {}
            for i = 1, #sharedNames do
                placeholders[i] = '?'
            end

            local rows = MySQL.query.await(
                ('SELECT account_name, MAX(money) AS money FROM addon_account_data WHERE owner IS NULL AND account_name IN (%s) GROUP BY account_name'):format(
                    table.concat(placeholders, ',')
                ),
                sharedNames
            )

            for i = 1, #rows do
                sharedData[rows[i].account_name] = rows[i].money
            end
        end

        local newAccounts = {}
        for i = 1, #sharedNames do
            local name = sharedNames[i]
            local money = sharedData[name]

            if money then
                SharedAccounts[name] = CreateAddonAccount(name, nil, money)
            else
                newAccounts[#newAccounts + 1] = { name, 0 }
            end
        end

        GlobalState.SharedAccounts = nil

        if next(newAccounts) then
            MySQL.prepare.await(
                'INSERT IGNORE INTO addon_account_data (account_name, money) VALUES (?, ?)',
                newAccounts
            )

            for i = 1, #newAccounts do
                local newAccount = newAccounts[i]
                local money = MySQL.scalar.await(
                    'SELECT money FROM addon_account_data WHERE account_name = ? AND owner IS NULL',
                    { newAccount[1] }
                )

                if money ~= nil then
                    SharedAccounts[newAccount[1]] = CreateAddonAccount(newAccount[1], nil, money)
                end
            end
        end

    end)
    if not ok then
        print(
            ('[esx_addonaccount] Schema migration/startup failed; accounts disabled: %s'):format(
                tostring(err)
            )
        )
        return
    end
    accountsReady = true
    loadConnectedAccounts()
    print('[esx_addonaccount] Database schema ready.')
    if catalogRefreshPending then
        catalogRefreshPending = false
        refreshCatalogs()
    end
end)

function GetAccount(name, owner)
    if not accountsReady or not Accounts[name] then
        return nil
    end

    return Accounts[name][owner]
end

function GetSharedAccount(name)
    if not accountsReady then
        return nil
    end
    return SharedAccounts[name]
end

function AddSharedAccount(society, amount)
    if not accountsReady then
        return nil
    end
    -- society.name = job_name/society_name
    -- society.label = label for the job/account
    -- amount = if the shared account should start with x amount
    if type(society) ~= 'table' or not society?.name or not society?.label then
        return
    end

    -- check if account already exist?
    if SharedAccounts[society.name] ~= nil then
        return SharedAccounts[society.name]
    end

    -- addon account:
    local account =
        MySQL.insert.await('INSERT INTO `addon_account` (name, label, shared) VALUES (?, ?, ?)', {
            society.name,
            society.label,
            1,
        })
    if not account then
        return
    end

    -- if addon account inserted, insert addon account data:
    local account_data =
        MySQL.insert.await('INSERT INTO `addon_account_data` (account_name, money) VALUES (?, ?)', {
            society.name,
            (amount or 0),
        })
    if not account_data then
        return
    end

    -- if all data inserted successfully to sql:
    SharedAccounts[society.name] = CreateAddonAccount(society.name, nil, (amount or 0))

    return SharedAccounts[society.name]
end

AddEventHandler('esx_addonaccount:getAccount', function(name, owner, cb)
    cb(GetAccount(name, owner))
end)

AddEventHandler('esx_addonaccount:getSharedAccount', function(name, cb)
    cb(GetSharedAccount(name))
end)

local function loadOwnerAccounts(identifier)
    if not accountsReady then
        return {}
    end
    local addonAccounts = {}
    local existingAccounts = {}

    if #AccountsIndex > 0 then
        local placeholders = {}
        for i = 1, #AccountsIndex do
            placeholders[i] = '?'
        end

        local params = { identifier }
        for i = 1, #AccountsIndex do
            params[#params + 1] = AccountsIndex[i]
        end

        local rows = MySQL.query.await(
            ('SELECT account_name, money FROM addon_account_data WHERE owner = ? AND account_name IN (%s)'):format(
                table.concat(placeholders, ',')
            ),
            params
        )

        for i = 1, #rows do
            existingAccounts[rows[i].account_name] = rows[i].money
        end
    end

    for i = 1, #AccountsIndex, 1 do
        local name = AccountsIndex[i]
        local account = GetAccount(name, identifier)

        if account == nil then
            local money = existingAccounts[name]

            if money == nil then
                MySQL.insert.await(
                    'INSERT IGNORE INTO addon_account_data (account_name, money, owner) VALUES (?, ?, ?)',
                    { name, 0, identifier }
                )

                money = 0
            end

            account = CreateAddonAccount(name, identifier, money)
            Accounts[name][identifier] = account
        end

        addonAccounts[#addonAccounts + 1] = account
    end

    return addonAccounts
end

loadConnectedAccounts = function()
    for _, xPlayer in pairs(ESX.GetExtendedPlayers()) do
        xPlayer.set('addonAccounts', loadOwnerAccounts(xPlayer.identifier))
    end
end

AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    xPlayer.set('addonAccounts', loadOwnerAccounts(xPlayer.identifier))
end)

refreshCatalogs = function()
    catalogRefreshPending = true

    if not accountsReady or catalogRefreshing then
        return
    end

    catalogRefreshing = true

    local ok, err = pcall(function()
        repeat
            catalogRefreshPending = false

            local refreshedIndex = {}
            local addonAccounts = MySQL.query.await('SELECT name, shared FROM addon_account')

            for i = 1, #addonAccounts, 1 do
                local name = addonAccounts[i].name
                local shared = addonAccounts[i].shared

                if shared == 0 then
                    table.insert(refreshedIndex, name)
                    Accounts[name] = Accounts[name] or {}
                else
                    local money = MySQL.scalar.await(
                        'SELECT money FROM addon_account_data WHERE account_name = ? AND owner IS NULL LIMIT 1',
                        { name }
                    )

                    if money == nil then
                        MySQL.insert.await(
                            'INSERT IGNORE INTO addon_account_data (account_name, money, owner) VALUES (?, ?, ?)',
                            { name, 0, nil }
                        )

                        money = 0
                    end

                    SharedAccounts[name] = SharedAccounts[name]
                        or CreateAddonAccount(name, nil, money)
                end
            end

            AccountsIndex = refreshedIndex
            GlobalState.SharedAccounts = nil
            loadConnectedAccounts()
        until not catalogRefreshPending
    end)

    catalogRefreshing = false

    if not ok then
        print(('[esx_addonaccount] Catalog refresh failed: %s'):format(tostring(err)))
    end
end

AddEventHandler('esx_addonaccount:refreshAccounts', refreshCatalogs)

AddEventHandler('esx:playerDropped', function(playerId)
    local xPlayer = ESX.GetPlayerFromId(playerId)

    if not xPlayer then
        return
    end

    local identifier = xPlayer.identifier

    for _, accounts in pairs(Accounts) do
        local account = accounts[identifier]

        if account then
            account.save(function(success)
                if
                    success
                    and not account.isDirty()
                    and not ESX.GetPlayerFromIdentifier(identifier)
                    and accounts[identifier] == account
                then
                    accounts[identifier] = nil
                end
            end)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(60000)

        for _, accounts in pairs(Accounts) do
            for owner, account in pairs(accounts) do
                if not account.isDirty() and not ESX.GetPlayerFromIdentifier(owner) then
                    accounts[owner] = nil
                end
            end
        end
    end
end)

AddEventHandler('esx:sqlCatalogReady', function(tables)
    if tables.addon_account then
        TriggerEvent('esx_addonaccount:refreshAccounts')
    end
end)
