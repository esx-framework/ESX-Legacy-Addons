-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local activeRequests = {}
local requestCooldowns = {}
local ammoStateRequests = {}
local ammoStateRequestId = 0

local function GetRequestKey(source, action)
	return ('%s:%s'):format(source, action)
end

local function BeginRequest(source, action)
	local key = GetRequestKey(source, action)
	local now = GetGameTimer()
	local cooldown = tonumber(Config.PurchaseCooldown) or 750

	if activeRequests[key] or (requestCooldowns[key] and requestCooldowns[key] > now) then
		return nil
	end

	activeRequests[key] = true
	requestCooldowns[key] = now + math.max(cooldown, 0)
	return key
end

local function EndRequest(key)
	if key then
		activeRequests[key] = nil
	end
end

local function GetPlayerIdentifier(xPlayer)
	if not xPlayer then
		return nil
	end

	if type(xPlayer.getIdentifier) == 'function' then
		local ok, identifier = pcall(xPlayer.getIdentifier)
		if ok and type(identifier) == 'string' then
			return identifier
		end
	end

	return type(xPlayer.identifier) == 'string' and xPlayer.identifier or nil
end

local function ValidateSamePlayer(source, expectedIdentifier)
	local xPlayer = ValidatePlayer(source)

	if not xPlayer or GetPlayerIdentifier(xPlayer) ~= expectedIdentifier then
		return nil
	end

	return xPlayer
end

local function NormalizeUpgradePrice(price)
	local value = tonumber(price)

	if not value or value ~= value or value == math.huge or value == -math.huge or value < 0 then
		return nil
	end

	local integerValue = math.floor(value)
	if integerValue ~= value then
		return nil
	end

	return integerValue
end

local function CanPayForUpgrade(xPlayer, isBlackMarket, price)
	price = NormalizeUpgradePrice(price)
	if not price then
		return false
	end

	if price == 0 then
		return true
	end

	return CanPayForWeapon(xPlayer, isBlackMarket, price)
end

local function TakeUpgradePayment(xPlayer, isBlackMarket, price)
	price = NormalizeUpgradePrice(price)
	if not price then
		return false
	end

	if price == 0 then
		return true
	end

	return TakeWeaponPayment(xPlayer, isBlackMarket, price)
end

local function RefundUpgradePayment(xPlayer, isBlackMarket, price)
	price = NormalizeUpgradePrice(price)
	if not price or price == 0 then
		return
	end

	RefundWeaponPayment(xPlayer, isBlackMarket, price)
end

local function CompleteAmmoStateRequest(requestId, ammoState)
	local request = ammoStateRequests[requestId]
	if not request then
		return
	end

	ammoStateRequests[requestId] = nil
	request.cb(ammoState)
end

local function RequestClientWeaponAmmoState(source, weaponName, cb)
	local timeout = tonumber(Config.ClientCallbackTimeout) or tonumber(Config.LicenseCallbackTimeout) or 5000
	ammoStateRequestId = ammoStateRequestId + 1

	if ammoStateRequestId > 1000000 then
		ammoStateRequestId = 1
	end

	local requestId = ('%s:%s:%s'):format(source, GetGameTimer(), ammoStateRequestId)
	ammoStateRequests[requestId] = {
		source = source,
		cb = cb
	}

	local triggered = pcall(function()
		TriggerClientEvent('esx_weaponshop:requestWeaponAmmoState', source, requestId, weaponName)
	end)

	if not triggered then
		CompleteAmmoStateRequest(requestId, nil)
		return
	end

	SetTimeout(timeout, function()
		CompleteAmmoStateRequest(requestId, nil)
	end)
end

