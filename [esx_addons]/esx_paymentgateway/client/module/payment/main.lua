-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- The payment dialog. Other resources open it with the RequestPayment export, the player picks
--- a method, and the export returns it. The dialog never moves money and keeps nothing once it
--- closes: checking the purchase and taking the money is the job of the resource that asked,
--- on its own server. Focus is only taken once the page says it shows the payment, so a page
--- that cannot show it never locks the player.

local Request = require "client.module.payment.request"

local Payment = {}

--- Dialog texts the page uses; each comes from the locale key "ui_" .. key.
local LABEL_KEYS <const> = {
    "heading", "choose", "total", "cash", "card", "remaining", "short", "pay_cash", "pay_card",
    "hold_cash", "hold_card", "unaffordable", "unreachable", "processing", "cancel", "success",
    "paid_with", "new_balance", "reference", "done",
}

---@class OpenPayment
---@field id integer Id of the dialog, so answers for an older one are ignored
---@field allowed table<PaymentMethod, boolean> Methods the dialog offers
---@field owner? string Resource that opened it
---@field done table Promise the export waits on

--- The payment on screen, nil while the dialog is closed.
---@type OpenPayment|nil
local current = nil
local lastId = 0

---@return table<string, string>
local function labels()
    local result = {}
    for i = 1, #LABEL_KEYS do
        local key = LABEL_KEYS[i]
        result[key] = Translate("ui_" .. key)
    end
    return result
end

---The player's money per method, as ESX last told this client. Only shown; the resource that
---charges checks the real balance on its server.
---@return table<PaymentMethod, number>
local function balances()
    local result = { cash = 0, card = 0 }
    local data = ESX.GetPlayerData()
    local accounts = type(data) == "table" and data.accounts
    if type(accounts) ~= "table" then return result end

    for _, account in pairs(accounts) do
        for method, name in pairs(Config.Accounts) do
            if type(account) == "table" and account.name == name then
                result[method] = math.max(0, tonumber(account.money) or 0)
            end
        end
    end
    return result
end

---Ends the payment on screen and wakes the resource that waits for it.
---@param method PaymentMethod|nil Method the player chose, nil when they did not
---@param reason? string Why not
local function finish(method, reason)
    local payment = current
    if not payment then return end
    current = nil
    payment.done:resolve({ method = method, reason = reason })
end

---Opens the dialog and waits until the player chose a method or walked away.
---@param input any Request from the export
---@param owner? string Resource that asked
---@return PaymentMethod|nil method
---@return string|nil reason Why there is no method: "cancelled", "busy" or what is wrong with the request
function Payment.request(input, owner)
    if current then return nil, "busy" end
    if not ESX.IsPlayerLoaded() then return nil, "The player is not loaded." end

    local request, reason = Request.normalize(input)
    if not request then return nil, reason end

    lastId = lastId + 1
    local payment = { id = lastId, allowed = request.allowed, owner = owner, done = promise.new() }
    current = payment

    xLib.nui.send({
        action = "open",
        payment = {
            id = payment.id,
            amount = request.amount,
            currency = request.currency,
            title = request.title,
            description = request.description,
            methods = request.methods,
            balances = balances(),
            hold = Config.HoldAmount > 0 and request.amount >= Config.HoldAmount,
        },
        theme = xLib.colors.getESXTheme(),
        labels = labels(),
        locale = Config.Locale,
        closeDelay = Config.CloseDelay,
        volume = Config.Volume,
    })

    local outcome = Citizen.Await(payment.done)
    return outcome.method, outcome.reason
end

---Closes the dialog from this side, e.g. when the player dies or logs out.
function Payment.cancel()
    if not current then return end
    xLib.nui.close({ action = "close" })
    finish(nil, "cancelled")
end

---Closes the dialog when the resource that opened it stops; nobody is left to hear the answer.
---@param resource string
function Payment.forgetResource(resource)
    if current and current.owner == resource then Payment.cancel() end
end

---@return boolean
function Payment.isOpen()
    return current ~= nil
end

xLib.nui.register("shown", function(data)
    if current and data.id == current.id then xLib.nui.focus(true, true) end
    return xLib.nui.ok()
end)

xLib.nui.register("pay", function(data)
    local payment = current
    if payment and data.id == payment.id and payment.allowed[data.method] then
        xLib.nui.close({ action = "close" })
        finish(data.method)
    end
    return xLib.nui.ok()
end)

xLib.nui.register("close", function(data)
    if current and data.id == current.id then finish(nil, "cancelled") end
    xLib.nui.focus(false, false)
    return xLib.nui.ok()
end)

return Payment
