-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local categories, vehicles = {}, {}
local vehiclesByModel = {}
local normalizePlate = xLib.vehiclePlate.normalize

local function generateServerPlate()
	return xLib.vehiclePlate.generateUnique({
		letters = Config.PlateLetters,
		numbers = Config.PlateNumbers,
		useSpace = Config.PlateUseSpace
	}, function(plate)
		local owned = MySQL.scalar.await('SELECT plate FROM owned_vehicles WHERE plate = ?', {plate})
		local rented = MySQL.scalar.await('SELECT plate FROM rented_vehicles WHERE plate = ?', {plate})
		return owned ~= nil or rented ~= nil
	end)
end

local function isNear(source, coords, distance)
	local nearby = xLib.player.isNearCoords(source, coords, distance)
	return nearby
end
local getValidCount = xLib.validation.count

local function canUseCardealerStock(xPlayer, source)
	return xPlayer and xPlayer.getJob().name == 'cardealer' and isNear(source, Config.Zones.BossActions.Pos, 8.0)
end

local function canUseCardealerShowroom(xPlayer, source)
	return xPlayer and xPlayer.getJob().name == 'cardealer' and isNear(source, Config.Zones.ShopInside.Pos, 30.0)
end

local function canUseCardealerReseller(xPlayer, source)
	return xPlayer and xPlayer.getJob().name == 'cardealer' and isNear(source, Config.Zones.ResellVehicle.Pos, 12.0)
end

local function getRentalPrice(basePrice)
	basePrice = tonumber(basePrice)
	if not basePrice then return nil end

	local multiplier = tonumber(Config.RentalPriceMultiplier) or 0.05
	local minimum = tonumber(Config.MinimumRentalPrice) or 1

	return math.max(minimum, ESX.Math.Round(basePrice * multiplier))
end

local function isNearVehicleWithPlate(source, plate, distance)
	local ped = GetPlayerPed(source)
	if not ped or ped <= 0 then return false end

	local playerCoords = GetEntityCoords(ped)
	local currentVehicle = GetVehiclePedIsIn(ped, false)
	if currentVehicle and currentVehicle ~= 0 and normalizePlate(GetVehicleNumberPlateText(currentVehicle)) == plate then
		return true
	end

	for _, vehicle in ipairs(GetAllVehicles()) do
		if DoesEntityExist(vehicle) and normalizePlate(GetVehicleNumberPlateText(vehicle)) == plate and #(GetEntityCoords(vehicle) - playerCoords) <= (distance or 8.0) then
			return true
		end
	end

	return false
end

CreateThread(function()
	exports["esx_society"]:registerSociety('cardealer', TranslateCap('car_dealer'), 'society_cardealer', 'society_cardealer', 'society_cardealer', {type = 'private'})
end)

CreateThread(function()
	local char = Config.PlateLetters
	char = char + Config.PlateNumbers
	if Config.PlateUseSpace then char = char + 1 end

	if char > 8 then
		print(('[^3WARNING^7] Character Limit Exceeded, ^5%s/8^7!'):format(char))
	end
end)

function RemoveOwnedVehicle(plate)
	MySQL.update('DELETE FROM owned_vehicles WHERE plate = ?', {plate})
end

AddEventHandler('onResourceStart', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		SQLVehiclesAndCategories()
	end
end)

function SQLVehiclesAndCategories()
	categories = MySQL.query.await('SELECT * FROM vehicle_categories')
	vehicles = MySQL.query.await('SELECT vehicles.*, vehicle_categories.label AS categoryLabel FROM vehicles JOIN vehicle_categories ON vehicles.category = vehicle_categories.name')

	for _, vehicle in pairs(vehicles) do
		vehiclesByModel[vehicle.model] = vehicle
	end

	TriggerClientEvent("esx_vehicleshop:updateVehiclesAndCategories", -1, vehicles, categories, vehiclesByModel)
end

function getVehicleFromModel(model)
	return vehiclesByModel[model]
end