AddEventHandler('playerDropped', function()
	local prefix = tostring(source) .. ':'

	for key in pairs(activeRequests) do
		if key:sub(1, #prefix) == prefix then
			activeRequests[key] = nil
		end
	end

	for key in pairs(requestCooldowns) do
		if key:sub(1, #prefix) == prefix then
			requestCooldowns[key] = nil
		end
	end

	for key, request in pairs(ammoStateRequests) do
		if request.source == source then
			ammoStateRequests[key] = nil
		end
	end
end)

RegisterNetEvent('esx_weaponshop:receiveWeaponAmmoState', function(requestId, ammoState)
	local request = ammoStateRequests[requestId]
	if not request or request.source ~= source then
		return
	end

	CompleteAmmoStateRequest(requestId, ammoState)
end)

---Handles weapon license purchase requests
---@param source number Player source
---@param cb function Callback function(success)
function ProcessLicensePurchase(source, cb)
	local requestKey = BeginRequest(source, 'license')
	if not requestKey then
		cb(false)
		return
	end

	local function finish(success)
		EndRequest(requestKey)
		cb(success and true or false)
	end

	local xPlayer = ValidatePlayer(source)
	local licensePrice = NormalizeMoneyAmount(Config.LicensePrice)

	if not xPlayer then
		finish(false)
		return
	end

	local identifier = GetPlayerIdentifier(xPlayer)
	if not identifier then
		finish(false)
		return
	end

	if not Config.LicenseEnable then
		finish(false)
		return
	end

	if not ValidatePlayerNearLicenseShop(source) then
		finish(false)
		return
	end

	if not IsLicenseResourceAvailable() then
		finish(false)
		return
	end

	if not licensePrice then
		finish(false)
		return
	end

	if not CanPayForWeapon(xPlayer, false, licensePrice) then
		finish(false)
		return
	end

	CheckWeaponLicense(source, function(hasLicense)
		if hasLicense ~= false then
			finish(false)
			return
		end

		xPlayer = ValidateSamePlayer(source, identifier)
		if not xPlayer then
			finish(false)
			return
		end

		if not ValidatePlayerNearLicenseShop(source) then
			finish(false)
			return
		end

		if not CanPayForWeapon(xPlayer, false, licensePrice) then
			finish(false)
			return
		end

		if not TakeWeaponPayment(xPlayer, false, licensePrice, 'Weapon License') then
			finish(false)
			return
		end

		AddWeaponLicense(source, function(added, reason)
			if added then
				finish(true)
				return
			end

			if reason ~= 'timeout' then
				xPlayer = ValidateSamePlayer(source, identifier)
			end

			if reason ~= 'timeout' and xPlayer then
				RefundWeaponPayment(xPlayer, false, licensePrice, 'Weapon License Refund')
			end

			finish(false)
		end)
	end)
end

---Handles weapon purchase requests from clients
---@param source number Player source
---@param weaponName string
---@param zone string Shop zone
---@param cb function Callback function(success)
function ProcessWeaponPurchase(source, weaponName, zone, cb)
	local requestKey = BeginRequest(source, 'weapon')
	if not requestKey then
		cb(false)
		return
	end

	local function finish(success)
		EndRequest(requestKey)
		cb(success and true or false)
	end

	local xPlayer = ValidatePlayer(source)

	if not xPlayer then
		finish(false)
		return
	end

	local identifier = GetPlayerIdentifier(xPlayer)
	if not identifier then
		finish(false)
		return
	end

	if not ValidateZone(zone, source) or not ValidateWeaponName(weaponName, source) then
		finish(false)
		return
	end

	if not ValidatePlayerNearZone(source, zone) then
		finish(false)
		return
	end

	local price = GetPrice(weaponName, zone)

	if price <= 0 then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to buy Invalid weapon - %s!'):format(
			source,
			tostring(weaponName)
		))
		finish(false)
		return
	end

	local zoneConfig = Config.Zones[zone]
	local isBlackMarket = zoneConfig and zoneConfig.Legal == false

	CheckRequiredWeaponLicense(source, zone, function(hasRequiredLicense)
		if not hasRequiredLicense then
			finish(false)
			return
		end

		xPlayer = ValidateSamePlayer(source, identifier)
		if not xPlayer then
			finish(false)
			return
		end

		if not ValidatePlayerNearZone(source, zone) then
			finish(false)
			return
		end

		if not CanReceiveWeapon(source, xPlayer, weaponName) then
			finish(false)
			return
		end

		if not CanPayForWeapon(xPlayer, isBlackMarket, price) then
			finish(false)
			return
		end

		if not TakeWeaponPayment(xPlayer, isBlackMarket, price) then
			finish(false)
			return
		end

		if not AddWeapon(source, xPlayer, weaponName) then
			xPlayer = ValidateSamePlayer(source, identifier)
			if xPlayer then
				RefundWeaponPayment(xPlayer, isBlackMarket, price)
			end

			finish(false)
			return
		end

		finish(true)
	end)
