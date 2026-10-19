-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- Server entry: Charge and Refund, which the resource that sells something calls after its own
--- checks. The dialog itself lives on the client. README.md documents both exports and
--- EXAMPLES.md shows them in use.

local Account = require "server.module.account.main"
local Validate = require "shared.module.validate.main"

Validate.config()

---Takes the price of a purchase for the method the player chose. Call it from your own server
---code, after checking price, stock and everything else the purchase depends on.
---@param playerId integer
---@param method PaymentMethod
---@param amount integer
---@param reason? string Shown in ESX's account logs
---@return boolean charged
---@return ChargeFailure|nil failure
---@return string|nil message Why, ready to show the player
exports("Charge", function(playerId, method, amount, reason)
    return Account.charge(playerId, method, amount, reason, GetInvokingResource())
end)

---Gives money back, e.g. when what was paid for could not be handed over.
---@param playerId integer
---@param method PaymentMethod
---@param amount integer
---@param reason? string Shown in ESX's account logs
---@return boolean refunded
exports("Refund", function(playerId, method, amount, reason)
    return Account.refund(playerId, method, amount, reason)
end)

if Config.TestCommand then
    require "server.module.test.main"
end
