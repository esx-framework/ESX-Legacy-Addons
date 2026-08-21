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

---@class WeaponShopCategory
---@field id string Unique category identifier
---@field label string Display name shown in UI

---@class WeaponShopLocales
---@field searchPlaceholder string
---@field buy string
---@field noWeaponSelected string
---@field noImageAvailable string
---@field licenseTitle string
---@field licenseDescription string
---@field buyLicense string
---@field cancel string

---@class WeaponShopData
---@field shopName string Shop name
---@field items WeaponShopNuiItem[] Available weapons
---@field categories WeaponShopCategory[] Item categories
---@field locales WeaponShopLocales Translated UI strings
---@field legal boolean Whether this is a legal shop
---@field mode "shop"|"license" Current NUI mode
---@field licensePrice number Weapon license price

---@class ThemeConvars
---@field primaryColor string Primary brand color (hex)
---@field secondaryColor string Secondary color (hex)
---@field backgroundColor string Background color (hex)
---@field accentColor string Accent/highlight color (hex)
---@field logoUrl string Logo image URL
