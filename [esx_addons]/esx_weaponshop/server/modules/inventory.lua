-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local function GetOxInventory()
	if not Config.OxInventory then
		return nil
	end

	if GetResourceState('ox_inventory') ~= 'started' then
		print('[^3WARNING^7] ox_inventory is enabled in ESX config but the resource is not started.')
		return nil
	end

	return exports.ox_inventory
end

local function GetInitialWeaponAmmo()
	local ammo = tonumber(Config.InitialWeaponAmmo)

	if not ammo or ammo ~= ammo or ammo == math.huge or ammo == -math.huge then
		return 42
	end

	return math.max(math.floor(ammo), 0)
end

local function GetInitialOxWeaponAmmoItem(weaponName)
	local ammoItemName = GetOxWeaponAmmoItem(weaponName)
	local amount = GetInitialWeaponAmmo()

	if not ammoItemName or amount <= 0 then
		return nil, 0
	end

	return ammoItemName, amount
end

local function BuildOxWeaponMetadata(weaponName)
	local metadata = {
		components = {},
		tint = 0
	}

	if WeaponShopWeaponUsesAmmo(weaponName) then
		metadata.ammo = 0
	end

	return metadata
end

local function CopyOxWeaponMetadata(metadata)
	local copy = {}

	if type(metadata) == 'table' then
		for key, value in pairs(metadata) do
			copy[key] = value
		end
	end

	if type(copy.components) ~= 'table' then
		copy.components = {}
	end

	return copy
end

