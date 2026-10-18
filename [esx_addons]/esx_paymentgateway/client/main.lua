-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- Client entry: shows the payments the server opens. The server decides everything; this side
--- only shows the dialog and passes the player's choice on.

local Payment = require "client.module.payment.main"

ESX.SecureNetEvent("esx_paymentgateway:open", function(payment)
    if type(payment) ~= "table" then return end
    Payment.open(payment)
end)

ESX.SecureNetEvent("esx_paymentgateway:result", function(result)
    if type(result) ~= "table" then return end
    Payment.result(result)
end)

ESX.SecureNetEvent("esx_paymentgateway:close", function(reason)
    Payment.close(type(reason) == "string" and reason or nil)
end)

AddEventHandler("esx:onPlayerDeath", function()
    Payment.cancel()
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if Payment.isOpen() then SetNuiFocus(false, false) end
end)
