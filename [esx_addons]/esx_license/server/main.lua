-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

ESXCatalog.awaitReady()

local licenses = {}
local grantsReady = false
local catalogRefreshPending = false
local catalogRefreshing = false
local refreshLicenseCatalog

MySQL.ready(function()
    local ok, err = pcall(function()
        licenses = MySQL.query.await('SELECT type, label FROM licenses')
        MigrateLicenseSchema()
    end)
    grantsReady = ok

    if not grantsReady then
        print(('[esx_license] Schema migration failed; grants disabled: %s'):format(tostring(err)))
        return
    end

    if catalogRefreshPending then
        refreshLicenseCatalog()
    end
    print('[esx_license] Database schema ready.')
    ESX.Trace('[esx_license] : ' .. #licenses .. ' Loaded.')
end)

---@param identifier target identifier
---@param licenseType license type
---@param cb callback function
local function AddLicense(identifier, licenseType, cb)
    if not grantsReady then
        return cb and cb(false)
    end
    MySQL.insert(
        'INSERT INTO user_licenses (type, owner) VALUES (?, ?) ON DUPLICATE KEY UPDATE id = LAST_INSERT_ID(id)',
        { licenseType, identifier },
        function(rowsChanged)
            if cb then
                cb(rowsChanged)
            end
        end
    )
end

---@param identifier target identifier
---@param licenseType license type
---@param cb callback function
local function RemoveLicense(identifier, licenseType, cb)
    MySQL.update(
        'DELETE FROM user_licenses WHERE type = ? AND owner = ?',
        { licenseType, identifier },
        function(rowsChanged)
            if cb then
                cb(rowsChanged)
            end
        end
    )
end

---@param licenseType license type
---@param cb callback function
local function GetLicense(licenseType, cb)
    MySQL.scalar('SELECT label FROM licenses WHERE type = ?', { licenseType }, function(result)
        if cb then
            cb({ type = licenseType, label = result })
        end
    end)
end

---@param identifier target identifier
---@param cb callback function
local function GetLicenses(identifier, cb)
    MySQL.query(
        'SELECT user_licenses.type, licenses.label FROM user_licenses LEFT JOIN licenses ON user_licenses.type = licenses.type WHERE owner = ?',
        { identifier },
        function(result)
            if cb then
                cb(result)
            end
        end
    )
end

---@param identifier target identifier
---@param licenseType license type
---@param cb callback function
local function CheckLicense(identifier, licenseType, cb)
    MySQL.scalar(
        'SELECT type FROM user_licenses WHERE type = ? AND owner = ?',
        { licenseType, identifier },
        function(result)
            if cb then
                if result then
                    cb(true)
                else
                    cb(false)
                end
            end
        end
    )
end

local function GetLicensesList(cb)
    cb(licenses)
end

local function isValidLicense(licenseType)
    local flag = false
    for i = 1, #licenses do
        if licenses[i].type == licenseType then
            flag = true
            break
        end
    end
    return flag
end

local function isAdmin(xPlayer)
    if not xPlayer or type(xPlayer.getGroup) ~= 'function' then
        return false
    end

    local group = xPlayer.getGroup()
    return group == 'admin' or group == 'superadmin'
end

local function isNearPlayer(source, target, distance)
    local nearby =
        xLib.player.isNearPlayer(source, target, distance or Config.LicenseCheckDistance or 5.0)
    return nearby
end

local function canReadTargetLicenses(source, target)
    source = tonumber(source)
    target = tonumber(target)

    if not source or not target then
        return false
    end
    if source == target then
        return true
    end

    local xPlayer = ESX.Player(source)
    local xTarget = ESX.Player(target)
    if not xPlayer or not xTarget then
        return false
    end
    if isAdmin(xPlayer) then
        return true
    end

    local job = xPlayer.getJob()
    if not job or not Config.allowedJobs[job.name] then
        return false
    end
    if job.onDuty == false then
        return false
    end

    return isNearPlayer(source, target)
end

AddEventHandler('esx_license:addLicense', function(target, licenseType, cb)
    local xPlayer = ESX.Player(target)
    if xPlayer then
        if isValidLicense(licenseType) then
            CheckLicense(xPlayer.getIdentifier(), licenseType, function(hasLicense)
                if hasLicense then
                    if cb then
                        cb(false)
                    end
                    return
                end

                AddLicense(xPlayer.getIdentifier(), licenseType, cb)
            end)
        else
            print(
                ('[esx_license]: Missing license type in db ^5%s^0 or someone try to use lua executor ID: ^5%s^0'):format(
                    licenseType,
                    target
                )
            )
        end
    end
end)

RegisterNetEvent('esx_license:removeLicense')
AddEventHandler('esx_license:removeLicense', function(target, licenseType, cb)
    local xPlayer = ESX.Player(source)
    if xPlayer then
        if
            Config.allowedJobs[xPlayer.getJob().name]
            and isValidLicense(licenseType)
            and canReadTargetLicenses(source, target)
        then
            local xTarget = ESX.Player(target)
            if xTarget then
                RemoveLicense(xTarget.getIdentifier(), licenseType, cb)
            end
        else
            xPlayer.showNotification('Your job is not allowed to remove the license', 'error', 3000)
        end
    end
end)

AddEventHandler('esx_license:getLicense', function(licenseType, cb)
    GetLicense(licenseType, cb)
end)

AddEventHandler('esx_license:getLicenses', function(target, cb)
    local xPlayer = ESX.Player(target)
    if xPlayer then
        GetLicenses(xPlayer.getIdentifier(), cb)
    end
end)

AddEventHandler('esx_license:checkLicense', function(target, licenseType, cb)
    local xPlayer = ESX.Player(target)
    if xPlayer then
        CheckLicense(xPlayer.getIdentifier(), licenseType, cb)
    end
end)

AddEventHandler('esx_license:getLicensesList', function(cb)
    GetLicensesList(cb)
end)

xLib.callback.registerCompat('esx_license:getLicense', function(source, cb, licenseType)
    local xPlayer = ESX.Player(source)
    if xPlayer then
        GetLicense(licenseType, cb)
    end
end)

xLib.callback.registerCompat('esx_license:getLicenses', function(source, cb, target)
    target = tonumber(target) or source
    if not canReadTargetLicenses(source, target) then
        return cb({})
    end

    local xPlayer = ESX.Player(target)
    if xPlayer then
        GetLicenses(xPlayer.getIdentifier(), cb)
    else
        cb({})
    end
end)

xLib.callback.registerCompat('esx_license:checkLicense', function(source, cb, target, licenseType)
    target = tonumber(target) or source
    if not isValidLicense(licenseType) or not canReadTargetLicenses(source, target) then
        return cb(false)
    end

    local xPlayer = ESX.Player(target)
    if xPlayer then
        CheckLicense(xPlayer.getIdentifier(), licenseType, cb)
    else
        cb(false)
    end
end)

xLib.callback.registerCompat('esx_license:getLicensesList', function(source, cb)
    GetLicensesList(cb)
end)

refreshLicenseCatalog = function()
    catalogRefreshPending = true

    if not grantsReady or catalogRefreshing then
        return
    end

    catalogRefreshing = true

    local ok, err = pcall(function()
        repeat
            catalogRefreshPending = false
            licenses = MySQL.query.await('SELECT type, label FROM licenses')
        until not catalogRefreshPending
    end)

    catalogRefreshing = false

    if not ok then
        print(('[esx_license] Catalog refresh failed: %s'):format(tostring(err)))
    end
end

AddEventHandler('esx:sqlCatalogReady', function(tables)
    if tables.licenses then
        refreshLicenseCatalog()
    end
end)
