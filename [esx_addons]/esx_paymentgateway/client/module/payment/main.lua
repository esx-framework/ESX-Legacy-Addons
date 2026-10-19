-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- The payment dialog. Other resources open it with the RequestPayment export and the player
--- picks a method. Resources name methods by their ESX account; the page only knows how each one
--- looks, cash or card. Without a handler the dialog closes on that pick and the export returns
--- the account. With one, the dialog waits while the handler asks the caller's server to sell, then
--- shows the receipt or the refusal. Either way the dialog never moves money and keeps nothing
--- once it closes: checking the purchase and taking the money is the job of the resource that
--- asked, on its own server. Focus is only taken once the page says it shows the payment, so a
--- page that cannot show it never locks the player.

local Request = require "client.module.payment.request"
local Validate = require "shared.module.validate.main"

local Payment = {}

--- Dialog texts the page uses; each comes from the locale key "ui_" .. key.
local LABEL_KEYS <const> = {
    "heading", "choose", "total", "cash", "card", "remaining", "short", "pay_cash", "pay_card",
    "hold_cash", "hold_card", "unaffordable", "unreachable", "processing", "cancel", "success",
    "paid_with", "new_balance", "reference", "done",
}

--- Longest refusal text and receipt reference a handler may hand back, in bytes.
local MAX_MESSAGE <const> = 120
local MAX_REFERENCE <const> = 40

--- Locale key of the text for each failure code of xPlayer.chargeAccount, except
--- insufficient_funds, whose text depends on the method.
local FAILURE_KEYS <const> = {
    invalid_account = "method_unavailable",
    invalid_amount = "payment_failed",
    session_closing = "payment_failed",
    failed = "payment_failed",
}

---@class OpenPayment
---@field id integer Id of the dialog, so answers for an older one are ignored
---@field allowed table<PaymentMethod, boolean> Methods the dialog offers
---@field onPay? function Handler of the resource that opened it
---@field owner? string Resource that opened it
---@field done table Promise the export waits on
---@field paying? boolean Whether the handler is running
---@field paid? PaymentMethod Method the handler sold with
---@field closed? boolean Whether the dialog was closed while the handler ran

--- The payment on screen, nil while the dialog is closed.
---@type OpenPayment|nil
local current = nil
local lastId = 0

---@param message string
local function warn(message)
    print(("[^3WARNING^7] esx_paymentgateway: %s"):format(message))
end

---@return table<string, string>
local function labels()
    local result = {}
    for i = 1, #LABEL_KEYS do
        local key = LABEL_KEYS[i]
        result[key] = Translate("ui_" .. key)
    end
    return result
end

---The way to pay that stands for an ESX account.
---@param account any
---@return PaymentMethod|nil
function Payment.methodOf(account)
    for method, name in pairs(Config.Accounts) do
        if name == account then return method end
    end
    return nil
end

---Text for the player about a failure code of xPlayer.chargeAccount.
---@param account string ESX account the charge was for
---@param code any
---@return string|nil text Nil when the value is no such code
function Payment.failureText(account, code)
    if code == "insufficient_funds" then
        local method = Payment.methodOf(account)
        return Translate(method and "insufficient_" .. method or "payment_failed")
    end
    local key = FAILURE_KEYS[code]
    return key and Translate(key) or nil
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
---@param method PaymentMethod|nil Method the player paid with, nil when they did not
---@param reason? string Why not
local function finish(method, reason)
    local payment = current
    if not payment then return end
    current = nil
    payment.done:resolve({ account = method and Config.Accounts[method], reason = reason })
end

---Runs the handler for the chosen method and waits for it, but no longer than
---Config.PayTimeout. The handler cannot be stopped; after the timeout its answer is ignored.
---@param payment OpenPayment
---@param method PaymentMethod
---@return table answer `timeout`, or `ok` from pcall with what the handler returned
local function ask(payment, method)
    local answer = promise.new()
    local settled = false
    local function settle(value)
        if settled then return end
        settled = true
        answer:resolve(value)
    end

    CreateThread(function()
        settle(table.pack(pcall(payment.onPay, Config.Accounts[method])))
    end)
    SetTimeout(Config.PayTimeout * 1000, function()
        settle({ timeout = true })
    end)
    return Citizen.Await(answer)
end

