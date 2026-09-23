-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local BANK = {}

local spawnedPeds, netIdTable = {}, {}
local playerSessions, playerLocks = {}, {}
local atmModelLookup = {}
local rateLimiters = {}

local TRANSACTION_TYPES = {
    deposit = "DEPOSIT",
    withdraw = "WITHDRAW",
    transfer = "TRANSFER",
    transferReceive = "TRANSFER_RECEIVE",
    pincode = "PINCODE"
}

for i = 1, #(Config.AtmModels or {}) do
    atmModelLookup[Config.AtmModels[i]] = true
end

local function DebugLog(message)
    if Config.Debug then
        print(("[esx_banking] %s"):format(message))
    end
end

local function Notify(playerId, localeKey, notificationType, ...)
    TriggerClientEvent("esx:showNotification", playerId, TranslateCap(localeKey, ...), notificationType or "info")
end

local function GetConfigNumber(key, default)
    local value = tonumber(Config[key])
    if value == nil then
        return default
    end

    return value
end

local function GetXPlayer(playerId)
    local ok, xPlayer = pcall(function()
        return ESX.Player(playerId)
    end)

    if not ok then
        DebugLog(("Failed to get xPlayer for %s: %s"):format(playerId, xPlayer))
        return nil
    end

    return xPlayer
end

local function GetIdentifier(xPlayer)
    local ok, identifier = pcall(function()
        return xPlayer.getIdentifier()
    end)

    if ok and identifier then
        return identifier
    end

    return nil
end

local function GetPlayerDisplayName(xPlayer)
    local ok, name = pcall(function()
        return xPlayer.getName()
    end)

    if ok and name then
        return name
    end

    return "Unknown"
end

local function GetAccountMoney(xPlayer, accountName)
    if not xPlayer or type(xPlayer.getAccount) ~= "function" then
        return nil
    end

    local ok, account = pcall(function()
        return xPlayer.getAccount(accountName)
    end)

    if not ok or type(account) ~= "table" or type(account.money) ~= "number" then
        return nil
    end

    return account.money
end

local function AddAccountMoney(xPlayer, accountName, amount, reason)
    if not xPlayer or type(xPlayer.addAccountMoney) ~= "function" then
        return false
    end

    local ok, result = pcall(function()
        return xPlayer.addAccountMoney(accountName, amount, reason)
    end)

    return ok and result ~= false
end

local function RemoveAccountMoney(xPlayer, accountName, amount, reason)
    if not xPlayer or type(xPlayer.removeAccountMoney) ~= "function" then
        return false
    end

    local ok, result = pcall(function()
        return xPlayer.removeAccountMoney(accountName, amount, reason)
    end)

    return ok and result ~= false
end

local function NormalizeAmount(value)
    local amount = tonumber(value)
    if not amount or amount ~= amount or amount == math.huge or amount == -math.huge then
        return nil
    end

    amount = ESX.Math.Round(amount)
    local maxAmount = GetConfigNumber("MaxTransactionAmount", 100000000)

    if amount < 1 or amount > maxAmount then
        return nil
    end

    return amount
end

local function NormalizePin(value)
    local pinText = tostring(value or ""):gsub("%s+", "")
    if not pinText:match("^%d%d%d%d$") then
        return nil, nil
    end

    return tonumber(pinText), pinText
end

local function FormatLogValue(value)
    local text = tostring(value or ""):gsub("[%c\r\n]", " ")
    local maxLength = GetConfigNumber("LogValueMaxLength", 80)

    if #text > maxLength then
        return text:sub(1, maxLength) .. "..."
    end

    return text
end

local function IsRateLimited(playerId, key, cooldownMs)
    cooldownMs = math.max(0, math.floor(tonumber(cooldownMs) or 0))
    if cooldownMs <= 0 then
        return false
    end

    local limiterState = rateLimiters[key]
    if not limiterState or limiterState.cooldownMs ~= cooldownMs then
        limiterState = {
            cooldownMs = cooldownMs,
            limiter = xLib.rateLimiter({
                capacity = 1,
                refill = 1,
                interval = cooldownMs,
                staleMs = math.max(60000, cooldownMs * 4)
            })
        }
        rateLimiters[key] = limiterState
    end

    local allowed = limiterState.limiter:consume(playerId)
    return not allowed
