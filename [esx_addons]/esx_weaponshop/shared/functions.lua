-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

---Gets ESX theme colors from convars (client-only)
---@return table Theme colors
function GetESXThemeColors()
	return xLib.colors.getESXTheme({
		secondaryColor = '#1a1a1a',
		backgroundColor = '#0a0a0a',
		accentColor = '#ffffff'
	})
end

---Safely gets an ESX weapon config without letting ESX.GetWeapon assertions bubble.
---@param weaponName any
---@return table|nil weapon
function GetWeaponConfig(weaponName)
	if type(weaponName) ~= 'string' or weaponName == '' then
		return nil
	end

	local ok, first, second = pcall(ESX.GetWeapon, weaponName)
	if not ok then
		return nil
	end

	if type(second) == 'table' then
		return second
	end

	return type(first) == 'table' and first or nil
end

---Checks whether weapon upgrades are usable with the active inventory backend.
---@return boolean supported
function AreWeaponShopUpgradesSupported()
	if not Config.WeaponShopUpgrades or Config.WeaponShopUpgrades.Enabled ~= true then
		return false
	end

	if Config.OxInventory then
		return GetResourceState('ox_inventory') == 'started'
	end

	return true
end

local function NormalizePositiveInteger(value)
	value = tonumber(value)

	if not value or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end

	value = math.floor(value)
	return value > 0 and value or nil
end

local function NormalizeInteger(value)
	value = tonumber(value)

	if not value or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end

	return math.floor(value)
end

---Gets the configured inventory ammo ceiling for ox_inventory weapons.
---@return number|nil maxAmmo
function GetWeaponShopConfiguredAmmoLimit()
	local ammoConfig = Config.WeaponShopUpgrades and Config.WeaponShopUpgrades.Ammo or {}

	return NormalizePositiveInteger(ammoConfig.MaxTotal)
		or NormalizePositiveInteger(ammoConfig.MaxAmount)
end

local function IsOxInventoryActive()
	return Config.OxInventory == true and GetResourceState('ox_inventory') == 'started'
end

local function GetOxInventoryItem(itemName)
	if not IsOxInventoryActive() or type(itemName) ~= 'string' or itemName == '' then
		return nil
	end

	local ok, item = pcall(function()
		return exports.ox_inventory:Items(itemName)
	end)

	return ok and type(item) == 'table' and item or nil
end

---Checks whether an ox_inventory item exists.
---@param itemName string
---@return boolean
function IsOxInventoryItemAvailable(itemName)
	return GetOxInventoryItem(itemName) ~= nil
end

---Gets the ox_inventory ammo item used by a weapon.
---@param weaponName string
---@return string|nil ammoItemName
function GetOxWeaponAmmoItem(weaponName)
	local oxItem = GetOxInventoryItem(weaponName)
	local ammoItemName = oxItem and oxItem.ammoname

	if type(ammoItemName) ~= 'string' or ammoItemName == '' then
		return nil
	end

	if not IsOxInventoryItemAvailable(ammoItemName) then
		return nil
	end

	return ammoItemName
end

---Checks whether a weapon uses ammo in the active inventory backend.
---@param weaponName string
---@param weapon table|nil
---@return boolean
function WeaponShopWeaponUsesAmmo(weaponName, weapon)
	weapon = weapon or GetWeaponConfig(weaponName)

	if weapon and weapon.throwable then
		return false
	end

	if IsOxInventoryActive() then
		return GetOxWeaponAmmoItem(weaponName) ~= nil
	end

	return weapon and type(weapon.ammo) == 'table' or false
end

local function ResolveOxComponentItem(component)
	local componentConfig = Config.WeaponShopUpgrades and Config.WeaponShopUpgrades.Components or {}
	local byHash = componentConfig.OxItemsByHash or {}
	local byName = componentConfig.OxItemsByName or {}
	local componentHash = type(component) == 'table' and tonumber(component.hash) or nil
	local componentName = type(component) == 'table' and component.name or nil

	return (componentHash and byHash[componentHash]) or (componentName and byName[componentName]) or nil
end

