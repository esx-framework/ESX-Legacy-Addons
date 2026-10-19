-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- How the dialog shows a way to pay. Resources name a method by its ESX account instead.
---@alias PaymentMethod "cash"|"card"

Config = {}

Config.Locale = GetConvar("esx:locale", "en")

--- ESX account behind each way to pay, one account per way. RequestPayment takes and returns
--- these account names, so a seller hands the result straight to xPlayer.chargeAccount.
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

--- Seconds the dialog waits for a payment handler before it gives up on the answer. Keep it
--- longer than the callback timeout your handlers use, so theirs runs out first.
Config.PayTimeout = 20

--- Milliseconds the receipt stays before the dialog closes itself; 0 waits for the player.
Config.CloseDelay = 2600

--- Volume of the dialog's sounds, 0 silent to 1 full.
Config.Volume = 0.5

--- Registers /testpayment for admins, to try the dialog and xPlayer.chargeAccount with their own money.
Config.TestCommand = false
