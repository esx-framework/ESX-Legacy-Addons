-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- /testpayment on the client: opens the dialog the server asked for and lets the server charge
--- the chosen method, the same way a shop would. By default the server is asked from inside the
--- dialog, which then shows the receipt; with "select" the dialog closes on the pick and the
--- answer comes as a notification. Only loaded when Config.TestCommand is on.

local Payment = require "client.module.payment.main"

---Asks the server to charge the test it opened. The amount stays on the server.
---@param account string ESX account the player chose
---@return table result ok, and reason or reference
local function charge(account)
    return xLib.callback.await("esx_paymentgateway:testCharge", false, account)
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
            local account, reason = Payment.request(request, charge, owner)
            return print(("[esx_paymentgateway] test payment: %s"):format(account or reason))
        end

        local account, reason = Payment.request(request, nil, owner)
        if not account then
            return print(("[esx_paymentgateway] test payment: %s"):format(reason))
        end

        -- A callback that fails or times out may still have charged.
        local answered, result = pcall(charge, account)
        if not answered then
            return ESX.ShowNotification(TranslateCap("payment_unconfirmed"), "error")
        end

        if type(result) == "table" and result.ok == true then
            local method = Payment.methodOf(account)
            ESX.ShowNotification(TranslateCap("test_paid", test.amount, method and Translate("ui_" .. method) or account), "success")
        else
            local code = type(result) == "table" and result.reason
            ESX.ShowNotification(Payment.failureText(account, code) or TranslateCap("payment_failed"), "error")
        end
    end)
end)