end

local function AcquirePlayerLock(playerId)
    if playerLocks[playerId] then
        return false
    end

    playerLocks[playerId] = true
    return true
end

local function ReleasePlayerLock(playerId)
    playerLocks[playerId] = nil
end

local function GetServerCoords(playerId)
    local ped = GetPlayerPed(playerId)
    if not ped or ped == 0 then
        return nil
    end

    local ok, coords = pcall(function()
        return GetEntityCoords(ped)
    end)

    if ok then
        return coords
    end

    return nil
end

local function IsPlayerNearBank(playerId)
    local coords = GetServerCoords(playerId)
    if not coords then
        return false
    end

    local distance = GetConfigNumber("InteractionDistance", 1.5)

    for i = 1, #(Config.Banks or {}) do
        local position = Config.Banks[i].Position
        local bankCoords = vector3(position.x, position.y, position.z)

        if #(coords - bankCoords) <= distance then
            return true
        end
    end

    return false
end

local function IsPlayerNearConfiguredAtm(playerId)
    local coords = GetServerCoords(playerId)
    if not coords then
        return false
    end

    local distance = GetConfigNumber("AtmInteractionDistance", 2.0)

    for i = 1, #(Config.AtmLocations or {}) do
        if #(coords - Config.AtmLocations[i]) <= distance then
            return true
        end
    end

    return false
end

local function FindConfiguredAtmNearCoords(coords, distance)
    if not coords then
        return nil
    end

    for i = 1, #(Config.AtmLocations or {}) do
        local atmCoords = Config.AtmLocations[i]
        if #(coords - atmCoords) <= distance then
            return atmCoords
        end
    end

    return nil
end

local function NormalizeAtmCoords(coords)
    local coordsType = type(coords)
    if coordsType ~= "table" and coordsType ~= "vector3" then
        return nil
    end

    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then
        return nil
    end

    return vector3(x, y, z)
end

local function NormalizeClientAtmData(atmData)
    if Config.ClientAtmFallback == false or type(atmData) ~= "table" then
        return nil
    end

    local model = tonumber(atmData.model)
    if not model or not atmModelLookup[model] then
        return nil
    end

    local coords = NormalizeAtmCoords(atmData.coords)
    if not coords then
        return nil
    end

    return {
        model = model,
        coords = coords
    }
end

local function IsPlayerNearClientAtm(playerId, atmData)
    local atm = NormalizeClientAtmData(atmData)
    if not atm then
        return false
    end

    local coords = GetServerCoords(playerId)
    if not coords then
        return false
    end

    local distance = GetConfigNumber("ClientAtmFallbackDistance", GetConfigNumber("AtmInteractionDistance", 2.0))
    local configuredAtmCoords = FindConfiguredAtmNearCoords(atm.coords, distance)
    if not configuredAtmCoords then
        return false
    end

    if #(coords - configuredAtmCoords) <= distance then
        atm.coords = configuredAtmCoords
        return true, atm
    end

    return false
end

local function IsPlayerNearNetworkedAtm(playerId)
    if type(GetAllObjects) ~= "function" then
        return false
    end

    local coords = GetServerCoords(playerId)
    if not coords then
        return false
    end

    local ok, objects = pcall(GetAllObjects)
    if not ok or type(objects) ~= "table" then
        return false
    end

    local distance = GetConfigNumber("AtmInteractionDistance", 2.0)

    for i = 1, #objects do
        local object = objects[i]
        if DoesEntityExist(object) and atmModelLookup[GetEntityModel(object)] then
            if #(coords - GetEntityCoords(object)) <= distance then
                return true
            end
        end
    end

    return false
end

local function IsPlayerNearAtm(playerId, atmData)
    if IsPlayerNearConfiguredAtm(playerId) or IsPlayerNearNetworkedAtm(playerId) then
        return true
    end

    return IsPlayerNearClientAtm(playerId, atmData)
end