end

local function ProcessAmmoPurchase(source, xPlayer, weaponName, isBlackMarket, data, zone, identifier, cb)
	local upgrades = BuildWeaponUpgrades(weaponName)
	local ammo = upgrades.ammo
	local amount = NormalizeAmmoAmount(data.amount)

	if not ammo or not amount then
		cb(false)
		return
	end

	local pricePerRound = NormalizeUpgradePrice(ammo.pricePerRound)
	if not pricePerRound then
		cb(false)
		return
	end

	local price = amount * pricePerRound

	RequestClientWeaponAmmoState(source, weaponName, function(ammoState)
		xPlayer = ValidateSamePlayer(source, identifier)
		if not xPlayer then
			cb(false)
			return
		end

		if not ValidatePlayerNearZone(source, zone) then
			cb(false)
			return
		end

		if not HasPlayerWeapon(source, xPlayer, weaponName) then
			xPlayer.showNotification(TranslateCap('requires_weapon'))
			cb(false)
			return
		end

		if not CanAddWeaponAmmo(source, xPlayer, weaponName, amount, ammoState) then
			cb(false)
			return
		end

		if not CanPayForUpgrade(xPlayer, isBlackMarket, price) then
			cb(false)
			return
		end

		if not TakeUpgradePayment(xPlayer, isBlackMarket, price) then
			cb(false)
			return
		end

		if AddWeaponAmmo(source, xPlayer, weaponName, amount) then
			cb(true)
			return
		end

		xPlayer = ValidatePlayer(source)
		if xPlayer then
			RefundUpgradePayment(xPlayer, isBlackMarket, price)
		end

		cb(false)
	end)
end

local function ProcessComponentPurchase(source, xPlayer, weaponName, isBlackMarket, data)
	if not ValidateUpgradeIdentifier(data.componentName, 'component', source) then
		return false
	end

	local component = GetWeaponShopComponentUpgrade(weaponName, data.componentName)
	if not component then
		print(('[^3WARNING^7] Player ^5%s^7 attempted invalid weapon component purchase - %s:%s!'):format(
			source,
			tostring(weaponName),
			tostring(data.componentName)
		))
		return false
	end

	if HasWeaponComponent(source, xPlayer, weaponName, component.name) then
		xPlayer.showNotification(TranslateCap('already_owned'))
		return false
	end

	local price = NormalizeUpgradePrice(component.price)
	if not price then
		return false
	end

	if not CanPayForUpgrade(xPlayer, isBlackMarket, price) then
		return false
	end

	if not TakeUpgradePayment(xPlayer, isBlackMarket, price) then
		return false
	end

	if AddWeaponComponent(source, xPlayer, weaponName, component.name) and HasWeaponComponent(source, xPlayer, weaponName, component.name) then
		return true
	end

	xPlayer = ValidatePlayer(source)
	if xPlayer then
		RefundUpgradePayment(xPlayer, isBlackMarket, price)
	end

	return false
end

