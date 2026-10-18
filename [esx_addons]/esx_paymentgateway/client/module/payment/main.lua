-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- The payment dialog on the client: opens the page with the server's payment, the theme
--- and the texts, passes the player's choice to the server and its answer back to the page.
--- The page reports through its `pay` and `close` callbacks.

local Payment = {}

--- Dialog texts the page uses; each comes from the locale key "ui_" .. key.
local LABEL_KEYS <const> = {
    "heading", "choose", "total", "cash", "card", "remaining", "short", "pay_cash", "pay_card",
    "hold_cash", "hold_card", "unaffordable", "unreachable", "processing", "cancel", "success",
    "paid_with", "new_balance", "reference", "done",
}

--- Id of the payment on screen, nil while the dialog is closed.
---@type integer|nil
local current = nil
--- Whether the payment on screen went through, so closing it is no cancel.
local settled = false

---@return table<string, string>
local function labels()
    local result = {}
    for i = 1, #LABEL_KEYS do
        local key = LABEL_KEYS[i]
        result[key] = Translate("ui_" .. key)
    end
    return result
end

---Opens the dialog with a payment the server opened.
---@param payment table
function Payment.open(payment)
    current = payment.id
    settled = false
    xLib.nui.open({
        action = "open",
        payment = payment,
        theme = xLib.colors.getESXTheme(),
        labels = labels(),
        locale = Config.Locale,
        closeDelay = Config.CloseDelay,
        volume = Config.Volume,
    })
end

---Passes the server's answer to the page.
---@param result table
function Payment.result(result)
    if result.id ~= current then return end
    settled = result.ok == true
    xLib.nui.send({
        action = "result",
        result = {
            id = result.id,
            ok = result.ok,
            method = result.method,
            message = result.error and TranslateCap(result.error) or nil,
            balances = result.balances,
        },
    })
end

---Closes the dialog because the server ended the payment.
---@param reason? string Locale key to tell the player why
function Payment.close(reason)
    if not current then return end
    current = nil
    xLib.nui.close({ action = "close" })
    if reason then ESX.ShowNotification(TranslateCap(reason), "error") end
end

---Closes the dialog from this side, e.g. when the player dies, and tells the server.
function Payment.cancel()
    if not current then return end
    if not settled then TriggerServerEvent("esx_paymentgateway:cancel", current) end
    current = nil
    xLib.nui.close({ action = "close" })
end

---@return boolean
function Payment.isOpen()
    return current ~= nil
end

xLib.nui.register("pay", function(data)
    if current and data.id == current and not settled then
        TriggerServerEvent("esx_paymentgateway:pay", current, data.method)
    end
    return xLib.nui.ok()
end)

xLib.nui.register("close", function(data)
    if current and data.id == current then
        if not settled then TriggerServerEvent("esx_paymentgateway:cancel", current) end
        current = nil
    end
    xLib.nui.focus(false, false)
    return xLib.nui.ok()
end)

return Payment
