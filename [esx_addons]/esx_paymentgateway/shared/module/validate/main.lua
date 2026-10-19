-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- Checks both sides share: what counts as a text and an amount, and the config, which the
--- client reads as much as the server does.

local Validate = {}

--- Largest amount; above it doubles lose whole units.
Validate.MAX_AMOUNT = 9007199254740991

---@param message string
local function warn(message)
    print(("[^3WARNING^7] esx_paymentgateway: %s"):format(message))
end

---@param value any
---@param maxLength integer
---@return boolean
function Validate.isText(value, maxLength)
    return type(value) == "string" and value:find("%S") ~= nil and #value <= maxLength
end

---@param value any
---@return boolean
function Validate.isAmount(value)
    return type(value) == "number" and value >= 1 and value <= Validate.MAX_AMOUNT and value % 1 == 0
end

---Checks the config once at start and puts back defaults for anything that would break a
---payment at runtime, with a warning for each.
function Validate.config()
    if type(Config.Accounts) ~= "table" then
        warn("Config.Accounts must be a table, using cash = money and card = bank")
        Config.Accounts = { cash = "money", card = "bank" }
    end
    for method, account in pairs(Config.Accounts) do
        if (method ~= "cash" and method ~= "card") or not Validate.isText(account, 64) then
            warn(("Config.Accounts.%s is not a known method with an account name, ignored"):format(method))
            Config.Accounts[method] = nil
        end
    end

    local methods = {}
    for _, method in ipairs(type(Config.Methods) == "table" and Config.Methods or {}) do
        if Config.Accounts[method] then methods[#methods + 1] = method end
    end
    if #methods == 0 then
        warn("Config.Methods names no method with an account; payments cannot open")
    end
    Config.Methods = methods

    if not Validate.isText(Config.Currency, 4) then
        warn("Config.Currency must be a short symbol, using $")
        Config.Currency = "$"
    end
    if type(Config.HoldAmount) ~= "number" or Config.HoldAmount < 0 then
        warn("Config.HoldAmount must be 0 or more, turning holding off")
        Config.HoldAmount = 0
    end
end

return Validate
