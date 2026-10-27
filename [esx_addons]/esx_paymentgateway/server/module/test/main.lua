-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- /testpayment for admins: opens the dialog on themselves and charges the amount with
--- xPlayer.chargeAccount, the way a shop would. Only loaded when Config.TestCommand is on. It
--- takes real money.

local Validate = require "shared.module.validate.main"

--- Counts test payments, for a receipt reference like a shop would give.
local tests = 0

--- Amount of the test each admin opened last. The charge takes it from here, the way a shop takes
--- its prices from its own data and never from the client.
---@type table<integer, integer>
local pending = {}

---Whether the dialog offers an ESX account as a way to pay.
---@param account any
---@return boolean
local function isOffered(account)
    for i = 1, #Config.Methods do
        if Config.Accounts[Config.Methods[i]] == account then return true end
    end
    return false
end

ESX.RegisterCommand("testpayment", "admin", function(xPlayer, args, showError)
    local amount = tonumber(args.amount)
    if not Validate.isAmount(amount) then
        return showError(TranslateCap("command_invalid_amount"))
    end
    local method = args.method ~= "both" and args.method or nil
    if method ~= nil and not isOffered(method) then
        return showError(TranslateCap("command_invalid_method"))
    end
    if args.mode ~= nil and args.mode ~= "select" then
        return showError(TranslateCap("command_invalid_mode"))
    end

    amount = math.tointeger(amount)
    pending[xPlayer.source] = amount
    TriggerClientEvent("esx_paymentgateway:test", xPlayer.source, {
        amount = amount,
        methods = method and { method } or nil,
        select = args.mode == "select",
    })
end, false, {
    help = TranslateCap("command_testpayment"),
    arguments = {
        { name = "amount", help = TranslateCap("command_amount"), type = "any" },
        { name = "method", help = TranslateCap("command_method"), type = "any" },
        { name = "mode", help = TranslateCap("command_mode"), type = "any" },
    },
})

--- The client only names the account, so this checks the command right and the account again;
--- anyone else could call it.
xLib.callback.register("esx_paymentgateway:testCharge", function(source, account)
    if not IsPlayerAceAllowed(tostring(source), "command.testpayment") then
        return { ok = false }
    end

    local amount = pending[source]
    local player = ESX.Player(source)
    if not amount or not player then return { ok = false } end
    if not isOffered(account) then return { ok = false, reason = "invalid_account" } end

    local charged, failure = player.chargeAccount(account, amount, "Test payment")
    print(("[esx_paymentgateway] test payment of %s for player %s from %s: %s"):format(
        amount, source, account, charged == true and "paid" or tostring(failure)))
    -- A player who left in between answers with nothing at all, so only true counts.
    if charged ~= true then return { ok = false, reason = failure } end

    pending[source] = nil
    tests = tests + 1
    return { ok = true, reference = ("TEST-%04d"):format(tests) }
end)

AddEventHandler("playerDropped", function()
    pending[tonumber(source)] = nil
end)
