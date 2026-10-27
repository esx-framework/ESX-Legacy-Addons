-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

ESXCatalog.awaitReady()

local PendingAccessoryPurchases = {}
local purchaseLimiter = xLib.rateLimiter({ capacity = 2, refill = 1, interval = 2000 })
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

local function beginAccessoryPurchase(source, accessory, account)
    local xPlayer = ESX.GetPlayerFromId(source)
    accessory = normalizeAccessory(accessory)

    if not xPlayer or not accessory or not isNearAccessoryShop(source, accessory) then
        return false
    end

    if not purchaseLimiter:consume(source) then
        return false, 'busy'
    end

    local purchases = PendingAccessoryPurchases[source]
    local pending = purchases and purchases[accessory]

    if pending and pending.player.isCurrent() == true and pending.expires >= GetGameTimer() then
        return false, 'busy'
    end

    local charged, failure =
        PaymentGateway.Charge(xPlayer, account, Config.Price, "Accessory Purchase")

    if not charged then
        return false, failure
    end

    PendingAccessoryPurchases[source] = purchases or {}
    PendingAccessoryPurchases[source][accessory] = {
        player = xPlayer,
        expires = GetGameTimer() + (Config.PurchaseSessionDuration or 60000),
    }

    TriggerClientEvent('esx:showNotification', source,
        TranslateCap('you_paid', ESX.Math.GroupDigits(Config.Price)))
    return true
end

RegisterServerEvent('esx_accessories:pay')
AddEventHandler('esx_accessories:pay', function(accessory)
	beginAccessoryPurchase(source, accessory)
end)

RegisterServerEvent('esx_accessories:save')
AddEventHandler('esx_accessories:save', function(skin, accessory)
    local playerId = source
    accessory = normalizeAccessory(accessory)

    if not accessory or type(skin) ~= 'table' then
        return
    end

    local purchases = PendingAccessoryPurchases[playerId]
    local pending = purchases and purchases[accessory]

    if not pending or pending.expires < GetGameTimer() then
        return
    end

    local player = pending.player

    if player.isCurrent() ~= true or not isNearAccessoryShop(playerId, accessory) then
        return
    end

    local name = string.lower(accessory)
    local item1, item2 = name .. '_1', name .. '_2'
    local minimum = accessory == 'Mask' and 0 or -1
    local itemSkin = {}

    for _, field in ipairs({ item1, item2 }) do
        local value = skin[field]
        local lowerBound = field == item1 and minimum or 0

        if type(value) ~= 'number' or value ~= value or value % 1 ~= 0 then
            return
        end

        if value < lowerBound or value > 4095 then
            return
        end

        itemSkin[field] = value
    end

    purchases[accessory] = nil

    local identifier = player.getIdentifier()

    TriggerEvent('esx_datastore:getDataStore', 'user_' .. name, identifier, function(store)
        if player.isCurrent() ~= true then
            return
        end

        if not store then
            return
        end

        store.set('skin', itemSkin)
        store.set('has' .. accessory, true)
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

xLib.callback.registerCompat('esx_accessories:buy', function(source, cb, accessory, account)
	cb(beginAccessoryPurchase(source, accessory, account))
end)

xLib.callback.registerCompat('esx_accessories:checkMoney', function(source, cb, accessory)
	local xPlayer = ESX.Player(source)

	cb(xPlayer and normalizeAccessory(accessory) and isNearAccessoryShop(source, normalizeAccessory(accessory)) and xPlayer.getMoney() >= Config.Price)
end)

AddEventHandler('esx:playerDropped', function(playerId)
	PendingAccessoryPurchases[playerId] = nil
end)