local function ProcessTintPurchase(source, xPlayer, weaponName, isBlackMarket, data)
	local tintIndex = tonumber(data.tintIndex)

	if not tintIndex or tintIndex ~= math.floor(tintIndex) then
		return false
	end

	local tint = GetWeaponShopTintUpgrade(weaponName, tintIndex)
	if not tint then
		print(('[^3WARNING^7] Player ^5%s^7 attempted invalid weapon tint purchase - %s:%s!'):format(
			source,
			tostring(weaponName),
			tostring(data.tintIndex)
		))
		return false
	end

	if GetWeaponTint(source, xPlayer, weaponName) == tint.index then
		xPlayer.showNotification(TranslateCap('equipped'))
		return false
	end

	local price = NormalizeUpgradePrice(tint.price)
	if not price then
		return false
	end

	if not CanPayForUpgrade(xPlayer, isBlackMarket, price) then
		return false
	end

	if not TakeUpgradePayment(xPlayer, isBlackMarket, price) then
		return false
	end

	if SetWeaponTint(source, xPlayer, weaponName, tint.index) and GetWeaponTint(source, xPlayer, weaponName) == tint.index then
		return true
	end

	xPlayer = ValidatePlayer(source)
	if xPlayer then
		RefundUpgradePayment(xPlayer, isBlackMarket, price)
	end

	return false
end

---Handles weapon upgrade purchase requests from clients
---@param source number Player source
---@param data table Purchase payload
---@param zone string Shop zone
---@param cb function Callback function(success)
function ProcessWeaponUpgradePurchase(source, data, zone, cb)
	local requestKey = BeginRequest(source, 'upgrade')
	if not requestKey then
		cb(false)
		return
	end

	local function finish(success)
		EndRequest(requestKey)
		cb(success and true or false)
	end

	if type(data) ~= 'table' then
		finish(false)
		return
	end

	local weaponName = data.weaponName
	local action = data.action
	local xPlayer = ValidatePlayer(source)

	if not xPlayer then
		finish(false)
		return
	end

	local identifier = GetPlayerIdentifier(xPlayer)
	if not identifier then
		finish(false)
		return
	end

	if not AreWeaponShopUpgradesSupported() then
		xPlayer.showNotification(TranslateCap('unavailable'))
		finish(false)
		return
	end

	if not ValidateZone(zone, source) or not ValidateWeaponName(weaponName, source) then
		finish(false)
		return
	end

	if not ValidateUpgradeIdentifier(action, 'upgrade action', source) then
		finish(false)
		return
	end

	if not GetZoneWeaponEntry(weaponName, zone) then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to upgrade weapon outside zone stock - %s:%s!'):format(
			source,
			tostring(zone),
			tostring(weaponName)
		))
		finish(false)
		return
	end

	if not ValidatePlayerNearZone(source, zone) then
		finish(false)
		return
	end

	local zoneConfig = Config.Zones[zone]
	local isBlackMarket = zoneConfig and zoneConfig.Legal == false

	CheckRequiredWeaponLicense(source, zone, function(hasRequiredLicense)
		if not hasRequiredLicense then
			finish(false)
			return
		end

		xPlayer = ValidateSamePlayer(source, identifier)
		if not xPlayer then
			finish(false)
			return
		end

		if not ValidatePlayerNearZone(source, zone) then
			finish(false)
			return
		end

		if not HasPlayerWeapon(source, xPlayer, weaponName) then
			xPlayer.showNotification(TranslateCap('requires_weapon'))
			finish(false)
			return
		end

		if action == 'ammo' then
			ProcessAmmoPurchase(source, xPlayer, weaponName, isBlackMarket, data, zone, identifier, finish)
			return
		end

		if action == 'component' then
			finish(ProcessComponentPurchase(source, xPlayer, weaponName, isBlackMarket, data))
			return
		end

		if action == 'tint' then
			finish(ProcessTintPurchase(source, xPlayer, weaponName, isBlackMarket, data))
			return
		end

		print(('[^3WARNING^7] Player ^5%s^7 attempted invalid weaponshop upgrade action - %s!'):format(
			source,
			tostring(action)
		))
		finish(false)
	end)
end