local function ValidateAccess(playerId, requestedType, accessData)
    if requestedType == "bank" then
        return IsPlayerNearBank(playerId), "bank"
    end

    if requestedType == "atm" then
        local isNear, atm = IsPlayerNearAtm(playerId, type(accessData) == "table" and accessData.atm or nil)
        return isNear, "atm", atm
    end

    if IsPlayerNearBank(playerId) then
        return true, "bank"
    end

    local isNearAtm, atm = IsPlayerNearAtm(playerId, type(accessData) == "table" and accessData.atm or nil)
    if isNearAtm then
        return true, "atm", atm
    end

    return false, nil
end

local function StartSession(playerId, requestedType, accessData)
    local isValid, accessType, atm = ValidateAccess(playerId, requestedType, accessData)
    if not isValid then
        return nil
    end

    playerSessions[playerId] = {
        accessType = accessType,
        expiresAt = os.time() + GetConfigNumber("SessionDuration", 90),
        atm = atm,
        pinUnlocked = accessType ~= "atm" or Config.RequireAtmPin == false
    }

    return accessType
end

local function ValidateSession(playerId, action, skipPinCheck)
    local session = playerSessions[playerId]
    if not session or session.expiresAt < os.time() then
        playerSessions[playerId] = nil
        return false
    end

    if (action == "transfer" or action == "pincode") and session.accessType ~= "bank" then
        return false
    end

    if not skipPinCheck and session.accessType == "atm" and Config.RequireAtmPin ~= false and not session.pinUnlocked then
        return false
    end

    local isValid = ValidateAccess(playerId, session.accessType, {atm = session.atm})
    if not isValid then
        playerSessions[playerId] = nil
        return false
    end

    session.expiresAt = os.time() + GetConfigNumber("SessionDuration", 90)
    return true, session.accessType
end

local function HasPincode(identifier)
    local ok, pincode = pcall(function()
        return MySQL.scalar.await("SELECT pincode FROM users WHERE identifier = ? LIMIT 1", {identifier})
    end)

    return ok and pincode ~= nil
end

local function FetchTransactionHistory(identifier)
    local historyDays = math.max(1, GetConfigNumber("HistoryDays", 30))
    local historyLimit = math.max(1, math.min(GetConfigNumber("HistoryLimit", 20), 100))
    local since = (os.time() - (historyDays * 86400)) * 1000

    local ok, rows = pcall(function()
        return MySQL.query.await(
            "SELECT label, type, amount, time, balance FROM banking WHERE identifier = ? AND time > ? ORDER BY time DESC LIMIT ?",
            {identifier, since, historyLimit}
        )
    end)

    if not ok or type(rows) ~= "table" then
        DebugLog(("Failed to fetch transaction history for %s"):format(identifier))
        return {}
    end

    return rows
end

local function BuildPlayerData(playerId, xPlayer, accessType)
    local identifier = GetIdentifier(xPlayer)
    if not identifier then
        return nil
    end

    return {
        success = true,
        accessType = accessType,
        playerName = GetPlayerDisplayName(xPlayer),
        money = GetAccountMoney(xPlayer, "money") or 0,
        bankMoney = GetAccountMoney(xPlayer, "bank") or 0,
        hasPin = HasPincode(identifier),
        transactionHistory = FetchTransactionHistory(identifier)
    }
end

local function SendAccountUpdate(playerId, actionType)
    local session = playerSessions[playerId]
    local xPlayer = GetXPlayer(playerId)
    if not session or not xPlayer then
        return
    end

    local data = BuildPlayerData(playerId, xPlayer, session.accessType)
    if not data then
        return
    end

    data.actionType = actionType
    TriggerClientEvent("esx_banking:updateMoneyInUI", playerId, data)
end

local function DeductAccountMoney(xPlayer, accountName, amount, reason)
    local before = GetAccountMoney(xPlayer, accountName)
    if not before or before < amount then
        return false, "not_enough_money"
    end

    local removed = RemoveAccountMoney(xPlayer, accountName, amount, reason)
    local after = GetAccountMoney(xPlayer, accountName)

    if after then
        if before - after >= amount then
            return true, after
        end

        return false, "transaction_failed"
    end

    if not removed then
        return false, "transaction_failed"
    end

    return true, before - amount
