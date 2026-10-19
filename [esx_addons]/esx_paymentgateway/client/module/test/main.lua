-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- /testpayment on the client: opens the dialog the server asked for, then lets the server charge
--- the chosen method, the same way a shop would. Only loaded when Config.TestCommand is on.

local Payment = require "client.module.payment.main"

ESX.SecureNetEvent("esx_paymentgateway:test", function(test)
    if type(test) ~= "table" then return end

    CreateThread(function()
        local method, reason = Payment.request({
            amount = test.amount,
            title = "Test payment",
            description = "esx_paymentgateway",
            methods = test.methods,
        }, GetCurrentResourceName())
        if not method then
            return print(("[esx_paymentgateway] test payment not paid: %s"):format(reason))
        end

        local result = xLib.callback.await("esx_paymentgateway:testCharge", false, test.amount, method)
        if type(result) == "table" and result.ok then
            ESX.ShowNotification(TranslateCap("test_paid", test.amount, Translate("ui_" .. method)), "success")
        else
            ESX.ShowNotification(type(result) == "table" and result.message or TranslateCap("payment_failed"), "error")
        end
    end)
end)