RegisterNetEvent("esx_vehicleshop:getVehiclesAndCategories", function()
	TriggerClientEvent("esx_vehicleshop:updateVehiclesAndCategories", source, vehicles, categories, vehiclesByModel)
end)

RegisterNetEvent('esx_vehicleshop:setVehicleOwnedPlayerId')
AddEventHandler('esx_vehicleshop:setVehicleOwnedPlayerId', function(playerId, vehicleProps, model, label)
	local xPlayer, xTarget = ESX.Player(source), ESX.Player(playerId)
	local vehicleData = type(model) == 'string' and getVehicleFromModel(model)

	if not canUseCardealerShowroom(xPlayer, source) or not xTarget or type(vehicleProps) ~= 'table' or not vehicleData then
		return
	end
	local plate = generateServerPlate()
	if not plate then
		return
	end
	vehicleProps = {plate = plate, model = joaat(model)}

	local xTargetName = xTarget.getName()
	MySQL.scalar('SELECT id FROM cardealer_vehicles WHERE vehicle = ?', {model},
	function(id)
		if not id then
			return
		end

		MySQL.insert('INSERT INTO owned_vehicles (owner, plate, vehicle) VALUES (?, ?, ?)', {xTarget.getIdentifier(), vehicleProps.plate, json.encode(vehicleProps)},
		function(insertId)
			if not insertId then return end

			MySQL.update('DELETE FROM cardealer_vehicles WHERE id = ?', {id},
			function(rowsChanged)
				if rowsChanged ~= 1 then
					MySQL.update('DELETE FROM owned_vehicles WHERE plate = ? AND owner = ?', {vehicleProps.plate, xTarget.getIdentifier()})
					return
				end

				xPlayer.showNotification(TranslateCap('vehicle_set_owned', vehicleProps.plate, xTargetName))
				xTarget.showNotification(TranslateCap('vehicle_belongs', vehicleProps.plate))
				MySQL.insert('INSERT INTO vehicle_sold (client, model, plate, soldby, date) VALUES (?, ?, ?, ?, ?)', {xTargetName, label or vehicleData.name or model, vehicleProps.plate, xPlayer.getName(), os.date('%Y-%m-%d %H:%M')})
			end)
		end)
	end)
end)

xLib.callback.registerCompat('esx_vehicleshop:getSoldVehicles', function(source, cb)
	local xPlayer = ESX.Player(source)
	if not canUseCardealerStock(xPlayer, source) and not canUseCardealerReseller(xPlayer, source) then return cb({}) end

	MySQL.query('SELECT client, model, plate, soldby, date FROM vehicle_sold ORDER BY DATE DESC', function(result)
		cb(result)
	end)
end)

RegisterNetEvent('esx_vehicleshop:rentVehicle')
AddEventHandler('esx_vehicleshop:rentVehicle', function(vehicle, plate, rentPrice, playerId)
	local xPlayer, xTarget = ESX.Player(source), ESX.Player(playerId)

	if not canUseCardealerShowroom(xPlayer, source) or not xTarget or not getVehicleFromModel(vehicle) then
		return
	end
	local xTargetName = xTarget.getName()
	MySQL.single('SELECT id, price FROM cardealer_vehicles WHERE vehicle = ?', {vehicle},
	function(result)
		if not result then
			return
		end

		local generatedPlate = generateServerPlate()
		local serverRentPrice = getRentalPrice(result.price)
		if not generatedPlate or not serverRentPrice then return end

		MySQL.insert('INSERT INTO rented_vehicles (vehicle, plate, player_name, base_price, rent_price, owner) VALUES (?, ?, ?, ?, ?, ?)', {vehicle, generatedPlate, xTargetName, result.price, serverRentPrice, xTarget.getIdentifier()},
		function(insertId)
			if not insertId then return end

			MySQL.update('DELETE FROM cardealer_vehicles WHERE id = ?', {result.id},
			function(rowsChanged)
				if rowsChanged ~= 1 then
					MySQL.update('DELETE FROM rented_vehicles WHERE plate = ? AND owner = ?', {generatedPlate, xTarget.getIdentifier()})
					return
				end

				xPlayer.showNotification(TranslateCap('vehicle_set_rented', generatedPlate, xTargetName))
			end)
		end)
	end)
end)

