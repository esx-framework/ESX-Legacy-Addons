-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- /testpayment for admins: opens the dialog on themselves and charges the amount with
--- xPlayer.chargeAccount, the way a shop would. Only loaded when Config.TestCommand is on. It
--- takes real money.

--- Counts test payments, for a receipt reference like a shop would give.
local tests = 0

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
    if not amount or amount < 1 or amount % 1 ~= 0 then
        return showError(TranslateCap("command_invalid_amount"))
    end

    TriggerClientEvent("esx_paymentgateway:test", xPlayer.source, {
        amount = amount,
        methods = isOffered(args.method) and { args.method } or nil,
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

--- The client names amount and method, so this checks the command right and both values again;
--- anyone else could call it.
xLib.callback.register("esx_paymentgateway:testCharge", function(source, amount, account)
    if not IsPlayerAceAllowed(tostring(source), "command.testpayment") then
        return { ok = false }
    end

    local player = ESX.Player(source)
    if not isOffered(account) or not player then return { ok = false, reason = "invalid_account" } end

    local charged, failure = player.chargeAccount(account, amount, "Test payment")
    print(("[esx_paymentgateway] test payment of %s for player %s from %s: %s"):format(
        amount, source, account, charged and "paid" or failure))
    if not charged then return { ok = false, reason = failure } end
    tests = tests + 1
    return { ok = true, reference = ("TEST-%04d"):format(tests) }
end)