end

local function CreditAccountMoney(xPlayer, accountName, amount, reason)
    local before = GetAccountMoney(xPlayer, accountName)
    local added = AddAccountMoney(xPlayer, accountName, amount, reason)
    local after = GetAccountMoney(xPlayer, accountName)

    if before and after then
        if after - before >= amount then
            return true, after
        end

        return false, after
    end

    if not added then
        return false, after
    end

    return true, after or ((before or 0) + amount)
end

local function ParsePayload(payload)
    if type(payload) ~= "table" then
        return nil
    end

    local action = payload.action

    if action == "deposit" then
        return action, NormalizeAmount(payload.amount)
    end

    if action == "withdraw" then
        return action, NormalizeAmount(payload.amount)
    end

    if action == "transfer" then
        local targetId = tonumber(payload.target)
        if not targetId or targetId <= 0 or targetId % 1 ~= 0 then
            return nil
        end

        return action, NormalizeAmount(payload.amount), targetId
    end

    if action == "pincode" then
        local pinNumber, pinText = NormalizePin(payload.pin)
        return action, pinNumber, pinText
    end

    if payload.deposit then
        return "deposit", NormalizeAmount(payload.deposit)
    end

    if payload.withdraw then
        return "withdraw", NormalizeAmount(payload.withdraw)
    end

    if payload.transfer and type(payload.transfer) == "table" then
        local targetId = tonumber(payload.transfer.playerId)
        if not targetId or targetId <= 0 or targetId % 1 ~= 0 then
            return nil
        end

        return "transfer", NormalizeAmount(payload.transfer.moneyAmount), targetId
    end

    if payload.pincode then
        local pinNumber, pinText = NormalizePin(payload.pincode)
        return "pincode", pinNumber, pinText
    end

    return nil
end

local function EnsureBankingIndexes()
    local ok, hasIndex = pcall(function()
        return MySQL.scalar.await(
            "SELECT COUNT(1) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'banking' AND INDEX_NAME = 'idx_banking_identifier_time'"
        )
    end)

    if not ok then
        DebugLog("Could not inspect banking indexes")
        return
    end

    if tonumber(hasIndex) == 0 then
        local created = pcall(function()
            MySQL.query.await("CREATE INDEX idx_banking_identifier_time ON banking (identifier, time)")
        end)

        if created then
            DebugLog("Created banking history index")
        end
    end
end

local function PruneOldTransactions()
    local retentionDays = GetConfigNumber("LogRetentionDays", 60)
    if retentionDays <= 0 then
        return
    end

    local cutoff = (os.time() - (retentionDays * 86400)) * 1000
    pcall(function()
        MySQL.update.await("DELETE FROM banking WHERE time < ?", {cutoff})
    end)
end

function BANK.CreatePeds()
    for i = 1, #(Config.Peds or {}) do
        local model = Config.Peds[i].Model
        local coords = Config.Peds[i].Position
        spawnedPeds[i] = CreatePed(0, model, coords.x, coords.y, coords.z, coords.w, true, true)
        netIdTable[i] = NetworkGetNetworkIdFromEntity(spawnedPeds[i])

        while not DoesEntityExist(spawnedPeds[i]) do
            Wait(50)
        end
    end

    Wait(100)
    TriggerClientEvent("esx_banking:pedHandler", -1, netIdTable)
end

function BANK.DeletePeds()
    for i = 1, #spawnedPeds do
        if spawnedPeds[i] and DoesEntityExist(spawnedPeds[i]) then
            DeleteEntity(spawnedPeds[i])
        end

        spawnedPeds[i] = nil
    end
end

function BANK.Deposit(playerId, xPlayer, amount)
    local deducted, reason = DeductAccountMoney(xPlayer, "money", amount, "Bank deposit")
    if not deducted then
        Notify(playerId, reason == "not_enough_money" and "not_enough_money" or "cant_do_it", "error", amount)
        return false
    end

    local credited, bankBalance = CreditAccountMoney(xPlayer, "bank", amount, "Bank deposit")
    if not credited then
        AddAccountMoney(xPlayer, "money", amount, "Bank deposit rollback")
        Notify(playerId, "cant_do_it", "error")
        return false
    end

    BANK.LogTransaction(playerId, TRANSACTION_TYPES.deposit, TRANSACTION_TYPES.deposit, amount, bankBalance)
    Notify(playerId, "deposit_money", "success", amount)
    return true
