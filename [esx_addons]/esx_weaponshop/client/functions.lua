-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local WEAPON_CATEGORIES = {
	[`GROUP_MELEE`] = 'melee',
	[`GROUP_PISTOL`] = 'handguns',
	[`GROUP_STUNGUN`] = 'handguns',
	[`GROUP_SMG`] = 'smgs',
	[`GROUP_RIFLE`] = 'rifles',
	[`GROUP_MG`] = 'rifles',
	[`GROUP_SHOTGUN`] = 'shotguns',
	[`GROUP_SNIPER`] = 'rifles',
	[`GROUP_HEAVY`] = 'heavy',
	[`GROUP_THROWN`] = 'throwables',
	[`GROUP_FIREEXTINGUISHER`] = 'misc',
	[`GROUP_PETROLCAN`] = 'misc',
}

local CATEGORY_ORDER = {
	'melee',
	'handguns',
	'smgs',
	'shotguns',
	'rifles',
	'heavy',
	'throwables',
	'misc'
}

---Gets display label for a weapon item
---@param weaponName string
---@return string
function GetItemLabel(weaponName)
	local label = ESX.GetWeaponLabel(weaponName)

	if Config.OxInventory and GetResourceState('ox_inventory') == 'started' then
		local oxItem = exports.ox_inventory:Items(weaponName)
		if oxItem then
			label = oxItem.label
		end
	end

	return label
end

---Gets image URL for a weapon item
---@param weaponName string
---@return string
function GetWeaponImage(weaponName)
	local customImage = GetWeaponShopCustomImage(weaponName)
	if customImage then
		return customImage
	end

	if Config.OxInventory and GetResourceState('ox_inventory') == 'started' then
		local oxItem = exports.ox_inventory:Items(weaponName)
		if oxItem and oxItem.client and oxItem.client.image then
			return oxItem.client.image
		end

		return ('nui://ox_inventory/web/images/%s.png'):format(weaponName)
	end

	return ('https://docs-backend.fivem.net/weapons/%s.png'):format(weaponName)
end

---Maps weapon to UI category
---@param weaponName string
---@return string
function GetWeaponCategory(weaponName)
	local group = GetWeapontypeGroup(joaat(weaponName))
	return WEAPON_CATEGORIES[group] or 'misc'
end

---Gets localized labels used by the weaponshop NUI
---@return table
function GetShopLocales()
	return {
		searchPlaceholder = TranslateCap('search_placeholder'),
		buy = TranslateCap('buy'),
		apply = TranslateCap('apply'),
		owned = TranslateCap('owned'),
		equipped = TranslateCap('equipped'),
		unavailable = TranslateCap('unavailable'),
		noWeaponSelected = TranslateCap('no_weapon_selected'),
		noImageAvailable = TranslateCap('no_image_available'),
		licenseTitle = TranslateCap('license_shop_title'),
		licenseDescription = TranslateCap('license_description'),
		buyLicense = TranslateCap('buy_license'),
		cancel = TranslateCap('menu_cancel'),
		tabWeapon = TranslateCap('tab_weapon'),
		tabAmmo = TranslateCap('tab_ammo'),
		tabComponents = TranslateCap('tab_components'),
		tabTints = TranslateCap('tab_tints'),
		ammo = TranslateCap('upgrade_ammo'),
		ammoUnit = TranslateCap('ammo_unit'),
		pricePerRound = TranslateCap('price_per_round'),
		total = TranslateCap('total'),
		buyAmmo = TranslateCap('buy_ammo'),
		ammoFull = TranslateCap('ammo_full'),
		components = TranslateCap('upgrade_components'),
		tints = TranslateCap('upgrade_tints'),
		requiresWeapon = TranslateCap('requires_weapon'),
		noAmmoAvailable = TranslateCap('no_ammo_available'),
		noComponentsAvailable = TranslateCap('no_components_available'),
		noTintsAvailable = TranslateCap('no_tints_available')
	}
end

local function NormalizeAmmoValue(value)
	value = tonumber(value)

	if not value or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end

	return math.max(math.floor(value), 0)
end

local function GetOxInventoryItemCount(itemName)
	if not Config.OxInventory or GetResourceState('ox_inventory') ~= 'started' then
		return 0
	end

	if type(itemName) ~= 'string' or itemName == '' then
		return 0
	end

	local searched, count = pcall(function()
		return exports.ox_inventory:Search('count', itemName)
	end)

	return searched and NormalizeAmmoValue(count) or 0
end

local function GetOxInventoryWeaponSlot(weaponName)
	if not Config.OxInventory or GetResourceState('ox_inventory') ~= 'started' then
		return nil
	end

	if type(weaponName) ~= 'string' or weaponName == '' then
		return nil
	end

	local searched, slots = pcall(function()
		return exports.ox_inventory:Search('slots', weaponName)
	end)

	if not searched or type(slots) ~= 'table' then
		return nil
	end

	for _, slot in pairs(slots) do
		if type(slot) == 'table' and slot.name == weaponName and slot.slot then
			return slot
		end
	end

	return nil
end