---Reads what the handler returned: true, false and a reason, or a result table as server
---callbacks usually send it. A refusal may name a failure code of xPlayer.chargeAccount instead
---of a text; a text the handler wrote itself wins.
---@param payment OpenPayment
---@param method PaymentMethod
---@param answer table From ask
---@return "paid"|"refused"|"unconfirmed" verdict
---@return string|nil detail The refusal text or the receipt reference
local function verdictOf(payment, method, answer)
    if answer.timeout then
        warn(("the payment handler of %s did not answer within %ss"):format(payment.owner, Config.PayTimeout))
        return "unconfirmed"
    end
    if not answer[1] then
        warn(("the payment handler of %s failed: %s"):format(payment.owner, answer[2]))
        return "unconfirmed"
    end

    local ok, detail = answer[2], answer[3]
    if type(ok) == "table" then
        local result = ok
        ok = result.ok
        if ok == true then
            detail = result.reference
        elseif Validate.isText(result.message, MAX_MESSAGE) then
            detail = result.message
        else
            detail = Payment.failureText(Config.Accounts[method], result.reason)
        end
    elseif ok == true and type(detail) == "table" then
        detail = detail.reference
    elseif ok == false then
        detail = Payment.failureText(Config.Accounts[method], detail) or detail
    end

    if ok == true then
        return "paid", Validate.isText(detail, MAX_REFERENCE) and detail or nil
    end
    if ok == false then
        return "refused", Validate.isText(detail, MAX_MESSAGE) and detail or nil
    end
    warn(("the payment handler of %s returned neither true nor false"):format(payment.owner))
    return "unconfirmed"
end

---Lets the handler sell with the chosen method and shows how that went. Only a clear no lets
---the player try again; an error or no answer at all may have sold anyway, so the dialog closes
---instead of risking a second purchase.
---@param payment OpenPayment
---@param method PaymentMethod
local function sell(payment, method)
    payment.paying = true
    local verdict, detail = verdictOf(payment, method, ask(payment, method))
    payment.paying = false

    if verdict == "unconfirmed" then
        if not payment.closed then xLib.nui.close({ action = "close" }) end
        ESX.ShowNotification(TranslateCap("payment_unconfirmed"), "error")
        return finish(nil, "unconfirmed")
    end
    if payment.closed then
        return finish(verdict == "paid" and method or nil, verdict == "paid" and nil or "cancelled")
    end

    if verdict == "paid" then payment.paid = method end
    xLib.nui.send({
        action = "result",
        result = {
            id = payment.id,
            ok = verdict == "paid",
            method = verdict == "paid" and method or nil,
            message = verdict == "refused" and (detail or Translate("ui_unreachable")) or nil,
            reference = verdict == "paid" and detail or nil,
            balances = balances(),
        },
    })
end

---Opens the dialog and waits until the player paid or walked away. Without an account it
---returns false, not nil: the export sends its results through msgpack, which turns a leading
---nil into a hole and drops the reason behind it.
---@param input any Request from the export
---@param onPay? function Handler that sells with the chosen account
---@param owner? string Resource that asked
---@return string|false account ESX account of the method the player paid with
---@return string|nil reason Why there is none: "cancelled", "unconfirmed", "busy" or what is wrong with the request
function Payment.request(input, onPay, owner)
    if current then return false, "busy" end
    if not ESX.IsPlayerLoaded() then return false, "The player is not loaded." end
    if onPay ~= nil and not Request.isCallable(onPay) then return false, "onPay must be a function." end

    local request, reason = Request.normalize(input)
    if not request then return false, reason end

    lastId = lastId + 1
    local payment = { id = lastId, allowed = request.allowed, onPay = onPay, owner = owner, done = promise.new() }
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
    return outcome.account or false, outcome.reason
end

---Closes the dialog from this side, e.g. when the player dies or logs out. While the handler
---runs, the export still waits for its answer, since it may have sold already.
function Payment.cancel()
    local payment = current
    if not payment or payment.closed then return end
    xLib.nui.close({ action = "close" })
    if payment.paying then
        payment.closed = true
    else
        finish(payment.paid, not payment.paid and "cancelled" or nil)
    end
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
    if not payment or data.id ~= payment.id or not payment.allowed[data.method] then
        return xLib.nui.ok()
    end
    if not payment.onPay then
        xLib.nui.close({ action = "close" })
        finish(data.method)
    elseif not payment.paying and not payment.paid and not payment.closed then
        CreateThread(function() sell(payment, data.method) end)
    end
    return xLib.nui.ok()
end)

xLib.nui.register("close", function(data)
    local payment = current
    if payment and data.id == payment.id and not payment.closed then
        if payment.paying then
            payment.closed = true
        else
            finish(payment.paid, not payment.paid and "cancelled" or nil)
        end
    end
    xLib.nui.focus(false, false)
    return xLib.nui.ok()
end)

return Payment
