-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- Client entry: the export other resources open the payment dialog with. README.md documents
--- it and EXAMPLES.md shows it in use.

local Payment = require "client.module.payment.main"
local Validate = require "shared.module.validate.main"

Validate.config()

---Opens the payment dialog and waits for the player; call it from a thread. Without onPay the
---dialog closes as soon as the player picks a method. With it, the dialog waits while onPay sells
---on your server and shows the receipt or the refusal.
---@param request table amount, title, description?, currency?, methods?
---@param onPay? fun(method: PaymentMethod): boolean|table, string|table|nil
---@return PaymentMethod|nil method
---@return string|nil reason
exports("RequestPayment", function(request, onPay)
    return Payment.request(request, onPay, GetInvokingResource())
end)

AddEventHandler("esx:onPlayerDeath", function()
    Payment.cancel()
end)

ESX.SecureNetEvent("esx:onPlayerLogout", function()
    Payment.cancel()
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then
        return Payment.forgetResource(resource)
    end
    if Payment.isOpen() then SetNuiFocus(false, false) end
end)

if Config.TestCommand then
    require "client.module.test.main"
end