RegisterNetEvent('esx_vehicleshop:getStockItem')
AddEventHandler('esx_vehicleshop:getStockItem', function(itemName, count)
	local source = source
	local xPlayer = ESX.Player(source)
	count = getValidCount(count)

	if not count or (not canUseCardealerStock(xPlayer, source) and not canUseCardealerReseller(xPlayer, source)) then
		print(('[^3WARNING^7] Player ^5%s^7 attempted invalid cardealer stock withdrawal!'):format(source))
		return
	end

	TriggerEvent('esx_addoninventory:getSharedInventory', 'society_cardealer', function(inventory)
		local item = inventory.getItem(itemName)

		-- is there enough in the society?
		if count > 0 and item.count >= count then

			-- can the player carry the said amount of x item?
			if not xPlayer.canCarryItem(itemName, count) then
				return xPlayer.showNotification(TranslateCap('player_cannot_hold'))
			end
			inventory.removeItem(itemName, count)
			xPlayer.addInventoryItem(itemName, count)
			xPlayer.showNotification(TranslateCap('have_withdrawn', count, item.label))
		else
			xPlayer.showNotification(TranslateCap('not_enough_in_society'))
		end
	end)
end)

RegisterNetEvent('esx_vehicleshop:putStockItems')
AddEventHandler('esx_vehicleshop:putStockItems', function(itemName, count)
	local source = source
	local xPlayer = ESX.Player(source)
	count = getValidCount(count)

	if not count or (not canUseCardealerStock(xPlayer, source) and not canUseCardealerReseller(xPlayer, source)) then
		print(('[^3WARNING^7] Player ^5%s^7 attempted invalid cardealer stock deposit!'):format(source))
		return
	end

	TriggerEvent('esx_addoninventory:getSharedInventory', 'society_cardealer', function(inventory)
		local item = inventory.getItem(itemName)
		local sourceItem = xPlayer.getInventoryItem(itemName)

		if sourceItem and sourceItem.count >= count then
			xPlayer.removeInventoryItem(itemName, count)
			inventory.addItem(itemName, count)
			xPlayer.showNotification(TranslateCap('have_deposited', count, item.label))
		else
			xPlayer.showNotification(TranslateCap('invalid_amount'))
		end
	end)
end)

xLib.callback.registerCompat('esx_vehicleshop:buyVehicle', function(source, cb, model, plate)
	local xPlayer = ESX.Player(source)
	local vehicleData = type(model) == 'string' and getVehicleFromModel(model)
	local modelPrice = vehicleData and tonumber(vehicleData.price)
	plate = generateServerPlate()

	if not xPlayer or not modelPrice or not plate or not isNear(source, Config.Zones.ShopInside.Pos, 30.0) then
		return cb(false)
	end

	if modelPrice and xPlayer.getMoney() >= modelPrice then
		xPlayer.removeMoney(modelPrice, "Vehicle Purchase")

		MySQL.insert('INSERT INTO owned_vehicles (owner, plate, vehicle) VALUES (?, ?, ?)', {xPlayer.getIdentifier(), plate, json.encode({model = joaat(model), plate = plate})
		}, function(insertId)
			if not insertId then
				xPlayer.addMoney(modelPrice, "Vehicle Purchase Refund")
				return cb(false)
			end

			xPlayer.showNotification(TranslateCap('vehicle_belongs', plate))
			ESX.OneSync.SpawnVehicle(joaat(model), Config.Zones.ShopOutside.Pos, Config.Zones.ShopOutside.Heading,{plate = plate}, function(vehicle)
				Wait(100)
				local vehicle = NetworkGetEntityFromNetworkId(vehicle)
				Wait(300)
				TaskWarpPedIntoVehicle(GetPlayerPed(source), vehicle, -1)
			end)
			cb(true)
		end)
	else
		cb(false)
	end
end)