end

function BANK.Withdraw(playerId, xPlayer, amount)
    local deducted, reason = DeductAccountMoney(xPlayer, "bank", amount, "Bank withdraw")
    if not deducted then
        Notify(playerId, reason == "not_enough_money" and "not_enough_money" or "cant_do_it", "error", amount)
        return false
    end

    local credited = CreditAccountMoney(xPlayer, "money", amount, "Bank withdraw")
    if not credited then
        AddAccountMoney(xPlayer, "bank", amount, "Bank withdraw rollback")
        Notify(playerId, "cant_do_it", "error")
        return false
    end

    local bankBalance = GetAccountMoney(xPlayer, "bank") or 0
    BANK.LogTransaction(playerId, TRANSACTION_TYPES.withdraw, TRANSACTION_TYPES.withdraw, amount, bankBalance)
    Notify(playerId, "withdraw_money", "success", amount)
    return true
end

function BANK.Transfer(playerId, xPlayer, targetId, amount)
    if playerId == targetId then
        Notify(playerId, "cant_do_it", "error")
        return false
    end

    local xTarget = GetXPlayer(targetId)
    if not xTarget then
        Notify(playerId, "cant_do_it", "error")
        return false
    end

    local deducted, reason = DeductAccountMoney(xPlayer, "bank", amount, "Bank transfer")
    if not deducted then
        Notify(playerId, reason == "not_enough_money" and "not_enough_money" or "cant_do_it", "error", amount)
        return false
    end

    local credited, targetBankBalance = CreditAccountMoney(xTarget, "bank", amount, "Bank transfer")
    if not credited then
        AddAccountMoney(xPlayer, "bank", amount, "Bank transfer rollback")
        Notify(playerId, "cant_do_it", "error")
        return false
    end

    local bankBalance = GetAccountMoney(xPlayer, "bank") or 0
    BANK.LogTransaction(playerId, TRANSACTION_TYPES.transfer, TRANSACTION_TYPES.transfer, amount, bankBalance)
    BANK.LogTransaction(targetId, TRANSACTION_TYPES.transferReceive, TRANSACTION_TYPES.transferReceive, amount, targetBankBalance)

    Notify(playerId, "transfer_money", "success", amount, targetId)
    Notify(targetId, "receive_transfer", "success", amount, playerId)
    SendAccountUpdate(targetId, TRANSACTION_TYPES.transferReceive)
    return true
end

function BANK.Pincode(playerId, xPlayer, pinNumber)
    local identifier = GetIdentifier(xPlayer)
    if not identifier then
        Notify(playerId, "cant_do_it", "error")
        return false
    end

    local updated = pcall(function()
        MySQL.update.await("UPDATE users SET pincode = ? WHERE identifier = ?", {pinNumber, identifier})
    end)

    if not updated then
        Notify(playerId, "cant_do_it", "error")
        return false
    end

    Notify(playerId, "pincode_money", "success", "****")
    return true
end

function BANK.LogTransaction(playerId, label, logType, amount, bankMoney)
    if not playerId then
        return
    end

    local normalizedAmount = NormalizeAmount(amount)
    if not normalizedAmount then
        return
    end

    local xPlayer = GetXPlayer(tonumber(playerId))
    if not xPlayer then
        return
    end

    local identifier = GetIdentifier(xPlayer)
    if not identifier then
        return
    end

    local safeLogType = FormatLogValue(logType or label):upper()
    local safeLabel = FormatLogValue(label or safeLogType)
    local balance = tonumber(bankMoney) or GetAccountMoney(xPlayer, "bank") or 0

    pcall(function()
        MySQL.insert.await(
            "INSERT INTO banking (identifier, label, type, amount, time, balance) VALUES (?, ?, ?, ?, ?, ?)",
            {identifier, safeLabel, safeLogType, normalizedAmount, os.time() * 1000, balance}
        )
    end)
