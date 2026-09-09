-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local ClothesPurchases = {}

local function isNearClothesShop(source)
	local ped = GetPlayerPed(source)
	if ped <= 0 then return false end

	local coords = GetEntityCoords(ped)
	for i = 1, #Config.Shops do
		if #(coords - Config.Shops[i]) <= (Config.ShopDistance or 3.0) then
			return true
		end
	end

	return false
end

local function sanitizeOutfitLabel(label)
	label = tostring(label or ''):gsub('[%c]', ' ')
	label = label:gsub('^%s+', ''):gsub('%s+$', '')

	if label == '' then return nil end

	return label:sub(1, Config.MaxOutfitLabelLength or 40)
end

local function calculatePurchaseCost(newSkin, oldSkin)
	if not Config.ChargePerPiece then
		return Config.Price
	end

	if type(newSkin) ~= 'table' or type(oldSkin) ~= 'table' then
		return Config.Price
	end

	local purchaseCost = 0
	for _, value in pairs(Config.SkinProps) do
		if (newSkin[value .. '_1'] ~= oldSkin[value .. '_1']) or (newSkin[value .. '_2'] ~= oldSkin[value .. '_2']) then
			purchaseCost = purchaseCost + Config.Price
		end
	end

	return math.max(Config.Price, purchaseCost)
end

RegisterServerEvent('esx_clotheshop:saveOutfit')
AddEventHandler('esx_clotheshop:saveOutfit', function(label, skin)
	local source = source
	local xPlayer = ESX.Player(source)
	label = sanitizeOutfitLabel(label)

	if not xPlayer or not label or type(skin) ~= 'table' or not ClothesPurchases[source] or ClothesPurchases[source] < GetGameTimer() then return end

	TriggerEvent('esx_datastore:getDataStore', 'property', xPlayer.getIdentifier(), function(store)
		local dressing = store.get('dressing')

		if dressing == nil then
			dressing = {}
		end

		if #dressing >= (Config.MaxOutfits or 20) then
			return
		end

		table.insert(dressing, {
			label = label,
			skin  = skin
		})

		store.set('dressing', dressing)
		store.save()
		ClothesPurchases[source] = nil
	end)
end)

xLib.callback.registerCompat('esx_clotheshop:buyClothes', function(source, cb, newSkin, oldSkin)
	local xPlayer = ESX.Player(source)
	local purchaseCost = calculatePurchaseCost(newSkin, oldSkin)

	if not xPlayer or type(newSkin) ~= 'table' or not isNearClothesShop(source) then
		return cb(false)
	end

	if xPlayer.getMoney() >= purchaseCost then
		xPlayer.removeMoney(purchaseCost, "Outfit Purchase")
		ClothesPurchases[source] = GetGameTimer() + (Config.PurchaseSessionDuration or 60000)
		TriggerClientEvent('esx:showNotification', source, TranslateCap('you_paid', purchaseCost))
		cb(true)
	else
		cb(false)
	end
end)

xLib.callback.registerCompat('esx_clotheshop:checkPropertyDataStore', function(source, cb)
	local xPlayer = ESX.Player(source)
	local foundStore = false
	if not xPlayer then return cb(false) end

	TriggerEvent('esx_datastore:getDataStore', 'property', xPlayer.getIdentifier(), function(store)
		foundStore = true
	end)

	cb(foundStore)
end)

AddEventHandler('esx:playerDropped', function(playerId)
	ClothesPurchases[playerId] = nil
end)
