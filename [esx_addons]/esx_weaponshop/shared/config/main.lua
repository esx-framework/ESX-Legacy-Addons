-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

---@type table
Config = Config or {}

-- ════════════════════════════════════════════════════════════════
-- CORE CONFIGURATION
-- ════════════════════════════════════════════════════════════════

Config.Locale = GetConvar('esx:locale', 'en')
Config.OxInventory = ESX.GetConfig().OxInventory

-- Image used by the NUI when the weapon image from inventory/FiveM docs cannot be loaded.
-- Supports URLs, nui:// paths, data URLs, or local resource paths
-- such as "web/dist/images/default-weapon.png".
Config.FallbackWeaponImage = ''

-- Optional image overrides per weapon. These take priority over ox_inventory/FiveM docs images.
-- Supports URLs, nui:// paths, data URLs or local resource paths.
--
-- Examples:
-- Config.WeaponImages = {
-- 	WEAPON_PISTOL = 'nui://esx_weaponshop/web/dist/images/pistol.png',
-- 	WEAPON_MICROSMG = 'https://example.com/microsmg.png',
-- 	WEAPON_MACHETE = 'web/dist/images/machete.png'
-- }
Config.WeaponImages = {}

-- Ammo loaded when a weapon is bought through the ESX loadout backend.
Config.InitialWeaponAmmo = 42

-- ════════════════════════════════════════════════════════════════
-- LICENSE CONFIGURATION
-- ════════════════════════════════════════════════════════════════

-- Only turn this on if you are using esx_license
Config.LicenseEnable = true
Config.LicensePrice = 5000

-- Server-side abuse protection
Config.ServerDistanceBuffer = 3.0
Config.PurchaseCooldown = 1500
Config.LicenseCallbackTimeout = 5000
Config.ClientCallbackTimeout = 5000

-- ════════════════════════════════════════════════════════════════
-- MARKER CONFIGURATION
-- ════════════════════════════════════════════════════════════════

Config.DrawDistance = 10.0
Config.Size = { x = 1.5, y = 1.5, z = 0.5 }
Config.Color = { r = 0, g = 128, b = 255 }
Config.Type = 1
Config.InteractionDistance = 2.0
Config.InteractionKeyLabel = 'E'