xLib.callback.registerCompat('esx_vehicleshop:getCommercialVehicles', function(source, cb)
	local xPlayer = ESX.Player(source)
	if not canUseCardealerShowroom(xPlayer, source) and not canUseCardealerStock(xPlayer, source) and not canUseCardealerReseller(xPlayer, source) then return cb({}) end

	MySQL.query('SELECT price, vehicle FROM cardealer_vehicles ORDER BY vehicle ASC', function(result)
		cb(result)
	end)
end)

xLib.callback.registerCompat('esx_vehicleshop:buyCarDealerVehicle', function(source, cb, model)
	local xPlayer = ESX.Player(source)

	if not canUseCardealerShowroom(xPlayer, source) then
		return cb(false)
	end
	local vehicleData = type(model) == 'string' and getVehicleFromModel(model)
	local modelPrice = vehicleData and tonumber(vehicleData.price)

	if not modelPrice then
		return cb(false)
	end
	TriggerEvent('esx_addonaccount:getSharedAccount', 'society_cardealer', function(account)
		if not account or account.money < modelPrice then
			return cb(false)
		end

		account.removeMoney(modelPrice)

		MySQL.insert('INSERT INTO cardealer_vehicles (vehicle, price) VALUES (?, ?)', {model, modelPrice},
		function(insertId)
			if not insertId then
				account.addMoney(modelPrice)
				return cb(false)
			end

			cb(true)
		end)
	end)
end)

RegisterNetEvent('esx_vehicleshop:returnProvider')
AddEventHandler('esx_vehicleshop:returnProvider', function(vehicleModel)
	local xPlayer = ESX.Player(source)

	if not canUseCardealerStock(xPlayer, source) and not canUseCardealerReseller(xPlayer, source) then
		return
	end
	MySQL.single('SELECT id, price FROM cardealer_vehicles WHERE vehicle = ?', {vehicleModel},
	function(result)
		if not result then
			return print(('[^3WARNING^7] Player ^5%s^7 Attempted To Sell Invalid Vehicle - ^5%s^7!'):format(source, vehicleModel))
		end

		local id = result.id

		MySQL.update('DELETE FROM cardealer_vehicles WHERE id = ?', {id},
		function(rowsChanged)
			if rowsChanged ~= 1 then
				return
			end
			TriggerEvent('esx_addonaccount:getSharedAccount', 'society_cardealer', function(account)
				local price = ESX.Math.Round(result.price * 0.75)
				local vehicleLabel = getVehicleFromModel(vehicleModel).name

				account.addMoney(price)
				xPlayer.showNotification(TranslateCap('vehicle_sold_for', vehicleLabel, ESX.Math.GroupDigits(price)))
			end)
		end)
	end)
end)

xLib.callback.registerCompat('esx_vehicleshop:getRentedVehicles', function(source, cb)
	local xPlayer = ESX.Player(source)
	if not canUseCardealerStock(xPlayer, source) then return cb({}) end

	MySQL.query('SELECT * FROM rented_vehicles ORDER BY player_name ASC', function(result)
		local vehicles = {}

		for i = 1, #result do
			local vehicle = result[i]
			vehicles[#vehicles + 1] = {
				name = vehicle.vehicle,
				plate = vehicle.plate,
				playerName = vehicle.player_name
			}
		end

		cb(vehicles)
	end)
end)

xLib.callback.registerCompat('esx_vehicleshop:giveBackVehicle', function(source, cb, plate)
	local xPlayer = ESX.Player(source)
	plate = normalizePlate(plate)

	if not xPlayer or not plate or not isNear(source, Config.Zones.GiveBackVehicle.Pos, 12.0) or not isNearVehicleWithPlate(source, plate, 8.0) then
		return cb(false)
	end

	MySQL.single('SELECT base_price, vehicle FROM rented_vehicles WHERE owner = ? AND plate = ?', {xPlayer.getIdentifier(), plate},
	function(result)
		if not result then
			return cb(false)
		end

		MySQL.update('DELETE FROM rented_vehicles WHERE owner = ? AND plate = ?', {xPlayer.getIdentifier(), plate},
		function(rowsChanged)
			if rowsChanged ~= 1 then return cb(false) end

			MySQL.insert('INSERT INTO cardealer_vehicles (vehicle, price) VALUES (?, ?)', {result.vehicle, result.base_price})
			RemoveOwnedVehicle(plate)
			cb(true)
		end)
	end)
end)