local function GetOxWeaponSlot(source, weaponName)
	local ox_inventory = GetOxInventory()

	if not ox_inventory or type(weaponName) ~= 'string' or weaponName == '' then
		return nil
	end

	local searched, slots = pcall(function()
		return ox_inventory:Search(source, 'slots', weaponName)
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

local function GetOxWeaponMetadata(source, weaponName)
	local slot = GetOxWeaponSlot(source, weaponName)
	if not slot then
		return nil, nil
	end

	return slot, CopyOxWeaponMetadata(slot.metadata)
end

local function SetOxWeaponMetadata(source, slot, metadata)
	local ox_inventory = GetOxInventory()

	if not ox_inventory or not slot or type(metadata) ~= 'table' then
		return false
	end

	local set, result = pcall(function()
		return ox_inventory:SetMetadata(source, slot.slot, metadata)
	end)

	return set and result ~= false
end

local function GetOxItemCount(source, itemName)
	local ox_inventory = GetOxInventory()

	if not ox_inventory or type(itemName) ~= 'string' or itemName == '' then
		return nil
	end

	local searched, count = pcall(function()
		return ox_inventory:Search(source, 'count', itemName)
	end)

	return searched and type(count) == 'number' and count or nil
end

local function CanCarryOxItem(source, itemName, count, metadata)
	local ox_inventory = GetOxInventory()
	count = tonumber(count)

	if not ox_inventory or type(itemName) ~= 'string' or itemName == '' or not count or count <= 0 then
		return false
	end

	local checked, canCarry = pcall(function()
		return ox_inventory:CanCarryItem(source, itemName, math.floor(count), metadata)
	end)

	return checked and canCarry == true
end

local function AddOxItem(source, itemName, count, metadata)
	local ox_inventory = GetOxInventory()
	count = tonumber(count)

	if not ox_inventory or type(itemName) ~= 'string' or itemName == '' or not count or count <= 0 then
		return false
	end

	local added, result = pcall(function()
		return ox_inventory:AddItem(source, itemName, math.floor(count), metadata)
	end)

	return added and result == true
end

local function RemoveOxItem(source, itemName, count, metadata)
	local ox_inventory = GetOxInventory()
	count = tonumber(count)

	if not ox_inventory or type(itemName) ~= 'string' or itemName == '' or not count or count <= 0 then
		return false
	end

	local removed, result = pcall(function()
		return ox_inventory:RemoveItem(source, itemName, math.floor(count), metadata)
	end)

	return removed and result ~= false
end

local function TableContains(list, value)
	if type(list) ~= 'table' or type(value) ~= 'string' or value == '' then
		return false
	end

	for i = 1, #list do
		if list[i] == value then
			return true
		end
	end

	return false
end

---Checks if player can receive the weapon
---@param source number Player source
---@param xPlayer table ESX player object
---@param weaponName string
---@return boolean
function CanReceiveWeapon(source, xPlayer, weaponName)
	local ox_inventory = GetOxInventory()

	if Config.OxInventory and not ox_inventory then
		xPlayer.showNotification(TranslateCap('cannot_carry'))
		return false
	end

	if ox_inventory then
		local metadata = BuildOxWeaponMetadata(weaponName)
		local ammoItemName, initialAmmo = GetInitialOxWeaponAmmoItem(weaponName)
		local searched, count = pcall(function()
			return ox_inventory:Search(source, 'count', weaponName)
		end)

		if not searched or type(count) ~= 'number' then
			xPlayer.showNotification(TranslateCap('cannot_carry'))
			return false
		end

		if count > 0 then
			xPlayer.showNotification(TranslateCap('already_owned'))
			return false
		end

		if not CanCarryOxItem(source, weaponName, 1, metadata) then
			xPlayer.showNotification(TranslateCap('cannot_carry'))
			return false
		end

		if initialAmmo > 0 and not CanCarryOxItem(source, ammoItemName, initialAmmo) then
			xPlayer.showNotification(TranslateCap('cannot_carry'))
			return false
		end

		return true
	end

	local checked, hasWeapon = pcall(function()
		return xPlayer.hasWeapon(weaponName)
	end)

	if not checked then
		return false
	end

	if hasWeapon then
		xPlayer.showNotification(TranslateCap('already_owned'))
		return false
	end

	return true
end

---Gives weapon item to player depending on inventory backend
---@param source number Player source
---@param xPlayer table ESX player object
---@param weaponName string
---@return boolean
function AddWeapon(source, xPlayer, weaponName)
	local ox_inventory = GetOxInventory()

	if Config.OxInventory and not ox_inventory then
		return false
	end

	if ox_inventory then
		local metadata = BuildOxWeaponMetadata(weaponName)
		local ammoItemName, initialAmmo = GetInitialOxWeaponAmmoItem(weaponName)

		if not AddOxItem(source, weaponName, 1, metadata) then
			return false
		end

		if initialAmmo > 0 and not AddOxItem(source, ammoItemName, initialAmmo) then
			RemoveOxItem(source, weaponName, 1)
			return false
		end

		return true
	end

	local added = pcall(function()
		xPlayer.addWeapon(weaponName, GetInitialWeaponAmmo())
	end)

	return added
end

---Checks whether the player owns a weapon in the active non-ox loadout.
---@param source number Player source
---@param xPlayer table ESX player object
---@param weaponName string
---@return boolean
function HasPlayerWeapon(source, xPlayer, weaponName)
	if Config.OxInventory then
		return GetOxWeaponSlot(source, weaponName) ~= nil
	end

	if type(xPlayer.hasWeapon) ~= 'function' then
		return false
	end

	local checked, hasWeapon = pcall(function()
		return xPlayer.hasWeapon(weaponName)
	end)

	return checked and hasWeapon == true
end

local function GetPlayerServerPed(source)
	if not source then
		return nil
	end

	local ped = GetPlayerPed(source)

	return ped and ped ~= 0 and ped or nil
end

local function GetPlayerWeaponEntry(xPlayer, weaponName)
	if type(xPlayer.getWeapon) == 'function' then
		local checked, first, second = pcall(function()
			return xPlayer.getWeapon(weaponName)
		end)

		if checked then
			if type(first) == 'table' then
				return first
			end

			if type(second) == 'table' then
				return second
			end
		end
	end

	if type(xPlayer.loadout) == 'table' then
		for i = 1, #xPlayer.loadout do
			local weapon = xPlayer.loadout[i]

			if weapon and weapon.name == weaponName then
				return weapon
			end
		end
	end

	return nil
end

local function NormalizeAmmoCount(value)
	value = tonumber(value)

	if not value or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end

	return math.max(math.floor(value), 0)
end

local function GetPedWeaponAmmo(source, weaponName)
	if type(GetAmmoInPedWeapon) ~= 'function' or type(weaponName) ~= 'string' then
		return nil
	end

	local ped = GetPlayerServerPed(source)
	if not ped then
		return nil
	end

	local checked, ammo = pcall(function()
		return GetAmmoInPedWeapon(ped, joaat(weaponName))
	end)

	return checked and NormalizeAmmoCount(ammo) or nil
end

---Gets the current ammo count for an owned weapon.
---@param source number Player source
---@param xPlayer table ESX player object
---@param weaponName string
---@return number|nil ammo
function GetPlayerWeaponAmmo(source, xPlayer, weaponName)
	if Config.OxInventory then
		local ammoItemName = GetOxWeaponAmmoItem(weaponName)
		if not ammoItemName then
			return nil
		end

		return NormalizeAmmoCount(GetOxItemCount(source, ammoItemName)) or 0
	end

	local pedAmmo = GetPedWeaponAmmo(source, weaponName)
	if pedAmmo then
		return pedAmmo
	end

	local weapon = GetPlayerWeaponEntry(xPlayer, weaponName)
	if not weapon then
		return nil
	end

	return NormalizeAmmoCount(weapon.ammo) or 0
end

local function NormalizePositiveAmmoLimit(value)
	value = NormalizeAmmoCount(value)

	return value and value > 0 and value or nil
end

---Checks whether adding ammo would stay inside the client runtime weapon ammo limit.
---@param source number Player source
---@param xPlayer table ESX player object
---@param weaponName string
---@param amount number
---@param ammoState table|nil Client ammo state with currentAmmo/maxAmmo
---@return boolean canAdd
function CanAddWeaponAmmo(source, xPlayer, weaponName, amount, ammoState)
	amount = tonumber(amount)
	if not amount or amount ~= amount or amount == math.huge or amount == -math.huge or amount <= 0 then
		return false
	end

	amount = math.floor(amount)

	if Config.OxInventory then
		local ammoItemName = GetOxWeaponAmmoItem(weaponName)
		if not ammoItemName then
			xPlayer.showNotification(TranslateCap('unavailable'))
			return false
		end

		local currentAmmo = NormalizeAmmoCount(GetOxItemCount(source, ammoItemName))
		if not currentAmmo then
			xPlayer.showNotification(TranslateCap('unavailable'))
			return false
		end

		local maxAmmo = GetWeaponShopConfiguredAmmoLimit()
		if maxAmmo and (currentAmmo >= maxAmmo or currentAmmo + amount > maxAmmo) then
			xPlayer.showNotification(TranslateCap('ammo_full'))
			return false
		end

		if not CanCarryOxItem(source, ammoItemName, amount) then
			xPlayer.showNotification(TranslateCap('cannot_carry'))
			return false
		end

		return true
	end

	local maxAmmo = type(ammoState) == 'table' and NormalizePositiveAmmoLimit(ammoState.maxAmmo) or nil

	if not maxAmmo then
		xPlayer.showNotification(TranslateCap('unavailable'))
		return false
	end

	local currentAmmo
	if type(ammoState) ~= 'table' then
		xPlayer.showNotification(TranslateCap('unavailable'))
		return false
	end

	currentAmmo = NormalizeAmmoCount(ammoState.currentAmmo)
	if not currentAmmo then
		xPlayer.showNotification(TranslateCap('unavailable'))
		return false
	end

	local serverAmmo = GetPlayerWeaponAmmo(source, xPlayer, weaponName)
	if serverAmmo and serverAmmo > currentAmmo then
		currentAmmo = serverAmmo
	end

	if not currentAmmo then
		xPlayer.showNotification(TranslateCap('unavailable'))
		return false
	end

	if currentAmmo >= maxAmmo or currentAmmo + amount > maxAmmo then
		xPlayer.showNotification(TranslateCap('ammo_full'))
		return false
	end

	return true
end

---Adds ammo to an owned weapon.
---@param source number Player source
---@param xPlayer table ESX player object
---@param weaponName string
---@param amount number
---@return boolean
function AddWeaponAmmo(source, xPlayer, weaponName, amount)
	if Config.OxInventory then
		local ammoItemName = GetOxWeaponAmmoItem(weaponName)
		if not ammoItemName then
			return false
		end

		return AddOxItem(source, ammoItemName, amount)
	end

	if type(xPlayer.addWeaponAmmo) ~= 'function' then
		return false
	end

	local added = pcall(function()
		xPlayer.addWeaponAmmo(weaponName, amount)
	end)

	return added
end

---Checks whether a weapon component is already owned.
---@param source number Player source
---@param xPlayer table ESX player object
---@param weaponName string
---@param componentName string
---@return boolean
function HasWeaponComponent(source, xPlayer, weaponName, componentName)
	if Config.OxInventory then
		local _, metadata = GetOxWeaponMetadata(source, weaponName)
		return metadata and TableContains(metadata.components, componentName) or false
	end

	if type(xPlayer.hasWeaponComponent) ~= 'function' then
		return false
	end

	local checked, hasComponent = pcall(function()
		return xPlayer.hasWeaponComponent(weaponName, componentName)
	end)

	return checked and hasComponent == true
end

---Adds a component to an owned weapon.
---@param source number Player source
---@param xPlayer table ESX player object
---@param weaponName string
---@param componentName string
---@return boolean
function AddWeaponComponent(source, xPlayer, weaponName, componentName)
	if Config.OxInventory then
		if not IsOxInventoryItemAvailable(componentName) then
			return false
		end

		local slot, metadata = GetOxWeaponMetadata(source, weaponName)
		if not slot or not metadata then
			return false
		end

		if not TableContains(metadata.components, componentName) then
			metadata.components[#metadata.components + 1] = componentName
		end

		return SetOxWeaponMetadata(source, slot, metadata)
	end

	if type(xPlayer.addWeaponComponent) ~= 'function' then
		return false
	end

	local added = pcall(function()
		xPlayer.addWeaponComponent(weaponName, componentName)
	end)

	return added
end

---Gets the current tint index for an owned weapon.
---@param source number Player source
---@param xPlayer table ESX player object
---@param weaponName string
---@return number
function GetWeaponTint(source, xPlayer, weaponName)
	if Config.OxInventory then
		local _, metadata = GetOxWeaponMetadata(source, weaponName)
		local tintIndex = metadata and tonumber(metadata.tint) or 0

		return tintIndex and math.max(math.floor(tintIndex), 0) or 0
	end

	if type(xPlayer.getWeaponTint) ~= 'function' then
		return 0
	end

	local checked, tintIndex = pcall(function()
		return xPlayer.getWeaponTint(weaponName)
	end)

	return checked and tonumber(tintIndex) or 0
end

---Sets a tint on an owned weapon.
---@param source number Player source
---@param xPlayer table ESX player object
---@param weaponName string
---@param tintIndex number
---@return boolean
function SetWeaponTint(source, xPlayer, weaponName, tintIndex)
	if Config.OxInventory then
		local slot, metadata = GetOxWeaponMetadata(source, weaponName)
		if not slot or not metadata then
			return false
		end

		metadata.tint = math.max(math.floor(tonumber(tintIndex) or 0), 0)

		return SetOxWeaponMetadata(source, slot, metadata)
	end

	if type(xPlayer.setWeaponTint) ~= 'function' then
		return false
	end

	local set = pcall(function()
		xPlayer.setWeaponTint(weaponName, tintIndex)
	end)

	return set
end
