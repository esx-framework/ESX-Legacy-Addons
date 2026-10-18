-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- Server entry: the exports other resources open and cancel payments with, and the player's
--- answers from the dialog.

local Payment = require "server.module.payment.main"

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

RegisterNetEvent("esx_paymentgateway:cancel", function(id)
    Payment.cancel(source --[[@as integer]], id)
end)
