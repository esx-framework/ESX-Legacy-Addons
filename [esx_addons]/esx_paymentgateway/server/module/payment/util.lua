-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- Checks of the requests other resources pass to the RequestPayment export. A request is
--- turned into a clean PaymentRequest or refused with the reason the export returns.

---@class PaymentRequest
---@field id integer Server id of the payment, set when it opens
---@field amount integer Price in whole currency units
---@field currency string Symbol shown before the amount
---@field title string What is paid for
---@field description? string Who is paid or further detail
---@field methods PaymentMethod[] Methods offered, in dialog order
---@field allowed table<PaymentMethod, boolean> The same methods as a set
---@field resultEvent? string Server event fired when the payment ends
---@field onResult? function Function the requester passed, called when the payment ends
---@field resource? string Resource that asked for the payment
---@field identifier? string ESX identifier of the character the payment was opened for
---@field expiresAt? integer GetGameTimer() value at which the payment expires

local Util = {}

--- Longest title and description, in bytes.
local MAX_TEXT <const> = 120
--- Longest currency symbol, in bytes.
local MAX_CURRENCY <const> = 4
--- Largest amount; above it doubles lose whole units.
local MAX_AMOUNT <const> = 9007199254740991
--- Event names a request may give: plain resource:side:action style names.
local EVENT_PATTERN <const> = "^[%w_%-%.:]+$"

---@param value any
---@param maxLength integer
---@return boolean
local function isText(value, maxLength)
    return type(value) == "string" and value:find("%S") ~= nil and #value <= maxLength
end

---@param value any
---@return boolean
local function isAmount(value)
    return type(value) == "number" and value >= 1 and value <= MAX_AMOUNT and value % 1 == 0
end

---Keeps the configured methods a list names, each once, in the configured order.
---@param value any Methods from the request
---@return PaymentMethod[] methods
---@return table<PaymentMethod, boolean> allowed
function Util.methods(value)
    local wanted = {}
    if type(value) == "table" then
        for _, method in ipairs(value) do
            wanted[method] = true
        end
    end

    local methods, allowed = {}, {}
    for _, method in ipairs(Config.Methods) do
        if Config.Accounts[method] and (type(value) ~= "table" or wanted[method]) then
            methods[#methods + 1] = method
            allowed[method] = true
        end
    end
    return methods, allowed
end

---Whether a value can be called: a function, or a function reference from another resource,
---which arrives as a table with a __call metamethod.
---@param value any
---@return boolean
function Util.isCallable(value)
    if type(value) == "function" then return true end
    local meta = type(value) == "table" and getmetatable(value)
    return type(meta) == "table" and meta.__call ~= nil
end

---Turns the table a resource passed into a payment request.
---@param input any Request from the export
---@return PaymentRequest|nil request
---@return string|nil reason Why the request was refused
function Util.normalize(input)
    if type(input) ~= "table" then return nil, "The request must be a table." end
    if not isAmount(input.amount) then return nil, "Amount must be a positive whole number." end
    if not isText(input.title, MAX_TEXT) then return nil, "A payment title is required." end

    local methods, allowed = Util.methods(input.methods)
    if #methods == 0 then return nil, "None of the requested methods is available." end

    local resultEvent = input.resultEvent
    if resultEvent ~= nil and not (isText(resultEvent, 128) and resultEvent:match(EVENT_PATTERN)) then
        return nil, "resultEvent must be an event name."
    end

    return {
        id = 0,
        amount = math.tointeger(input.amount) or input.amount,
        currency = isText(input.currency, MAX_CURRENCY) and input.currency or Config.Currency,
        title = input.title,
        description = isText(input.description, MAX_TEXT) and input.description or nil,
        methods = methods,
        allowed = allowed,
        resultEvent = resultEvent,
    }
end

---The part of a request the requester gets back with the result.
---@param request PaymentRequest
---@return table
function Util.public(request)
    return {
        id = request.id,
        amount = request.amount,
        currency = request.currency,
        title = request.title,
        description = request.description,
        methods = request.methods,
    }
end

return Util
