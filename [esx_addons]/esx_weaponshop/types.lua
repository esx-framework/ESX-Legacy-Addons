-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

---@meta

---@class WeaponShopItem
---@field name string Weapon spawn name (e.g., "WEAPON_PISTOL")
---@field price number Purchase price

---@class WeaponShopBlip
---@field Enabled boolean Whether to show blip on map
---@field Sprite number Blip sprite
---@field Color number Blip color
---@field Display number Blip display type
---@field Scale number Blip scale
---@field ShortRange boolean Whether blip is short-range only

---@class WeaponShopZone
---@field Legal boolean Whether this shop requires a weapon license when enabled
---@field Blip WeaponShopBlip Blip configuration
---@field Items WeaponShopItem[] Available weapons in this shop
---@field Locations vector3[] Shop locations on map

---@class WeaponShopNuiItem
---@field name string Weapon spawn name
---@field label string Display label shown in UI
---@field price number Purchase price
---@field category string Category identifier
---@field image string Image URL for UI display
---@field upgrades WeaponShopUpgrades Available upgrade options
---@field state WeaponShopWeaponState Current player state for this weapon

---@class WeaponShopAmmoUpgrade
---@field label string Ammo display label
---@field pricePerRound number Price per ammo unit
---@field defaultAmount number Default amount selected in UI
---@field minAmount number Minimum purchasable amount
---@field maxAmount number Maximum purchasable amount
---@field quickAmounts number[] Quick-select ammo amounts
---@field maxAmmo number|nil Maximum ammo the weapon may hold after buying ammo

---@class WeaponShopComponentUpgrade
---@field name string ESX component name
---@field label string Display label
---@field price number Purchase price

---@class WeaponShopTintUpgrade
---@field index number Tint index
---@field label string Display label
---@field price number Purchase/apply price
---@field color string Hex color preview

---@class WeaponShopUpgrades
---@field supported boolean Whether upgrades are available with the active inventory backend
---@field ammo WeaponShopAmmoUpgrade|nil Ammo purchase configuration
---@field components WeaponShopComponentUpgrade[] Component purchase options
---@field tints WeaponShopTintUpgrade[] Tint purchase options

---@class WeaponShopWeaponState
---@field owned boolean Whether the player owns this weapon
---@field ammo number Current ammo count
---@field tintIndex number Current equipped tint index
---@field components string[] Owned component names

---@class WeaponShopCategory
---@field id string Unique category identifier
---@field label string Display name shown in UI

---@class WeaponShopLocales
---@field searchPlaceholder string
---@field buy string
---@field apply string
---@field owned string
---@field equipped string
---@field unavailable string
---@field noWeaponSelected string
---@field noImageAvailable string
---@field licenseTitle string
---@field licenseDescription string
---@field buyLicense string
---@field cancel string
---@field tabWeapon string
---@field tabAmmo string
---@field tabComponents string
---@field tabTints string
---@field ammo string
---@field ammoUnit string
---@field pricePerRound string
---@field total string
---@field buyAmmo string
---@field ammoFull string
---@field components string
---@field tints string
---@field requiresWeapon string
---@field noAmmoAvailable string
---@field noComponentsAvailable string
---@field noTintsAvailable string

---@class WeaponShopData
---@field shopName string Shop name
---@field items WeaponShopNuiItem[] Available weapons
---@field categories WeaponShopCategory[] Item categories
---@field locales WeaponShopLocales Translated UI strings
---@field fallbackImage string Configured fallback image for missing weapon pictures
---@field legal boolean Whether this is a legal shop
---@field mode "shop"|"license" Current NUI mode
---@field licensePrice number Weapon license price
---@field selectedName string|nil Weapon selected after a refresh

---@class ThemeConvars
---@field primaryColor string Primary brand color (hex)
---@field secondaryColor string Secondary color (hex)
---@field backgroundColor string Background color (hex)
---@field accentColor string Accent/highlight color (hex)
---@field logoUrl string Logo image URL
