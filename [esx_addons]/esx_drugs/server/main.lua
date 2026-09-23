-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local playersProcessingCannabis = {}
local playersPickingCannabis = {}
local playersSellingDrugs = {}

local PickupCooldown = 3500
local PickupDuration = 3000
local PickupDistance = 3.0
local PickupFieldDistance = 55.0
local ProcessDistance = 5.0
local SellDistance = 3.0
local SellCooldown = 1500
local MinCannabisPickup = 1
local MaxCannabisPickup = 3
local pickupLimiter = xLib.rateLimiter({ capacity = 1, refill = 1, interval = PickupCooldown, staleMs = 60000 })
local sellLimiter = xLib.rateLimiter({ capacity = 1, refill = 1, interval = SellCooldown, staleMs = 60000 })

local function NormalizeInteger(value, min, max)
	value = tonumber(value)

	if not value or value ~= math.floor(value) or value < min or value > max then
		return nil
	end

	return value
end

local function NormalizeCoords(coords)
	if not coords then
		return nil
	end

	local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
	if not x or not y or not z then
		return nil
	end

	return vector3(x, y, z)
end

local function GetPlayerCoords(src)
	local ped = GetPlayerPed(src)
	if not ped or ped == 0 then
		return nil
	end

	return GetEntityCoords(ped)
end

local function IsNearCoords(src, coords, distance)
	local playerCoords = GetPlayerCoords(src)
	if not playerCoords then
		return false
	end

	return #(playerCoords - coords) <= distance
end

local function ValidatePickupCannabis(src, plantCoords)
	local ECoords = Config.CircleZones.WeedField.coords
	local PCoords = GetPlayerCoords(src)
	plantCoords = NormalizeCoords(plantCoords)

	if not PCoords or not plantCoords then
		return false
	end

	if #(plantCoords - ECoords) > PickupFieldDistance then
		return false
	end

	return #(PCoords - plantCoords) <= PickupDistance and #(PCoords - ECoords) <= PickupFieldDistance
end

local function ValidateProcessCannabis(src)
	return IsNearCoords(src, Config.CircleZones.WeedProcessing.coords, ProcessDistance)
end

local function ValidateDrugDealer(src)
	return IsNearCoords(src, Config.CircleZones.DrugDealer.coords, SellDistance)
end

local function FoundExploiter(src,reason)
	-- ADD YOUR BAN EVENT HERE UNTIL THEN IT WILL ONLY KICK THE PLAYER --
	DropPlayer(src,reason)
end

RegisterServerEvent('esx_drugs:sellDrug')
AddEventHandler('esx_drugs:sellDrug', function(itemName, amount)
	local src = source
	local xPlayer = ESX.Player(src)

	if not xPlayer then
		return
	end

	local identifier = xPlayer.getIdentifier()
	-- If this fails its 99% a mod-menu, the variables client sided are setup to provide the exact right arguments
	if type(amount) ~= 'number' or type(itemName) ~= 'string' then
		print(('esx_drugs: %s attempted to sell with invalid input type!'):format(identifier))
		FoundExploiter(src,'SellDrugs Event Trigger')
		return
	end

	if playersSellingDrugs[src] then
		return
	end

	if not sellLimiter:consume(src) then
		return
	end

	if not ValidateDrugDealer(src) then
		print(('esx_drugs: %s attempted to sell away from the dealer!'):format(identifier))
		FoundExploiter(src,'SellDrugs Event Trigger')
		return
	end

	amount = NormalizeInteger(amount, Config.SellMenu.Min, Config.SellMenu.Max)
	if not amount then
		print(('esx_drugs: %s attempted to sell an invalid amount!'):format(identifier))
		FoundExploiter(src,'SellDrugs Event Trigger')
		return
	end

	local price = Config.DrugDealerItems[itemName]
	if not price then
		print(('esx_drugs: %s attempted to sell an invalid drug!'):format(identifier))
		return
	end

	local xItem = xPlayer.getInventoryItem(itemName)
	if xItem == nil or xItem.count < amount then
		xPlayer.showNotification(TranslateCap('dealer_notenough'))
		return
	end

	playersSellingDrugs[src] = true
	price = ESX.Math.Round(price * amount)

	local removed = xPlayer.removeInventoryItem(xItem.name, amount)
	if removed == false then
		playersSellingDrugs[src] = nil
		return
	end

	if Config.GiveBlack then
		xPlayer.addAccountMoney('black_money', price, "Drugs Sold")
	else
		xPlayer.addMoney(price, "Drugs Sold")
	end

	xPlayer.showNotification(TranslateCap('dealer_sold', amount, xItem.label, ESX.Math.GroupDigits(price)))
	playersSellingDrugs[src] = nil
end)

