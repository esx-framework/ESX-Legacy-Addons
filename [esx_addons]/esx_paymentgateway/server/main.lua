-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- Server entry: the exports other resources open and cancel payments with, and the player's
--- answers from the dialog.

local Payment = require "server.module.payment.main"
local Util = require "server.module.payment.util"

Util.checkConfig()

--- Pay attempts a player may make in a burst; refusals let them try another method.
local limiter = xLib.rateLimiter({ capacity = 4, refill = 1, interval = 1000, staleMs = 60000 })

---Opens the payment dialog for a player.
---@param playerId integer Server id of the player who pays
---@param request table amount, title, description?, currency?, methods?, resultEvent?
---@param onResult? fun(playerId: integer, success: boolean, method: string|nil, request: table, outcome: string)
---@return boolean opened
---@return integer|string|nil detail Payment id when it opened, the reason when it did not
exports("RequestPayment", function(playerId, request, onResult)
    return Payment.request(playerId, request, GetInvokingResource(), onResult)
end)

---Ends a player's open payment; only the resource that opened it may.
---@param playerId integer
---@return boolean cancelled
exports("CancelPayment", function(playerId)
    return Payment.cancelFor(playerId, GetInvokingResource())
end)

RegisterNetEvent("esx_paymentgateway:pay", function(id, method)
    local playerId = source --[[@as integer]]
    if not limiter:consume(playerId) then return end
    Payment.pay(playerId, id, method)
end)

RegisterNetEvent("esx_paymentgateway:cancel", function(id)
    Payment.cancel(source --[[@as integer]], id)
end)

--- ESX fires this when a player leaves and when they log out of their character.
AddEventHandler("esx:playerDropped", function(playerId)
    Payment.drop(playerId)
end)

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        Payment.stopAll()
    else
        Payment.forgetResource(resource)
    end
end)

if Config.TestCommand then
    require "server.module.test.main"
end
