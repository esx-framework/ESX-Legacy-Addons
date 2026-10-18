-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- Payments the server holds open: one per player, bound to the character it was opened for and
--- settled by the method the player picks. Amount, balances and outcome are decided here; the
--- client only names a method. Everything runs synchronously, as net event logic has to, and a
--- payment is taken off the books before any money moves, so it can never be settled twice.

local Account = require "server.module.account.main"
local Util = require "server.module.payment.util"

local Payment = {}

--- How a payment ended, as the requester hears it.
---@alias PaymentOutcome "paid"|"cancelled"|"expired"|"dropped"

---@type table<integer, PaymentRequest>
local open = {}
local lastId = 0

---@param message string
local function warn(message)
    print(("[^3WARNING^7] esx_paymentgateway: %s"):format(message))
end

---@param player StaticPlayer
---@return string|nil
local function identifierOf(player)
    local ok, identifier = pcall(player.getIdentifier)
    return ok and type(identifier) == "string" and identifier or nil
end

---Answers the method the player chose.
---@param playerId integer
---@param id integer
---@param ok boolean
---@param method PaymentMethod|nil
---@param reason string|nil Locale key of why it failed
---@param wallet table<PaymentMethod, number>
local function answer(playerId, id, ok, method, reason, wallet)
    TriggerClientEvent("esx_paymentgateway:result", playerId, {
        id = id,
        ok = ok,
        method = method,
        error = reason,
        balances = wallet,
    })
end

---Tells the requesting resource how its payment ended: through its callback and its result
---event. A failing callback is logged and cannot break the payment.
---@param playerId integer
---@param request PaymentRequest
---@param success boolean
---@param method PaymentMethod|nil
---@param outcome PaymentOutcome
local function report(playerId, request, success, method, outcome)
    local public = Util.public(request)
    if request.onResult then
        local ok, err = pcall(request.onResult, playerId, success, method, public, outcome)
        if not ok then warn(("result callback of %s failed: %s"):format(request.resource, err)) end
    end
    if request.resultEvent then
        TriggerEvent(request.resultEvent, playerId, success, method, public, outcome)
    end
end

---Takes a player's open payment off the books.
---@param playerId integer
---@param id? any Only take it when it has this id
---@return PaymentRequest|nil
local function take(playerId, id)
    local request = open[playerId]
    if not request or (id ~= nil and request.id ~= id) then return nil end
    open[playerId] = nil
    return request
end

---Ends an open payment that was not paid and tells the client to close.
---@param playerId integer
---@param request PaymentRequest
---@param outcome PaymentOutcome
---@param notice? string Locale key the player is shown
local function abandon(playerId, request, outcome, notice)
    TriggerClientEvent("esx_paymentgateway:close", playerId, notice)
    report(playerId, request, false, nil, outcome)
end

---Puts a payment back after a failed charge, so the player can try another method. The charge
---runs ESX's and maybe the inventory's code; should that ever wait, the player may have left,
---the payment may have run out or another one may have opened in the meantime. Then the payment
---ends here instead, because nothing else would end it.
---@param playerId integer
---@param request PaymentRequest
---@return boolean reopened
local function reopen(playerId, request)
    local player = ESX.Player(playerId)
    if not player or identifierOf(player) ~= request.identifier then
        report(playerId, request, false, nil, "dropped")
        return false
    end
    if open[playerId] then
        report(playerId, request, false, nil, "cancelled")
        return false
    end
    if GetGameTimer() >= request.expiresAt then
        abandon(playerId, request, "expired", "payment_expired")
        return false
    end
    open[playerId] = request
    return true
end

---Opens the payment dialog for a player.
---@param playerId integer
---@param input any Request from the export
---@param resource? string Resource that asked
---@param onResult? any Callback from the export
---@return boolean opened
---@return string|integer|nil detail Payment id when it opened, the reason when it did not
function Payment.request(playerId, input, resource, onResult)
    local player = type(playerId) == "number" and ESX.Player(playerId)
    if not player then return false, "Player is not available." end
    if open[playerId] then return false, "The player already has a payment open." end
    if onResult ~= nil and not Util.isCallable(onResult) then
        return false, "The result callback must be a function."
    end

    local identifier = identifierOf(player)
    if not identifier then return false, "Player is not available." end

    local request, reason = Util.normalize(input)
    if not request then return false, reason end

    lastId = lastId + 1
    request.id = lastId
    request.resource = resource
    request.identifier = identifier
    request.onResult = onResult
    request.expiresAt = GetGameTimer() + Config.Timeout * 1000
    open[playerId] = request

    TriggerClientEvent("esx_paymentgateway:open", playerId, {
        id = request.id,
        amount = request.amount,
        currency = request.currency,
        title = request.title,
        description = request.description,
        methods = request.methods,
        balances = Account.balances(player),
        hold = Config.HoldAmount > 0 and request.amount >= Config.HoldAmount,
        expiresIn = Config.Timeout * 1000,
    })

    local id = request.id
    SetTimeout(Config.Timeout * 1000, function()
        local expired = take(playerId, id)
        if expired then abandon(playerId, expired, "expired", "payment_expired") end
    end)

    return true, id
end

---Pays a player's open payment with the method they chose.
---@param playerId integer
---@param id any Payment id from the client
---@param method any Method from the client
function Payment.pay(playerId, id, method)
    local request = open[playerId]
    if not request or request.id ~= id then return end
    local player = ESX.Player(playerId)
    if not player then return end

    -- Another character on the same connection must never pay for the one the payment was for.
    if identifierOf(player) ~= request.identifier then
        open[playerId] = nil
        return abandon(playerId, request, "dropped")
    end

    if type(method) ~= "string" or not request.allowed[method] then
        return answer(playerId, request.id, false, nil, "method_unavailable", Account.balances(player))
    end

    -- Claimed before any money moves: whatever happens below, it cannot be paid twice.
    open[playerId] = nil
    local charged, failure = Account.charge(player, playerId, Config.Accounts[method], request.amount, request.title)
    if not charged then
        if not reopen(playerId, request) then return end
        local reason = failure == "insufficient" and "insufficient_" .. method or "payment_failed"
        return answer(playerId, request.id, false, nil, reason, Account.balances(player))
    end

    answer(playerId, request.id, true, method, nil, Account.balances(player))
    TriggerEvent("esx_paymentgateway:paid", {
        playerId = playerId,
        identifier = request.identifier,
        id = request.id,
        amount = request.amount,
        method = method,
        account = Config.Accounts[method],
        title = request.title,
        resource = request.resource,
    })
    report(playerId, request, true, method, "paid")
end

---Ends a payment the player walked away from.
---@param playerId integer
---@param id any Payment id from the client
function Payment.cancel(playerId, id)
    local request = take(playerId, id)
    if request then report(playerId, request, false, nil, "cancelled") end
end

---Ends a payment for the resource that opened it, e.g. when the player walks away from a shop.
---@param playerId any
---@param resource? string Resource that asks
---@return boolean cancelled
function Payment.cancelFor(playerId, resource)
    local request = open[playerId]
    if not request or request.resource ~= resource then return false end
    open[playerId] = nil
    abandon(playerId, request, "cancelled")
    return true
end

return Payment