xLib.callback.registerCompat('esx_drugs:buyLicense', function(source, cb, licenseName)
	local xPlayer = ESX.Player(source)
	local license = Config.LicensePrices[licenseName]

	if license then
		if xPlayer.getMoney() >= license.price then
			xPlayer.removeMoney(license.price)

			TriggerEvent('esx_license:addLicense', source, licenseName, function()
				cb(true)
			end)
		else
			cb(false)
		end
	else
		print(('esx_drugs: %s attempted to buy an invalid license!'):format(xPlayer.getIdentifier()))
		cb(false)
	end
end)

RegisterServerEvent('esx_drugs:pickedUpCannabis')
AddEventHandler('esx_drugs:pickedUpCannabis', function(plantCoords)
	local src = source
	local xPlayer = ESX.Player(src)

	if not xPlayer then
		return
	end

	if playersPickingCannabis[src] then
		return
	end

	if not pickupLimiter:consume(src) then
		return
	end

	if ValidatePickupCannabis(src, plantCoords) then
		playersPickingCannabis[src] = true

		SetTimeout(PickupDuration, function()
			if not playersPickingCannabis[src] then
				return
			end

			playersPickingCannabis[src] = nil

			if not ValidatePickupCannabis(src, plantCoords) then
				return
			end

			local xPlayer = ESX.Player(src)
			if not xPlayer then
				return
			end

			local amount = math.random(MinCannabisPickup, MaxCannabisPickup)
			if xPlayer.canCarryItem('cannabis', amount) then
				xPlayer.addInventoryItem('cannabis', amount)
			else
				xPlayer.showNotification(TranslateCap('weed_inventoryfull'))
			end
		end)
	else
		FoundExploiter(src,'Event Trigger')
	end
end)

xLib.callback.registerCompat('esx_drugs:canPickUp', function(source, cb, item)
	if item ~= 'cannabis' then
		return cb(false)
	end

	local xPlayer = ESX.Player(source)
	cb(xPlayer and xPlayer.canCarryItem(item, 1) or false)
end)

RegisterServerEvent('esx_drugs:outofbound')
AddEventHandler('esx_drugs:outofbound', function()
	CancelProcessing(source)
end)

xLib.callback.registerCompat('esx_drugs:cannabis_count', function(source, cb)
	local xPlayer = ESX.Player(source)
	local xCannabis = xPlayer and xPlayer.getInventoryItem('cannabis')
	cb(xCannabis and xCannabis.count or 0)
end)

RegisterServerEvent('esx_drugs:processCannabis')
AddEventHandler('esx_drugs:processCannabis', function()
	local src = source

	if playersProcessingCannabis[src] then
		print(('esx_drugs: %s attempted to exploit weed processing!'):format(GetPlayerIdentifiers(src)[1]))
		return
	end

	if not ValidateProcessCannabis(src) then
		FoundExploiter(src,'Event Trigger')
		return
	end

	local xPlayer = ESX.Player(src)
	if not xPlayer then
		return
	end

	local xCannabis = xPlayer.getInventoryItem('cannabis')
	if not xCannabis or xCannabis.count < 3 then
		xPlayer.showNotification(TranslateCap('weed_processingenough'))
		return
	end

	playersProcessingCannabis[src] = true

	CreateThread(function()
		while playersProcessingCannabis[src] do
			Wait(Config.Delays.WeedProcessing)

			if not playersProcessingCannabis[src] then
				break
			end

			local xPlayer = ESX.Player(src)
			if not xPlayer then
				break
			end

			if not ValidateProcessCannabis(src) then
				xPlayer.showNotification(TranslateCap('weed_processingtoofar'))
				break
			end

			local xCannabis = xPlayer.getInventoryItem('cannabis')
			if not xCannabis or xCannabis.count < 3 then
				xPlayer.showNotification(TranslateCap('weed_processingenough'))
				break
			end

			if not xPlayer.canSwapItem('cannabis', 3, 'marijuana', 1) then
				xPlayer.showNotification(TranslateCap('weed_processingfull'))
				break
			end

			local removed = xPlayer.removeInventoryItem('cannabis', 3)
			if removed == false then
				break
			end

			local added = xPlayer.addInventoryItem('marijuana', 1)
			if added == false then
				xPlayer.addInventoryItem('cannabis', 3)
				break
			end

			xPlayer.showNotification(TranslateCap('weed_processed'))
		end

		playersProcessingCannabis[src] = nil
	end)
end)

function CancelProcessing(playerId)
	if playersProcessingCannabis[playerId] then
		playersProcessingCannabis[playerId] = nil
	end
end

RegisterServerEvent('esx_drugs:cancelProcessing')
AddEventHandler('esx_drugs:cancelProcessing', function()
	CancelProcessing(source)
end)

AddEventHandler('esx:playerDropped', function(playerId, reason)
	CancelProcessing(playerId)
	playersPickingCannabis[playerId] = nil
	playersSellingDrugs[playerId] = nil
end)

RegisterServerEvent('esx:onPlayerDeath')
AddEventHandler('esx:onPlayerDeath', function(data)
	CancelProcessing(source)
	playersPickingCannabis[source] = nil
end)