local function ResolveWeaponShopComponentName(component)
	if type(component) ~= 'table' or type(component.name) ~= 'string' or component.name == '' then
		return nil
	end

	if not Config.OxInventory then
		return component.name
	end

	local oxComponentName = ResolveOxComponentItem(component)
	if type(oxComponentName) ~= 'string' or oxComponentName == '' then
		return nil
	end

	if not IsOxInventoryItemAvailable(oxComponentName) then
		return nil
	end

	return oxComponentName
end

local function NormalizeAmmoNativeResult(first, second)
	local ammo = NormalizePositiveInteger(second)
	if ammo then
		return ammo
	end

	if first ~= true and first ~= false then
		return NormalizePositiveInteger(first)
	end

	return nil
end

local function GetWeaponMaxAmmo(ped, weaponHash)
	if type(GetMaxAmmo) ~= 'function' then
		return nil
	end

	local checked, first, second = pcall(function()
		return GetMaxAmmo(ped, weaponHash)
	end)

	if not checked then
		return nil
	end

	return NormalizeAmmoNativeResult(first, second)
end

local function GetWeaponMaxAmmoByType(ped, weaponHash)
	if type(GetPedAmmoTypeFromWeapon) ~= 'function' or type(GetMaxAmmoByType) ~= 'function' then
		return nil
	end

	local typeChecked, ammoType = pcall(function()
		return GetPedAmmoTypeFromWeapon(ped, weaponHash)
	end)

	ammoType = typeChecked and NormalizeInteger(ammoType) or nil
	if not ammoType or ammoType == 0 then
		return nil
	end

	local checked, first, second = pcall(function()
		return GetMaxAmmoByType(ped, ammoType)
	end)

	if not checked then
		return nil
	end

	return NormalizeAmmoNativeResult(first, second)
end

local function GetPedWeaponMaxAmmo(ped, weaponName)
	if not ped or ped == 0 or type(weaponName) ~= 'string' then
		return nil
	end

	local weaponHash = joaat(weaponName)

	return GetWeaponMaxAmmo(ped, weaponHash) or GetWeaponMaxAmmoByType(ped, weaponHash)
end

---Gets the runtime ammo cap for a weapon from the current client ped when available.
---@param weaponName string
---@return number|nil maxAmmo
function GetWeaponShopAmmoLimit(weaponName)
	if IsDuplicityVersion() or type(PlayerPedId) ~= 'function' then
		return nil
	end

	return GetPedWeaponMaxAmmo(PlayerPedId(), weaponName)
end

---Converts a configured image value into a browser-safe URL.
---@param image string|nil
---@return string imageUrl
function GetWeaponShopImageUrl(image)
	if type(image) ~= 'string' or image == '' then
		return ''
	end

	local scheme = image:match('^(%a[%w+.-]*):')
	if scheme then
		scheme = scheme:lower()

		if scheme == 'http' or scheme == 'https' or scheme == 'nui' or scheme == 'data' then
			return image
		end

		return ''
	end

	image = image:gsub('^%./', ''):gsub('^/+', '')
	return ('nui://%s/%s'):format(GetCurrentResourceName(), image)
end

---Gets a configured image override for a weapon.
---@param weaponName string
---@return string|nil imageUrl
function GetWeaponShopCustomImage(weaponName)
	if type(weaponName) ~= 'string' or type(Config.WeaponImages) ~= 'table' then
		return nil
	end

	local image = Config.WeaponImages[weaponName] or Config.WeaponImages[weaponName:upper()]
	local imageUrl = GetWeaponShopImageUrl(image)

	return imageUrl ~= '' and imageUrl or nil
end

---Gets a browser-safe fallback image URL from config.
---@return string fallbackImage
function GetWeaponShopFallbackImage()
	return GetWeaponShopImageUrl(Config.FallbackWeaponImage)
end

local function GetComponentPrice(componentName, weaponName)
	local config = Config.WeaponShopUpgrades.Components or {}
	local byWeapon = config.WeaponPrices and config.WeaponPrices[weaponName]
	local price = byWeapon and byWeapon[componentName] or config.Prices and config.Prices[componentName] or config.DefaultPrice

	return tonumber(price) or 0
end

local function GetTintPrice(tintIndex, weaponName)
	local config = Config.WeaponShopUpgrades.Tints or {}
	local byWeapon = config.WeaponPrices and config.WeaponPrices[weaponName]
	local price = byWeapon and byWeapon[tintIndex] or config.Prices and config.Prices[tintIndex] or config.DefaultPrice

	return tonumber(price) or 0