xLib.callback.registerCompat('esx_vehicleshop:resellVehicle', function(source, cb, plate, model)
	local xPlayer, resellPrice = ESX.Player(source)
	plate = normalizePlate(plate)

	if xPlayer and plate and isNear(source, Config.Zones.ResellVehicle.Pos, 12.0) and (xPlayer.getJob().name == 'cardealer' or not Config.EnablePlayerManagement) then
		-- calculate the resell price
		for i=1, #vehicles, 1 do
			if joaat(vehicles[i].model) == model then
				resellPrice = ESX.Math.Round(vehicles[i].price / 100 * Config.ResellPercentage)
				break
			end
		end

		if not resellPrice then
			print(('[^3WARNING^7] Player ^5%s^7 Attempted To Resell Invalid Vehicle - ^5%s^7!'):format(source, model))
			return cb(false)
		end
		MySQL.single('SELECT * FROM rented_vehicles WHERE plate = ?', {plate},
		function(result)
			if result then -- is it a rented vehicle?
				return cb(false) -- it is, don't let the player sell it since he doesn't own it
			end
			MySQL.single('SELECT * FROM owned_vehicles WHERE owner = ? AND plate = ?', {xPlayer.getIdentifier(), plate},
			function(result)
				if not result then -- does the owner match?
					return cb(false)
				end
				local vehicle = json.decode(result.vehicle or '{}')

				if not vehicle or vehicle.model ~= model then
					print(('[^3WARNING^7] Player ^5%s^7 Attempted To Resell Vehicle With Invalid Model - ^5%s^7!'):format(source, model))
					return cb(false)
				end
				if normalizePlate(vehicle.plate) ~= plate then
					print(('[^3WARNING^7] Player ^5%s^7 Attempted To Resell Vehicle With Invalid Plate - ^5%s^7!'):format(source, plate))
					return cb(false)
				end

				MySQL.update('DELETE FROM owned_vehicles WHERE owner = ? AND plate = ?', {xPlayer.getIdentifier(), plate}, function(rowsChanged)
					if rowsChanged ~= 1 then return cb(false) end

					xPlayer.addMoney(resellPrice, "Sold Vehicle")
					cb(true)
				end)
			end)
		end)
	else
		cb(false)
	end
end)

xLib.callback.registerCompat('esx_vehicleshop:getStockItems', function(source, cb)
	local xPlayer = ESX.Player(source)
	if not canUseCardealerStock(xPlayer, source) and not canUseCardealerReseller(xPlayer, source) then
		return cb({})
	end

	TriggerEvent('esx_addoninventory:getSharedInventory', 'society_cardealer', function(inventory)
		cb(inventory.items)
	end)
end)

xLib.callback.registerCompat('esx_vehicleshop:getPlayerInventory', function(source, cb)
	local xPlayer = ESX.Player(source)
	local items = xPlayer.getInventory(true)

	cb({items = items})
end)

xLib.callback.registerCompat('esx_vehicleshop:isPlateTaken', function(source, cb, plate)
	MySQL.scalar('SELECT plate FROM owned_vehicles WHERE plate = ?', {plate},
	function(result)
		cb(result ~= nil)
	end)
end)

xLib.callback.registerCompat('esx_vehicleshop:retrieveJobVehicles', function(source, cb, type)
	local xPlayer = ESX.Player(source)
	if not xPlayer then return cb({}) end

	MySQL.query('SELECT * FROM owned_vehicles WHERE owner = ? AND type = ? AND job = ?', {xPlayer.getIdentifier(), type, xPlayer.getJob().name},
	function(result)
		cb(result)
	end)
end)

