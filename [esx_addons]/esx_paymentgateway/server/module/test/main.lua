-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- /testpayment for admins: opens the dialog on themselves to try amounts, methods and the
--- server theme. Only loaded when Config.TestCommand is on.

local Payment = require "server.module.payment.main"

local RESULT_EVENT <const> = "esx_paymentgateway:testResult"

ESX.RegisterCommand("testpayment", "admin", function(xPlayer, args, showError)
    local amount = tonumber(args.amount)
    if not amount or amount < 1 or amount % 1 ~= 0 then
        return showError(TranslateCap("command_invalid_amount"))
    end

    local methods = (args.method == "cash" or args.method == "card") and { args.method } or nil
    local opened, reason = Payment.request(xPlayer.source, {
        amount = amount,
        title = "Test payment",
        description = "esx_paymentgateway",
        methods = methods,
        resultEvent = RESULT_EVENT,
    }, GetCurrentResourceName())

    if not opened then showError(reason) end
end, false, {
    help = TranslateCap("command_testpayment"),
    arguments = {
        { name = "amount", help = TranslateCap("command_amount"), type = "any" },
        { name = "method", help = TranslateCap("command_method"), type = "any" },
    },
})

--- A local server event, so clients cannot fake a result.
AddEventHandler(RESULT_EVENT, function(playerId, success, method, request, reason)
    print(("[esx_paymentgateway] test payment of %s for player %s: %s (%s, %s)"):format(
        request.amount, playerId, success and "paid" or "not paid", method or "no method", reason))
end)