end

AddEventHandler("onResourceStart", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end

    CreateThread(function()
        if Config.EnablePeds then
            BANK.CreatePeds()
        end

        EnsureBankingIndexes()
        PruneOldTransactions()
    end)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end

    if Config.EnablePeds then
        BANK.DeletePeds()
    end
end)

AddEventHandler("playerDropped", function()
    local playerId = source
    playerSessions[playerId] = nil
    playerLocks[playerId] = nil
end)

if Config.EnablePeds then
    AddEventHandler("esx:playerLoaded", function(playerId)
        TriggerClientEvent("esx_banking:pedHandler", playerId, netIdTable)
    end)
end

RegisterNetEvent("esx_banking:doingType", function(typeData)
    local playerId = source

    if IsRateLimited(playerId, "transaction", GetConfigNumber("TransactionCooldown", 1250)) then
        return
    end

    local action, amount, targetOrPinText = ParsePayload(typeData)
    if not action or not amount then
        Notify(playerId, "invalid_amount", "error")
        return
    end

    local validSession = ValidateSession(playerId, action)
    if not validSession then
        Notify(playerId, "cant_do_it", "error")
        return
    end

    if not AcquirePlayerLock(playerId) then
        Notify(playerId, "cant_do_it", "error")
        return
    end

    local success = false
    local xPlayer = GetXPlayer(playerId)

    if xPlayer then
        if action == "deposit" then
            success = BANK.Deposit(playerId, xPlayer, amount)
        elseif action == "withdraw" then
            success = BANK.Withdraw(playerId, xPlayer, amount)
        elseif action == "transfer" then
            success = BANK.Transfer(playerId, xPlayer, targetOrPinText, amount)
        elseif action == "pincode" then
            success = BANK.Pincode(playerId, xPlayer, amount, targetOrPinText)
        end
    end

    ReleasePlayerLock(playerId)

    if success then
        SendAccountUpdate(playerId, TRANSACTION_TYPES[action] or action:upper())
    end
end)

xLib.callback.registerCompat("esx_banking:getPlayerData", function(source, cb, accessData)
    local playerId = source
    local requestedType = type(accessData) == "table" and accessData.accessType or accessData

    if IsRateLimited(playerId, "open", 750) then
        cb({success = false})
        return
    end

    local accessType = StartSession(playerId, requestedType == "atm" and "atm" or "bank", type(accessData) == "table" and accessData or nil)
    if not accessType then
        cb({success = false})
        return
    end

    local xPlayer = GetXPlayer(playerId)
    if not xPlayer then
        cb({success = false})
        return
    end

    cb(BuildPlayerData(playerId, xPlayer, accessType) or {success = false})
end)

xLib.callback.registerCompat("esx_banking:checkPincode", function(source, cb, inputPincode)
    local playerId = source

    if IsRateLimited(playerId, "pin", GetConfigNumber("PinAttemptCooldown", 1500)) then
        cb(false)
        return
    end

    local validSession, accessType = ValidateSession(playerId, "withdraw", true)
    if not validSession or accessType ~= "atm" then
        cb(false)
        return
    end

    local pinNumber = NormalizePin(inputPincode)
    if not pinNumber then
        cb(false)
        return
    end

    local xPlayer = GetXPlayer(playerId)
    local identifier = xPlayer and GetIdentifier(xPlayer)
    if not identifier then
        cb(false)
        return
    end

    local ok, pincode = pcall(function()
        return MySQL.scalar.await("SELECT COUNT(1) FROM users WHERE identifier = ? AND pincode = ?", {identifier, pinNumber})
    end)

    local validPin = ok and (tonumber(pincode) or 0) > 0
    if validPin and playerSessions[playerId] then
        playerSessions[playerId].pinUnlocked = true
    end

    cb(validPin)
end)

local function logTransaction(targetSource, label, key, amount)
    if not targetSource then
        return
    end

    if type(key) ~= "string" or key == "" then
        return
    end

    BANK.LogTransaction(targetSource, label, key, amount)
end

exports("logTransaction", logTransaction)