local function BuildOxInventoryWeaponState(weaponName)
	local state = {
		owned = false,
		ammo = 0,
		tintIndex = 0,
		components = {}
	}

	local slot = GetOxInventoryWeaponSlot(weaponName)
	local ammoItemName = GetOxWeaponAmmoItem(weaponName)

	if ammoItemName then
		state.ammo = GetOxInventoryItemCount(ammoItemName)
	end

	if not slot then
		return state
	end

	local metadata = type(slot.metadata) == 'table' and slot.metadata or {}
	state.owned = true
	state.tintIndex = NormalizeAmmoValue(metadata.tint) or 0

	if not ammoItemName then
		state.ammo = NormalizeAmmoValue(metadata.ammo) or 0
	end

	if type(metadata.components) == 'table' then
		for i = 1, #metadata.components do
			if type(metadata.components[i]) == 'string' then
				state.components[#state.components + 1] = metadata.components[i]
			end
		end
	end

	return state
end

local function GetWeaponAmmoState(weaponName)
	if type(weaponName) ~= 'string' or weaponName == '' then
		return nil
	end

	if Config.OxInventory then
		local state = BuildOxInventoryWeaponState(weaponName)
		if not state.owned then
			return nil
		end

		return {
			currentAmmo = state.ammo,
			maxAmmo = GetWeaponShopAmmoLimit(weaponName) or GetWeaponShopConfiguredAmmoLimit()
		}
	end

	local ped = PlayerPedId()
	local weaponHash = joaat(weaponName)
	local hasPedWeapon = HasPedGotWeapon(ped, weaponHash, false)

	local currentAmmo = hasPedWeapon and NormalizeAmmoValue(GetAmmoInPedWeapon(ped, weaponHash)) or 0
	local maxAmmo = GetWeaponShopAmmoLimit(weaponName)

	if not currentAmmo or not maxAmmo then
		return nil
	end

	return {
		currentAmmo = currentAmmo,
		maxAmmo = maxAmmo
	}
end

RegisterNetEvent('esx_weaponshop:requestWeaponAmmoState', function(requestId, weaponName)
	TriggerServerEvent('esx_weaponshop:receiveWeaponAmmoState', requestId, GetWeaponAmmoState(weaponName))
end)

local function BuildWeaponState(weaponName, upgrades)
	local state = {
		owned = false,
		ammo = 0,
		tintIndex = 0,
		components = {}
	}

	if Config.OxInventory then
		return BuildOxInventoryWeaponState(weaponName)
	end

	local ped = PlayerPedId()
	local weaponHash = joaat(weaponName)

	state.owned = HasPedGotWeapon(ped, weaponHash, false)

	if not state.owned then
		return state
	end

	state.ammo = GetAmmoInPedWeapon(ped, weaponHash)
	state.tintIndex = GetPedWeaponTintIndex(ped, weaponHash)

	if upgrades and type(upgrades.components) == 'table' then
		for i = 1, #upgrades.components do
			local ok, first, second = pcall(ESX.GetWeaponComponent, weaponName, upgrades.components[i].name)
			local component = ok and (type(second) == 'table' and second or type(first) == 'table' and first) or nil

			if component and HasPedGotWeaponComponent(ped, weaponHash, component.hash) then
				state.components[#state.components + 1] = upgrades.components[i].name
			end
		end
	end

	return state
end

---Builds the current weapon state for direct NUI refreshes.
---@param weaponName string
---@return table state
function BuildCurrentShopWeaponState(weaponName)
	return BuildWeaponState(weaponName, BuildWeaponUpgrades(weaponName))
end

---Builds NUI item list for a zone
---@param zone string
---@return table
function BuildShopItems(zone)
	local zoneItems = Config.Zones[zone].Items
	local items = {}

	for i = 1, #zoneItems do
		local item = zoneItems[i]
		local upgrades = BuildWeaponUpgrades(item.name)
		items[i] = {
			name = item.name,
			label = GetItemLabel(item.name),
			price = item.price,
			category = GetWeaponCategory(item.name),
			image = GetWeaponImage(item.name),
			upgrades = upgrades,
			state = BuildWeaponState(item.name, upgrades)
		}
	end

	return items
end

---Builds category filter list from zone items
---@param items table
---@return table
function BuildCategories(items)
	local found = {}

	for i = 1, #items do
		found[items[i].category] = true
	end

	local categories = {
		{ id = 'all', label = TranslateCap('category_all') }
	}

	for i = 1, #CATEGORY_ORDER do
		local id = CATEGORY_ORDER[i]
		if found[id] then
			categories[#categories + 1] = {
				id = id,
				label = TranslateCap('category_' .. id)
			}
		end
	end

	return categories
end

---Gets weapon price from the currently selected zone
---@param zone string
---@param weaponName string
---@return number
function GetZoneWeaponPrice(zone, weaponName)
	local zoneItems = Config.Zones[zone].Items

	for i = 1, #zoneItems do
		if zoneItems[i].name == weaponName then
			return zoneItems[i].price
		end
	end

	return 0
end

---Displays purchase scaleform and purchase sound
---@param weaponName string
---@param price number
function DisplayBoughtScaleform(weaponName, price)
	local scaleform = xLib.scaleform.utils.requestScaleformMovie('MP_BIG_MESSAGE_FREEMODE')
	local sec = 4

	BeginScaleformMovieMethod(scaleform, 'SHOW_WEAPON_PURCHASED')

	local label = GetItemLabel(weaponName)

	ScaleformMovieMethodAddParamTextureNameString(TranslateCap('weapon_bought', ESX.Math.GroupDigits(price)))
	ScaleformMovieMethodAddParamTextureNameString(label)
	ScaleformMovieMethodAddParamInt(joaat(weaponName))
	ScaleformMovieMethodAddParamTextureNameString('')
	ScaleformMovieMethodAddParamInt(100)
	EndScaleformMovieMethod()

	PlaySoundFrontend(-1, 'WEAPON_PURCHASE', 'HUD_AMMO_SHOP_SOUNDSET', false)

	CreateThread(function()
		while sec > 0 do
			Wait(0)
			sec = sec - 0.01

			DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255, 0)
		end
	end)
end
