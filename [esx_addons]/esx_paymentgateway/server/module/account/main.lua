-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- The money side of a payment: reading balances and taking money from an ESX account in a way
--- that can be trusted. ESX refuses some removals and only says so through its return value (a
--- missing account, cover lost to rounding, a player who is logging out), and ox_inventory's
--- override takes from non-item accounts without checking cover. So every charge is checked
--- before, guarded while it runs and proven after.

local Account = {}

--- Why a charge took nothing: no such player, a method that is not enabled, an amount that is no
--- whole number of at least 1, too little money, or ESX refusing to take it.
---@alias ChargeFailure "player"|"method"|"amount"|"insufficient"|"failed"

--- ESX 1.16 gives every player these, but does not list them on StaticPlayer yet.
---@class StaticPlayer
---@field beginAccountOperation fun(): boolean
---@field endAccountOperation fun()

--- Largest amount; above it doubles lose whole units.
local MAX_AMOUNT <const> = 9007199254740991

---@param message string
local function warn(message)
    print(("[^3WARNING^7] esx_paymentgateway: %s"):format(message))
end

---@param player StaticPlayer
---@param account string ESX account name
---@return number|nil money Balance, nil when the account cannot be read
local function money(player, account)
    local ok, data = pcall(player.getAccount, account)
    if not ok or type(data) ~= "table" then return nil end
    return tonumber(data.money)
end

---@param player StaticPlayer
---@param method PaymentMethod
---@return number
local function balanceOf(player, method)
    local account = Config.Accounts[method]
    return account and math.max(0, money(player, account) or 0) or 0
end

---@param value any
---@return boolean
local function isAmount(value)
    return type(value) == "number" and value >= 1 and value <= MAX_AMOUNT and value % 1 == 0
end

---The ESX account of a method the server takes payments in.
---@param method any
---@return string|nil
local function accountOf(method)
    if type(method) ~= "string" then return nil end
    for i = 1, #Config.Methods do
        if Config.Methods[i] == method then return Config.Accounts[method] end
    end
    return nil
end

---@param player StaticPlayer
---@return string|nil
local function identifierOf(player)
    local ok, identifier = pcall(player.getIdentifier)
    return ok and type(identifier) == "string" and identifier or nil
end

---Text for the player about a charge that took nothing, in the server's locale.
---@param failure ChargeFailure
---@param method any
---@return string
local function messageOf(failure, method)
    if failure == "insufficient" then return TranslateCap("insufficient_" .. method) end
    if failure == "method" then return TranslateCap("method_unavailable") end
    return TranslateCap("payment_failed")
end

---Checks what a resource passed to Charge or Refund.
---@param playerId any
---@param method any
---@param amount any
---@return StaticPlayer|nil player
---@return string|ChargeFailure account The ESX account, or why the call was refused
local function resolve(playerId, method, amount)
    local player = type(playerId) == "number" and ESX.Player(playerId)
    if not player then return nil, "player" end
    local account = accountOf(method)
    if not account then return nil, "method" end
    if not isAmount(amount) then return nil, "amount" end
    return player, account
end

---The player's balance for both methods. A method without an account shows 0, so the dialog
---always gets both, also on servers that pay only in cash or only by card.
---@param player StaticPlayer
---@return table<PaymentMethod, number>
function Account.balances(player)
    return {
        cash = balanceOf(player, "cash"),
        card = balanceOf(player, "card"),
    }
end

---Takes money from a player's account and proves it was taken.
---@param player StaticPlayer
---@param playerId integer Server id of the player, for warnings
---@param account string ESX account name
---@param amount integer
---@param reason string Shown in ESX's account logs
---@return boolean charged
---@return "insufficient"|"failed"|nil failure Why nothing was taken
function Account.take(player, playerId, account, amount, reason)
    local before = money(player, account)
    if not before or before < amount then return false, "insufficient" end

    -- ESX refuses account changes while a player logs out; versions without the guard skip it.
    local guarded, began = pcall(player.beginAccountOperation)
    if guarded and began == false then return false, "failed" end

    local called, removed = pcall(player.removeAccountMoney, account, amount, reason)
    if guarded and began then pcall(player.endAccountOperation) end

    local after = money(player, account)
    local dropped = after and before - after

    if not called or removed == false then
        if not called then warn(("removeAccountMoney failed: %s"):format(removed)) end
        return false, "failed"
    end

    if removed == true then
        if dropped ~= amount then
            warn(("player %s, %s: ESX took %s but the balance moved by %s"):format(
                playerId, account, amount, dropped))
        end
        return true
    end

    -- Versions that return nothing: only the balance can tell whether the money was taken.
    if dropped == amount then return true end
    warn(("player %s, %s: tried to take %s, the balance moved by %s"):format(
        playerId, account, amount, dropped))
    return false, "failed"
end

---Takes the price of something a player buys, with the method they chose. The resource that
---calls this has checked everything else (price, stock, distance, whether it takes that method)
---right before, on its own server.
---@param playerId integer
---@param method PaymentMethod
---@param amount integer
---@param reason? string Shown in ESX's account logs
---@param resource? string Resource that charges, for the paid event
---@return boolean charged
---@return ChargeFailure|nil failure
---@return string|nil message Why, ready to show the player
function Account.charge(playerId, method, amount, reason, resource)
    local player, account = resolve(playerId, method, amount)
    if not player then return false, account, messageOf(account, method) end
    ---@cast account string

    reason = type(reason) == "string" and reason or "Payment"
    local charged, failure = Account.take(player, playerId, account, amount, reason)
    if not charged then return false, failure, messageOf(failure, method) end

    TriggerEvent("esx_paymentgateway:paid", {
        playerId = playerId,
        identifier = identifierOf(player),
        amount = amount,
        method = method,
        account = account,
        reason = reason,
        resource = resource,
    })
    return true
end

---Gives money back, for when what was paid for could not be handed over.
---@param playerId integer
---@param method PaymentMethod
---@param amount integer
---@param reason? string Shown in ESX's account logs
---@return boolean refunded
function Account.refund(playerId, method, amount, reason)
    local player, account = resolve(playerId, method, amount)
    if not player then
        warn(("could not refund %s to player %s by %s: %s"):format(amount, playerId, method, account))
        return false
    end
    ---@cast account string

    local before = money(player, account)
    local called, added = pcall(player.addAccountMoney, account, amount, type(reason) == "string" and reason or "Refund")
    local after = money(player, account)

    if called and (added == true or (added == nil and before and after and after - before == amount)) then
        return true
    end
    -- Nobody else will notice money that did not come back, so it has to show in the console.
    warn(("could not refund %s to player %s (%s): %s"):format(amount, playerId, account, called and "ESX refused" or added))
    return false
end

return Account
