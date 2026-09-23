-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local PendingAccessoryPurchases = {}
local ValidAccessories = {
	ears = 'Ears',
	mask = 'Mask',
	helmet = 'Helmet',
	glasses = 'Glasses'
}

local function normalizeAccessory(accessory)
	return ValidAccessories[string.lower(tostring(accessory or ''))]
end

local function isNearAccessoryShop(source, accessory)
	local ped = GetPlayerPed(source)
	local zone = Config.Zones[accessory]
	if ped <= 0 or not zone or type(zone.Pos) ~= 'table' then return false end

	local coords = GetEntityCoords(ped)
	for i = 1, #zone.Pos do
		if #(coords - zone.Pos[i]) <= (Config.ShopDistance or 3.0) then
			return true
		end
	end

	return false
end

local function beginAccessoryPurchase(source, accessory)
	local xPlayer = ESX.Player(source)
	accessory = normalizeAccessory(accessory)

	if not xPlayer or not accessory or not isNearAccessoryShop(source, accessory) or xPlayer.getMoney() < Config.Price then
		return false
	end

	xPlayer.removeMoney(Config.Price, "Accessory Purchase")
	PendingAccessoryPurchases[source] = PendingAccessoryPurchases[source] or {}
	PendingAccessoryPurchases[source][accessory] = GetGameTimer() + (Config.PurchaseSessionDuration or 60000)

	TriggerClientEvent('esx:showNotification', source, TranslateCap('you_paid', ESX.Math.GroupDigits(Config.Price)))
	return true
end

RegisterServerEvent('esx_accessories:pay')
AddEventHandler('esx_accessories:pay', function(accessory)
	beginAccessoryPurchase(source, accessory)
end)

RegisterServerEvent('esx_accessories:save')
AddEventHandler('esx_accessories:save', function(skin, accessory)
	local source = source
	local xPlayer = ESX.Player(source)
	accessory = normalizeAccessory(accessory)

	if not xPlayer or not accessory or type(skin) ~= 'table' or not isNearAccessoryShop(source, accessory) then return end
	if not PendingAccessoryPurchases[source] or not PendingAccessoryPurchases[source][accessory] or PendingAccessoryPurchases[source][accessory] < GetGameTimer() then return end

	TriggerEvent('esx_datastore:getDataStore', 'user_' .. string.lower(accessory), xPlayer.getIdentifier(), function(store)
		store.set('has' .. accessory, true)

		local itemSkin = {}
		local item1 = string.lower(accessory) .. '_1'
		local item2 = string.lower(accessory) .. '_2'
		if skin[item1] == nil or skin[item2] == nil then return end

		itemSkin[item1] = skin[item1]
		itemSkin[item2] = skin[item2]

		store.set('skin', itemSkin)
		PendingAccessoryPurchases[source][accessory] = nil
	end)
end)

xLib.callback.registerCompat('esx_accessories:get', function(source, cb, accessory)
	local xPlayer = ESX.Player(source)
	accessory = normalizeAccessory(accessory)
	if not xPlayer or not accessory then return cb(false, {}) end

	TriggerEvent('esx_datastore:getDataStore', 'user_' .. string.lower(accessory), xPlayer.getIdentifier(), function(store)
		local hasAccessory = (store.get('has' .. accessory) and store.get('has' .. accessory) or false)
		local skin = (store.get('skin') and store.get('skin') or {})

		cb(hasAccessory, skin)
	end)

end)

xLib.callback.registerCompat('esx_accessories:buy', function(source, cb, accessory)
	cb(beginAccessoryPurchase(source, accessory))
end)

xLib.callback.registerCompat('esx_accessories:checkMoney', function(source, cb, accessory)
	local xPlayer = ESX.Player(source)

	cb(xPlayer and normalizeAccessory(accessory) and isNearAccessoryShop(source, normalizeAccessory(accessory)) and xPlayer.getMoney() >= Config.Price)
end)

AddEventHandler('esx:playerDropped', function(playerId)
	PendingAccessoryPurchases[playerId] = nil
end)