end

local function GetTintSwatch(tintIndex)
	local config = Config.WeaponShopUpgrades.Tints or {}

	return config.Swatches and config.Swatches[tintIndex] or '#9A9A9A'
end

---Builds upgrade options for a weapon using ESX weapon metadata and local prices.
---@param weaponName string
---@return table upgrades
function BuildWeaponUpgrades(weaponName)
	local upgrades = {
		supported = AreWeaponShopUpgradesSupported(),
		ammo = nil,
		components = {},
		tints = {}
	}

	if not upgrades.supported then
		return upgrades
	end

	local weapon = GetWeaponConfig(weaponName)
	if not weapon then
		return upgrades
	end

	local upgradeConfig = Config.WeaponShopUpgrades
	local ammoConfig = upgradeConfig.Ammo or {}

	if ammoConfig.Enabled ~= false and WeaponShopWeaponUsesAmmo(weaponName, weapon) then
		local ammoLabel = type(weapon.ammo) == 'table' and weapon.ammo.label or TranslateCap('upgrade_ammo')

		upgrades.ammo = {
			label = ammoLabel,
			pricePerRound = tonumber(ammoConfig.PricePerRound) or 0,
			defaultAmount = tonumber(ammoConfig.DefaultAmount) or 30,
			minAmount = tonumber(ammoConfig.MinAmount) or 1,
			maxAmount = tonumber(ammoConfig.MaxAmount) or 250,
			quickAmounts = ammoConfig.QuickAmounts or { 30, 60, 120 },
			maxAmmo = GetWeaponShopAmmoLimit(weaponName) or (Config.OxInventory and GetWeaponShopConfiguredAmmoLimit() or nil)
		}
	end

	local componentConfig = upgradeConfig.Components or {}
	if componentConfig.Enabled ~= false and type(weapon.components) == 'table' then
		for i = 1, #weapon.components do
			local component = weapon.components[i]
			local componentName = component and component.name

			if type(componentName) == 'string' and not (componentConfig.Blacklisted and componentConfig.Blacklisted[componentName]) then
				local price = GetComponentPrice(componentName, weaponName)
				local shopComponentName = ResolveWeaponShopComponentName(component)
				if price > 0 and shopComponentName then
					upgrades.components[#upgrades.components + 1] = {
						name = shopComponentName,
						esxName = componentName,
						label = component.label or componentName,
						price = price
					}
				end
			end
		end
	end

	local tintConfig = upgradeConfig.Tints or {}
	if tintConfig.Enabled ~= false and type(weapon.tints) == 'table' then
		for fallbackIndex, tintData in pairs(weapon.tints) do
			local tintIndex = nil
			local tintLabel = nil

			if type(tintData) == 'table' then
				tintIndex = tonumber(tintData.tint or tintData.index)
				tintLabel = tintData.label or tintData.name
			else
				tintIndex = tonumber(fallbackIndex)
				tintLabel = tostring(tintData)
			end

			if tintIndex and tintIndex == math.floor(tintIndex) and type(tintLabel) == 'string' and tintLabel ~= '' then
				upgrades.tints[#upgrades.tints + 1] = {
					index = tintIndex,
					label = tintLabel,
					price = GetTintPrice(tintIndex, weaponName),
					color = GetTintSwatch(tintIndex)
				}
			end
		end

		table.sort(upgrades.tints, function(a, b)
			return a.index < b.index
		end)
	end

	return upgrades
end

---Finds a configured component upgrade option.
---@param weaponName string
---@param componentName string
---@return table|nil component
function GetWeaponShopComponentUpgrade(weaponName, componentName)
	local upgrades = BuildWeaponUpgrades(weaponName)

	for i = 1, #upgrades.components do
		if upgrades.components[i].name == componentName then
			return upgrades.components[i]
		end
	end

	return nil
end

---Finds a configured tint upgrade option.
---@param weaponName string
---@param tintIndex number
---@return table|nil tint
function GetWeaponShopTintUpgrade(weaponName, tintIndex)
	local upgrades = BuildWeaponUpgrades(weaponName)

	for i = 1, #upgrades.tints do
		if upgrades.tints[i].index == tintIndex then
			return upgrades.tints[i]
		end
	end

	return nil
end
