-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- Payments the server holds open: one per player, bound to the character it was opened for and
--- settled by the method the player picks. Amount, balances and outcome are decided here; the
--- client only names a method.

local Account = require "server.module.account.main"
local Util = require "server.module.payment.util"

local Payment = {}

--- How a payment ended, as the requester hears it.
---@alias PaymentOutcome "cancelled"|"expired"

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
