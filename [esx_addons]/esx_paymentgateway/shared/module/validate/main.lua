-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- Checks both sides share: what counts as a text, an amount and a balance, and the config,
--- which the client reads as much as the server does. Money goes through xLib.validation, so the
--- gateway takes the same amounts xPlayer.chargeAccount does.

local Validate = {}

--- Bounds the page holds these config values to as well.
local MIN_PAY_TIMEOUT <const> = 3
local MAX_PAY_TIMEOUT <const> = 300
local MAX_CLOSE_DELAY <const> = 30000

---@param message string
local function warn(message)
    print(("[^3WARNING^7] esx_paymentgateway: %s"):format(message))
end

---A finite number within bounds; a string that reads as one does not count.
---@param value any
---@param min number
---@param max? number
---@return boolean
local function isNumber(value, min, max)
    return type(value) == "number" and xLib.validation.number(value, min, max) ~= nil
end

---Non-blank UTF-8 text of at most maxLength bytes.
---@param value any
---@param maxLength integer
---@return boolean
function Validate.isText(value, maxLength)
    return type(value) == "string" and #value <= maxLength and value:find("%S") ~= nil and utf8.len(value) ~= nil
end

---A price: a whole number from 1 up, as xPlayer.chargeAccount takes it. validation.money rounds,
---so a value it changes was never one.
---@param value any
---@return boolean
function Validate.isAmount(value)
    local amount = xLib.validation.money(value, 1)
    return amount ~= nil and amount == value
end

---A balance as the dialog shows it: whole units rounded down, 0 for anything that is no money.
---@param value any
---@return integer
function Validate.balance(value)
    local number = tonumber(value)
    return number and xLib.validation.money(math.floor(number)) or 0
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

    -- Requests and answers name a method by its account, so no two methods may share one.
    local methods, taken = {}, {}
    for _, method in ipairs(type(Config.Methods) == "table" and Config.Methods or {}) do
        local account = Config.Accounts[method]
        if not account then
            warn(("Config.Methods lists %s, which has no account in Config.Accounts; ignored"):format(method))
        elseif taken[account] then
            warn(("Config.Methods lists %s, but %s already takes the account %s; ignored"):format(method, taken[account], account))
        else
            taken[account] = method
            methods[#methods + 1] = method
        end
    end
    if #methods == 0 then
        warn("Config.Methods names no method with an account; payments cannot open")
    end
    Config.Methods = methods

    if not Validate.isText(Config.Currency, 4) then
        warn("Config.Currency must be a short symbol, using $")
        Config.Currency = "$"
    end
    if not isNumber(Config.HoldAmount, 0) then
        warn("Config.HoldAmount must be 0 or more, turning holding off")
        Config.HoldAmount = 0
    end
    if not isNumber(Config.PayTimeout, MIN_PAY_TIMEOUT, MAX_PAY_TIMEOUT) then
        warn(("Config.PayTimeout must be %s to %s seconds, using 20"):format(MIN_PAY_TIMEOUT, MAX_PAY_TIMEOUT))
        Config.PayTimeout = 20
    end
    if not isNumber(Config.CloseDelay, 0, MAX_CLOSE_DELAY) then
        warn(("Config.CloseDelay must be 0 to %s milliseconds, using 2600"):format(MAX_CLOSE_DELAY))
        Config.CloseDelay = 2600
    end
    if not isNumber(Config.Volume, 0, 1) then
        warn("Config.Volume must be 0 to 1, using 0.5")
        Config.Volume = 0.5
    end
    if type(Config.TestCommand) ~= "boolean" then
        warn("Config.TestCommand must be true or false, turning it off")
        Config.TestCommand = false
    end
end

return Validate
