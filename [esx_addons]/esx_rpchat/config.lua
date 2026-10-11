-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Config = {}

Config.Locale = GetConvar('esx:locale', 'en')
Config.OnlyFirstname = false
Config.EnableESXIdentity = true -- RP names
Config.ProximityDistance = 20.0 -- meters for /me and /do messages
Config.ProximityMaxLength = 256 -- maximum characters kept from /me and /do messages
Config.OocCooldown = 3000 -- milliseconds between OOC messages from the same player
Config.TwtCooldown = 10000 -- milliseconds between /twt messages from the same player
Config.AnonTwtCooldown = 15000 -- milliseconds between /anontwt messages from the same player
Config.MeCooldown = 1000 -- milliseconds between /me messages from the same player
Config.DoCooldown = 1000 -- milliseconds between /do messages from the same player
