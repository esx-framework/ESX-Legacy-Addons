-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- Checks of the requests other resources pass to the RequestPayment export. A request is
--- turned into the payment the dialog shows, or refused with the reason the export returns.

local Validate = require "shared.module.validate.main"

local Request = {}

---@class PaymentRequest
---@field amount integer Price in whole currency units
---@field currency string Symbol shown before the amount
---@field title string What is paid for
---@field description? string Who is paid or further detail
---@field methods PaymentMethod[] Methods offered, in dialog order
---@field allowed table<PaymentMethod, boolean> The same methods as a set

--- Longest title and description, in bytes.
local MAX_TEXT <const> = 120
--- Longest currency symbol, in bytes.
local MAX_CURRENCY <const> = 4

---Keeps the configured methods a list names, each once, in the configured order.
---@param value any Methods from the request
---@return PaymentMethod[] methods
---@return table<PaymentMethod, boolean> allowed
local function methodsOf(value)
    local wanted = {}
    if type(value) == "table" then
        for _, method in ipairs(value) do
            wanted[method] = true
        end
    end

    local methods, allowed = {}, {}
    for _, method in ipairs(Config.Methods) do
        if type(value) ~= "table" or wanted[method] then
            methods[#methods + 1] = method
            allowed[method] = true
        end
    end
    return methods, allowed
end

---Turns the table a resource passed into the payment the dialog shows.
---@param input any Request from the export
---@return PaymentRequest|nil request
---@return string|nil reason Why the request was refused
function Request.normalize(input)
    if type(input) ~= "table" then return nil, "The request must be a table." end
    if not Validate.isAmount(input.amount) then return nil, "Amount must be a positive whole number." end
    if not Validate.isText(input.title, MAX_TEXT) then return nil, "A payment title is required." end

    local methods, allowed = methodsOf(input.methods)
    if #methods == 0 then return nil, "None of the requested methods is available." end

    return {
        amount = math.tointeger(input.amount) or input.amount,
        currency = Validate.isText(input.currency, MAX_CURRENCY) and input.currency or Config.Currency,
        title = input.title,
        description = Validate.isText(input.description, MAX_TEXT) and input.description or nil,
        methods = methods,
        allowed = allowed,
    }
end

return Request
