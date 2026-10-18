-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

---@alias PaymentMethod "cash"|"card"

Config = {}

Config.Locale = GetConvar("esx:locale", "en")

--- ESX account each payment method takes the money from.
---@type table<PaymentMethod, string>
Config.Accounts = {
    cash = "money",
    card = "bank",
}

--- Order the methods are listed in, and the methods a request gets when it names none.
---@type PaymentMethod[]
Config.Methods = { "cash", "card" }

--- Currency symbol shown before amounts when a request names none.
Config.Currency = "$"

--- Payments of at least this amount have to be held to confirm; 0 turns holding off.
Config.HoldAmount = 50000

--- Seconds a payment stays open before it expires and the dialog closes.
Config.Timeout = 120

--- Milliseconds the receipt stays before the dialog closes itself; 0 waits for the player.
Config.CloseDelay = 2600

--- Volume of the dialog's sounds, 0 silent to 1 full.
Config.Volume = 0.5
