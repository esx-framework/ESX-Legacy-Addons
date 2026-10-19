-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- /testpayment on the client: opens the dialog the server asked for and lets the server charge
--- the chosen method, the same way a shop would. By default the server is asked from inside the
--- dialog, which then shows the receipt; with "select" the dialog closes on the pick and the
--- answer comes as a notification. Only loaded when Config.TestCommand is on.

local Payment = require "client.module.payment.main"

---@param amount integer
---@param method PaymentMethod
---@return table result ok, and reason or reference
local function charge(amount, method)
    return xLib.callback.await("esx_paymentgateway:testCharge", false, amount, method)
end

ESX.SecureNetEvent("esx_paymentgateway:test", function(test)
    if type(test) ~= "table" then return end

    local request = {
        amount = test.amount,
        title = "Test payment",
        description = "esx_paymentgateway",
        methods = test.methods,
    }
    local owner = GetCurrentResourceName()

    CreateThread(function()
        if not test.select then
            local method, reason = Payment.request(request, function(method)
                return charge(test.amount, method)
            end, owner)
            return print(("[esx_paymentgateway] test payment: %s"):format(method or reason))
        end

        local method, reason = Payment.request(request, nil, owner)
        if not method then
            return print(("[esx_paymentgateway] test payment: %s"):format(reason))
        end

        local result = charge(test.amount, method)
        if type(result) == "table" and result.ok then
            ESX.ShowNotification(TranslateCap("test_paid", test.amount, Translate("ui_" .. method)), "success")
        else
            local reason = type(result) == "table" and result.reason
            ESX.ShowNotification(Payment.failureText(method, reason) or TranslateCap("payment_failed"), "error")
        end
    end)
end)