RegisterNetEvent('esx_vehicleshop:setJobVehicleState')
AddEventHandler('esx_vehicleshop:setJobVehicleState', function(plate, state)
	local xPlayer = ESX.Player(source)
	plate = normalizePlate(plate)
	state = state == true or state == 1

	if not xPlayer or not plate or (state == false and not isNearVehicleWithPlate(source, plate, 12.0)) then
		return
	end

	MySQL.update('UPDATE owned_vehicles SET `stored` = ? WHERE owner = ? AND plate = ? AND job = ?', {state, xPlayer.getIdentifier(), plate, xPlayer.getJob().name},
	function(rowsChanged)
		if rowsChanged == 0 then
			print(('[^3WARNING^7] Player ^5%s^7 Attempted To Exploit the Garage!'):format(source, plate))
		end
	end)
end)

function PayRent()
	local timeStart = os.clock()
	print('[^2INFO^7] ^5Rent Payments^7 Initiated')

	MySQL.query('SELECT rented_vehicles.owner, rented_vehicles.rent_price, rented_vehicles.plate, users.accounts FROM rented_vehicles LEFT JOIN users ON rented_vehicles.owner = users.identifier', {},
	function(rentals)
		local owners = {}
		for i = 1, #rentals do
			local rental = rentals[i]
			if not owners[rental.owner] then
				owners[rental.owner] = {rental}
			else
				owners[rental.owner][#owners[rental.owner] + 1] = rental
			end
		end

		local total = 0
		local unrentals = {}
		local users = {}
		for k, v in pairs(owners) do
			local sum = 0
			for i = 1, #v do
				sum = sum + v[i].rent_price
			end
			local xPlayer = ESX.Player(k)

			if xPlayer then
				local bank = xPlayer.getAccount('bank').money

				if bank >= sum and #v > 1 then
					total = total + sum
					xPlayer.removeAccountMoney('bank', sum, "Vehicle Rental")
					xPlayer.showNotification(('You have paid $%s for all of your rentals'):format(ESX.Math.GroupDigits(sum)))
				else
					for i = 1, #v do
						local rental = v[i]
						if xPlayer.getAccount('bank').money >= rental.rent_price then
							total = total + rental.rent_price
							xPlayer.removeAccountMoney('bank', rental.rent_price, "Vehicle Rental")
							xPlayer.showNotification(TranslateCap('paid_rental', ESX.Math.GroupDigits(rental.rent_price), rental.plate))
						else
							xPlayer.showNotification(TranslateCap('paid_rental_evicted', ESX.Math.GroupDigits(rental.rent_price), rental.plate))
							unrentals[#unrentals + 1] = {rental.owner, rental.plate}
						end
					end
				end
			else
				local accounts = json.decode(v[1].accounts)
				if accounts.bank < sum then
					sum = 0
					local limit = false
					for i = 1, #v do
						local rental = v[i]
						if not limit then
							sum = sum + rental.rent_price
							if sum > accounts.bank then
								sum = sum - rental.rent_price
								limit = true
								unrentals[#unrentals + 1] = {rental.owner, rental.plate}
							end
						else
							unrentals[#unrentals + 1] = {rental.owner, rental.plate}
						end
					end
				end
				if sum > 0 then
					total = total + sum
					accounts.bank = accounts.bank - sum
					users[#users + 1] = {json.encode(accounts), k}
				end
			end
		end

		if total > 0 then
			TriggerEvent('esx_addonaccount:getSharedAccount', 'society_cardealer', function(account)
				account.addMoney(total)
			end)
		end

		if next(users) then
			MySQL.prepare.await('UPDATE users SET accounts = ? WHERE identifier = ?', users)
		end

		if next(unrentals) then
			MySQL.prepare.await('DELETE FROM rented_vehicles WHERE owner = ? AND plate = ?', unrentals)
		end

		print(('[^2INFO^7] ^5Rent Payments^7 took ^5%s^7 ms to execute'):format(ESX.Math.Round((os.time() - timeStart) / 1000000, 2)))
	end)
end

TriggerEvent('cron:runAt', 22, 00, PayRent)
