-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

if Config.EnableESXService then
	if Config.MaxInService ~= -1 then
		TriggerEvent('esx_service:activateService', 'police', Config.MaxInService)
	end
end

TriggerEvent('esx_phone:registerNumber', 'police', TranslateCap('alert_police'), true, true)
TriggerEvent('esx_society:registerSociety', 'police', TranslateCap('society_police'), 'society_police', 'society_police', 'society_police', {type = 'public'})

local cuffedPlayers = {}
local getValidCount = xLib.validation.count

local function isPoliceOnDuty(xPlayer)
	local job = xPlayer and xPlayer.getJob()
	return job and job.name == 'police' and job.onDuty ~= false
end

local function notifyOffDuty(xPlayer)
	local job = xPlayer and xPlayer.getJob()
	if not job or job.name ~= 'police' or job.onDuty ~= false then
		return false
	end

	xPlayer.showNotification(TranslateCap('off_duty'))
	return true
end

local function generateJobVehiclePlate()
	return xLib.vehiclePlate.generateUnique({
		prefix = 'POL',
		letters = 2,
		numbers = 3
	}, function(plate)
		return MySQL.scalar.await('SELECT plate FROM owned_vehicles WHERE plate = ?', {plate}) ~= nil
	end)
end

local function isNearPlayer(source, target, distance)
	local nearby = xLib.player.isNearPlayer(source, target, distance)
	return nearby
end

local function isNearPoliceArmory(source)
	local ped = GetPlayerPed(source)
	if not ped or ped == 0 then
		return false
	end

	local coords = GetEntityCoords(ped)
	for _, station in pairs(Config.PoliceStations) do
		for i = 1, #(station.Armories or {}) do
			if #(coords - station.Armories[i]) <= 8.0 then
				return true
			end
		end
	end

	return false
end

local function normalizeImpoundPlate(plate)
	if type(plate) ~= 'string' then
		return nil
	end

	plate = plate:gsub("^%s+", ""):gsub("%s+$", "")
	if plate == "" then
		return nil
	end

	return plate
end

local function impoundPlateKey(plate)
	return plate:gsub("^%s+", ""):gsub("%s+$", ""):upper()
end

local function isNearImpoundVehicle(source, plate)
	local ped = GetPlayerPed(source)
	if not ped or ped == 0 then
		return false
	end

	local plateKey = impoundPlateKey(plate)
	local vehicle = GetVehiclePedIsIn(ped, false)

	if vehicle ~= 0 and impoundPlateKey(GetVehicleNumberPlateText(vehicle) or '') == plateKey then
		return true
	end

	local coords = GetEntityCoords(ped)
	local vehicles = GetAllVehicles()

	for i = 1, #vehicles do
		vehicle = vehicles[i]

		if impoundPlateKey(GetVehicleNumberPlateText(vehicle) or '') == plateKey
			and #(GetEntityCoords(vehicle) - coords) <= 8.0 then
			return true
		end
	end

	return false
end

local function isNearPoliceVehicleShop(source, type)
	local ped = GetPlayerPed(source)
	if not ped or ped == 0 then return false end

	local coords = GetEntityCoords(ped)
	local shopKey = type == 'helicopter' and 'Helicopters' or 'Vehicles'

	for _, station in pairs(Config.PoliceStations) do
		for i = 1, #(station[shopKey] or {}) do
			local shopCoords = station[shopKey][i].InsideShop or station[shopKey][i].Spawner
			if shopCoords and #(coords - vector3(shopCoords.x, shopCoords.y, shopCoords.z)) <= 35.0 then
				return true
			end
		end
	end

	return false
end

local function getAuthorizedVehicle(vehicleHash, jobGrade, type)
	local vehicles = Config.AuthorizedVehicles[type]?[jobGrade] or {}

	for i = 1, #vehicles do
		local vehicle = vehicles[i]
		if GetHashKey(vehicle.model) == vehicleHash then
			return vehicle
		end
	end

	return nil
end

RegisterNetEvent('esx_policejob:impoundOwnedVehicle')
AddEventHandler('esx_policejob:impoundOwnedVehicle', function(plate)
	local source = source
	local xPlayer = ESX.Player(source)

	if not xPlayer or xPlayer.getJob().name ~= 'police' then
		print(('[^3WARNING^7] Player ^5%s^7 Attempted To Exploit Vehicle Impound!'):format(source))
		return
	end

	plate = normalizeImpoundPlate(plate)
	if not plate then
		return
	end

	if not isNearImpoundVehicle(source, plate) then
		return
	end

	pcall(function()
		exports['esx_garage']:impoundVehicle(plate)
	end)
end)

RegisterNetEvent('esx_policejob:confiscatePlayerItem')
AddEventHandler('esx_policejob:confiscatePlayerItem', function(target, itemType, itemName, amount)
	local source = source
	local sourceXPlayer = ESX.Player(source)
	local targetXPlayer = ESX.Player(target)
	if not isPoliceOnDuty(sourceXPlayer) or not targetXPlayer or not isNearPlayer(source, target, 5.0) or not cuffedPlayers[tonumber(target)] then
		if not notifyOffDuty(sourceXPlayer) then
			print(('[^3WARNING^7] Player ^5%s^7 Attempted To Exploit The Confuscation System!'):format(source))
		end
		return
	end

	local sourceXPlayerName = sourceXPlayer.getName()
	local targetXPlayerName = targetXPlayer.getName()
	amount = itemType == 'item_weapon' and ESX.Math.Round(tonumber(amount) or 0) or getValidCount(amount)
	if amount == nil or amount < 0 then
		return sourceXPlayer.showNotification(TranslateCap('quantity_invalid'))
	end

	if itemType == 'item_standard' then
		local targetItem = targetXPlayer.getInventoryItem(itemName)
		local sourceItem = sourceXPlayer.getInventoryItem(itemName)

		-- does the target player have enough in their inventory?
		if targetItem and targetItem.count >= amount then

			-- can the player carry the said amount of x item?
			if sourceXPlayer.canCarryItem(itemName, amount) then
				targetXPlayer.removeInventoryItem(itemName, amount)
				sourceXPlayer.addInventoryItem   (itemName, amount)
				sourceXPlayer.showNotification(TranslateCap('you_confiscated', amount, sourceItem.label, targetXPlayerName))
				targetXPlayer.showNotification(TranslateCap('got_confiscated', amount, sourceItem.label, sourceXPlayerName))
			else
				sourceXPlayer.showNotification(TranslateCap('quantity_invalid'))
			end
		else
			sourceXPlayer.showNotification(TranslateCap('quantity_invalid'))
		end

	elseif itemType == 'item_account' then
		local targetAccount = targetXPlayer.getAccount(itemName)

		-- does the target player have enough money?
		if targetAccount.money >= amount then
			targetXPlayer.removeAccountMoney(itemName, amount, "Confiscated")
			sourceXPlayer.addAccountMoney   (itemName, amount, "Confiscated")

			sourceXPlayer.showNotification(TranslateCap('you_confiscated_account', amount, itemName, targetXPlayerName))
			targetXPlayer.showNotification(TranslateCap('got_confiscated_account', amount, itemName, sourceXPlayerName))
		else
			sourceXPlayer.showNotification(TranslateCap('quantity_invalid'))
		end

	elseif itemType == 'item_weapon' then
		if amount == nil then amount = 0 end

		-- does the target player have weapon?
		if targetXPlayer.hasWeapon(itemName) then
			targetXPlayer.removeWeapon(itemName)
			sourceXPlayer.addWeapon   (itemName, amount)

			sourceXPlayer.showNotification(TranslateCap('you_confiscated_weapon', ESX.GetWeaponLabel(itemName), targetXPlayerName, amount))
			targetXPlayer.showNotification(TranslateCap('got_confiscated_weapon', ESX.GetWeaponLabel(itemName), amount, sourceXPlayerName))
		else
			sourceXPlayer.showNotification(TranslateCap('quantity_invalid'))
		end
	end
end)

RegisterNetEvent('esx_policejob:handcuff')
AddEventHandler('esx_policejob:handcuff', function(target)
	local xPlayer = ESX.Player(source)

	if isPoliceOnDuty(xPlayer) and isNearPlayer(source, target, 5.0) then
		target = tonumber(target)
		cuffedPlayers[target] = not cuffedPlayers[target]
		Player(target).state:set('isHandcuffed', cuffedPlayers[target], true)
		if cuffedPlayers[target] and Config.EnableHandcuffTimer then
			SetTimeout(Config.HandcuffTimer, function()
				if cuffedPlayers[target] then
					cuffedPlayers[target] = nil
					Player(target).state:set('isHandcuffed', false, true)
				end
			end)
		end
		TriggerClientEvent('esx_policejob:handcuff', target)
	elseif not notifyOffDuty(xPlayer) then
		print(('[^3WARNING^7] Player ^5%s^7 Attempted To Exploit Handcuffs!'):format(source))
	end
end)

RegisterNetEvent('esx_policejob:drag')
AddEventHandler('esx_policejob:drag', function(target)
	local xPlayer = ESX.Player(source)

	if isPoliceOnDuty(xPlayer) and cuffedPlayers[tonumber(target)] and isNearPlayer(source, target, 5.0) then
		TriggerClientEvent('esx_policejob:drag', target, source)
	elseif not notifyOffDuty(xPlayer) then
		print(('[^3WARNING^7] Player ^5%s^7 Attempted To Exploit Dragging!'):format(source))
	end
end)

RegisterNetEvent('esx_policejob:putInVehicle')
AddEventHandler('esx_policejob:putInVehicle', function(target)
	local xPlayer = ESX.Player(source)

	if isPoliceOnDuty(xPlayer) and cuffedPlayers[tonumber(target)] and isNearPlayer(source, target, 5.0) then
		TriggerClientEvent('esx_policejob:putInVehicle', target)
	elseif not notifyOffDuty(xPlayer) then
		print(('[^3WARNING^7] Player ^5%s^7 Attempted To Exploit Garage!'):format(source))
	end
end)

RegisterNetEvent('esx_policejob:OutVehicle')
AddEventHandler('esx_policejob:OutVehicle', function(target)
	local xPlayer = ESX.Player(source)

	if isPoliceOnDuty(xPlayer) and cuffedPlayers[tonumber(target)] and isNearPlayer(source, target, 8.0) then
		TriggerClientEvent('esx_policejob:OutVehicle', target)
	elseif not notifyOffDuty(xPlayer) then
		print(('[^3WARNING^7] Player ^5%s^7 Attempted To Exploit Dragging Out Of Vehicle!'):format(source))
	end
end)

AddEventHandler('playerDropped', function()
	cuffedPlayers[source] = nil
end)

RegisterNetEvent('esx_policejob:getStockItem')
AddEventHandler('esx_policejob:getStockItem', function(itemName, count)
	local source = source
	local xPlayer = ESX.Player(source)
	count = getValidCount(count)

	if not count or not isPoliceOnDuty(xPlayer) or not isNearPoliceArmory(source) then
		if not notifyOffDuty(xPlayer) then
			print(('[^3WARNING^7] Player ^5%s^7 attempted invalid police stock withdrawal!'):format(source))
		end
		return
	end

	TriggerEvent('esx_addoninventory:getSharedInventory', 'society_police', function(inventory)
		local inventoryItem = inventory.getItem(itemName)

		-- is there enough in the society?
		if count > 0 and inventoryItem.count >= count then

			-- can the player carry the said amount of x item?
			if xPlayer.canCarryItem(itemName, count) then
				inventory.removeItem(itemName, count)
				xPlayer.addInventoryItem(itemName, count)
				xPlayer.showNotification(TranslateCap('have_withdrawn', count, inventoryItem.name))
			else
				xPlayer.showNotification(TranslateCap('quantity_invalid'))
			end
		else
			xPlayer.showNotification(TranslateCap('quantity_invalid'))
		end
	end)
end)

RegisterNetEvent('esx_policejob:putStockItems')
AddEventHandler('esx_policejob:putStockItems', function(itemName, count)
	local source = source
	local xPlayer = ESX.Player(source)
	local sourceItem = xPlayer.getInventoryItem(itemName)
	count = getValidCount(count)

	if not count or not isPoliceOnDuty(xPlayer) or not isNearPoliceArmory(source) then
		if not notifyOffDuty(xPlayer) then
			print(('[^3WARNING^7] Player ^5%s^7 attempted invalid police stock deposit!'):format(source))
		end
		return
	end

	TriggerEvent('esx_addoninventory:getSharedInventory', 'society_police', function(inventory)
		local inventoryItem = inventory.getItem(itemName)

		-- does the player have enough of the item?
		if sourceItem.count >= count and count > 0 then
			xPlayer.removeInventoryItem(itemName, count)
			inventory.addItem(itemName, count)
			xPlayer.showNotification(TranslateCap('have_deposited', count, inventoryItem.name))
		else
			xPlayer.showNotification(TranslateCap('quantity_invalid'))
		end
	end)
end)

xLib.callback.registerCompat('esx_policejob:getOtherPlayerData', function(source, cb, target, notify)
	local sourceXPlayer = ESX.Player(source)
	local xPlayer = ESX.Player(target)
	if not isPoliceOnDuty(sourceXPlayer) or not xPlayer or not isNearPlayer(source, target, 5.0) or not cuffedPlayers[tonumber(target)] then
		return cb({})
	end

	local job = xPlayer.getJob()
	if notify then
		xPlayer.showNotification(TranslateCap('being_searched'))
	end

	local data = {
		name = xPlayer.getName(),
		job = job.label,
		grade = job.grade_label,
		inventory = xPlayer.getInventory(),
		accounts = xPlayer.getAccounts(),
		weapons = xPlayer.getLoadout()
	}

	if Config.EnableESXIdentity then
		data.dob = xPlayer.get('dateofbirth')
		data.height = xPlayer.get('height')

		if xPlayer.get('sex') == 'm' then data.sex = 'male' else data.sex = 'female' end
	end

	TriggerEvent('esx_status:getStatus', target, 'drunk', function(status)
		if status then
			data.drunk = ESX.Math.Round(status.percent)
		end
	end)

	if Config.EnableLicenses then
		TriggerEvent('esx_license:getLicenses', target, function(licenses)
			data.licenses = licenses
			cb(data)
		end)
	else
		cb(data)
	end
end)

local fineList = {}
xLib.callback.registerCompat('esx_policejob:getFineList', function(source, cb, category)
	if not fineList[category] then
		MySQL.query('SELECT * FROM fine_types WHERE category = ?', {category},
		function(fines)
			fineList[category] = fines

			cb(fines)
		end)
	else
		cb(fineList[category])
	end
end)


xLib.callback.registerCompat('esx_policejob:getVehicleInfos', function(source, cb, plate)
	local xPlayer = ESX.Player(source)
	plate = normalizeImpoundPlate(plate)

	if not isPoliceOnDuty(xPlayer) or not plate or (not isNearImpoundVehicle(source, plate) and not isNearPoliceArmory(source)) then
		return cb({plate = plate})
	end

	local retrivedInfo = {
		plate = plate
	}
	if Config.EnableESXIdentity then
		MySQL.single('SELECT users.firstname, users.lastname FROM owned_vehicles JOIN users ON owned_vehicles.owner = users.identifier WHERE plate = ?', {plate},
		function(result)
			if result then
				retrivedInfo.owner = ('%s %s'):format(result.firstname, result.lastname)
			end
			cb(retrivedInfo)
		end)
	else
		MySQL.scalar('SELECT owner FROM owned_vehicles WHERE plate = ?', {plate},
		function(owner)
			if owner then
				local xPlayer = ESX.Player(owner)
				if xPlayer then
					retrivedInfo.owner = xPlayer.getName()
				end
			end
			cb(retrivedInfo)
		end)
	end
end)

xLib.callback.registerCompat('esx_policejob:getArmoryWeapons', function(source, cb)
	local xPlayer = ESX.Player(source)
	if not isPoliceOnDuty(xPlayer) or not isNearPoliceArmory(source) then
		return cb({})
	end

	TriggerEvent('esx_datastore:getSharedDataStore', 'society_police', function(store)
		local weapons = store.get('weapons')

		if weapons == nil then
			weapons = {}
		end

		cb(weapons)
	end)
end)

xLib.callback.registerCompat('esx_policejob:addArmoryWeapon', function(source, cb, weaponName, removeWeapon)
	local xPlayer = ESX.Player(source)
	if not isPoliceOnDuty(xPlayer) or not isNearPoliceArmory(source) or not xPlayer.hasWeapon(weaponName) then
		return cb(false)
	end

	if removeWeapon then
		xPlayer.removeWeapon(weaponName)
	end

	TriggerEvent('esx_datastore:getSharedDataStore', 'society_police', function(store)
		local weapons = store.get('weapons') or {}
		local foundWeapon = false

		for i=1, #weapons, 1 do
			if weapons[i].name == weaponName then
				weapons[i].count = weapons[i].count + 1
				foundWeapon = true
				break
			end
		end

		if not foundWeapon then
			table.insert(weapons, {
				name  = weaponName,
				count = 1
			})
		end

		store.set('weapons', weapons)
		cb(true)
		end)
end)

xLib.callback.registerCompat('esx_policejob:removeArmoryWeapon', function(source, cb, weaponName)
	local xPlayer = ESX.Player(source)
	if not isPoliceOnDuty(xPlayer) or not isNearPoliceArmory(source) then
		return cb(false)
	end

	TriggerEvent('esx_datastore:getSharedDataStore', 'society_police', function(store)
		local weapons = store.get('weapons') or {}

		local foundWeapon = false

		for i=1, #weapons, 1 do
			if weapons[i].name == weaponName and weapons[i].count > 0 then
				weapons[i].count = weapons[i].count - 1
				foundWeapon = true
				break
			end
		end

		if not foundWeapon then
			return cb(false)
		end

		xPlayer.addWeapon(weaponName, 500)
		store.set('weapons', weapons)
		cb(true)
	end)
end)

xLib.callback.registerCompat('esx_policejob:buyWeapon', function(source, cb, weaponName, type, componentNum)
	local xPlayer = ESX.Player(source)
	if not isPoliceOnDuty(xPlayer) or not isNearPoliceArmory(source) then
		return cb(false)
	end

	local authorizedWeapons, selectedWeapon = Config.AuthorizedWeapons[xPlayer.getJob().grade_name]
	if not authorizedWeapons then
		return cb(false)
	end

	for k,v in ipairs(authorizedWeapons) do
		if v.weapon == weaponName then
			selectedWeapon = v
			break
		end
	end

	if not selectedWeapon then
		print(('[^3WARNING^7] Player ^5%s^7 Attempted To Buy Invalid Weapon - ^5%s^7!'):format(source, weaponName))
		cb(false)
	else
		-- Weapon
		if type == 1 then
			if xPlayer.getMoney() >= selectedWeapon.price then
				xPlayer.removeMoney(selectedWeapon.price, "Weapon Bought")
				xPlayer.addWeapon(weaponName, 100)

				cb(true)
			else
				cb(false)
			end

		-- Weapon Component
		elseif type == 2 then
			local price = selectedWeapon.components[componentNum]
			local weaponNum, weapon = ESX.GetWeapon(weaponName)
			local component = weapon.components[componentNum]

			if component then
				if xPlayer.getMoney() >= price then
					xPlayer.removeMoney(price, "Weapon Component Bought")
					xPlayer.addWeaponComponent(weaponName, component.name)

					cb(true)
				else
					cb(false)
				end
			else
				print(('[^3WARNING^7] Player ^5%s^7 Attempted To Buy Invalid Weapon Component - ^5%s^7!'):format(source, componentNum))
				cb(false)
			end
		end
	end
end)

xLib.callback.registerCompat('esx_policejob:buyJobVehicle', function(source, cb, vehicleProps, type)
	local xPlayer = ESX.Player(source)
	local job = xPlayer and xPlayer.getJob()
	local model = _G.type(vehicleProps) == 'table' and tonumber(vehicleProps.model)
	local authorizedVehicle = job and model and getAuthorizedVehicle(model, job.grade_name, type)
	local price = authorizedVehicle and tonumber(authorizedVehicle.price) or 0

	-- vehicle model not found
	if not isPoliceOnDuty(xPlayer) or price == 0 or not isNearPoliceVehicleShop(source, type) then
		if not notifyOffDuty(xPlayer) then
			print(('[^3WARNING^7] Player ^5%s^7 Attempted To Buy Invalid Vehicle - ^5%s^7!'):format(source, tostring(model)))
		end
		return cb(false)
	end

	if xPlayer.getMoney() < price then return cb(false) end

	local plate = generateJobVehiclePlate()
	if not plate then return cb(false) end

	local storedProps = {model = model, plate = plate}
	if _G.type(authorizedVehicle.props) == 'table' then
		for key, value in pairs(authorizedVehicle.props) do
			storedProps[key] = value
		end
	end

	xPlayer.removeMoney(price, "Job Vehicle Bought")

	MySQL.insert('INSERT INTO owned_vehicles (owner, vehicle, plate, type, job, `stored`) VALUES (?, ?, ?, ?, ?, ?)', { xPlayer.getIdentifier(), json.encode(storedProps), plate, type, job.name, true},
	function (insertId)
		if not insertId then
			xPlayer.addMoney(price, "Job Vehicle Refund")
			return cb(false)
		end

		cb(true)
	end)
end)

xLib.callback.registerCompat('esx_policejob:storeNearbyVehicle', function(source, cb, plates)
	local xPlayer = ESX.Player(source)
	if not isPoliceOnDuty(xPlayer) or type(plates) ~= 'table' or #plates == 0 then return cb(false) end

	local job = xPlayer.getJob()
	local identifier = xPlayer.getIdentifier()
	local plate = MySQL.scalar.await('SELECT plate FROM owned_vehicles WHERE owner = ? AND plate IN (?) AND job = ?', {identifier, plates, job.name})

	if plate then
		MySQL.update('UPDATE owned_vehicles SET `stored` = true WHERE owner = ? AND plate = ? AND job = ?', {identifier, plate, job.name},
		function(rowsChanged)
			if rowsChanged == 0 then
				cb(false)
			else
				cb(plate)
			end
		end)
	else
		cb(false)
	end
end)

function getPriceFromHash(vehicleHash, jobGrade, type)
   local vehicles = Config.AuthorizedVehicles[type]?[jobGrade] or {}

	for i = 1, #vehicles do
		local vehicle = vehicles[i]
		if GetHashKey(vehicle.model) == vehicleHash then
			return vehicle.price
		end
	end

	return 0
end

xLib.callback.registerCompat('esx_policejob:getStockItems', function(source, cb)
	local xPlayer = ESX.Player(source)
	if not isPoliceOnDuty(xPlayer) or not isNearPoliceArmory(source) then
		return cb({})
	end

	TriggerEvent('esx_addoninventory:getSharedInventory', 'society_police', function(inventory)
		cb(inventory.items)
	end)
end)

xLib.callback.registerCompat('esx_policejob:getPlayerInventory', function(source, cb)
	local xPlayer = ESX.Player(source)
	if not isPoliceOnDuty(xPlayer) or not isNearPoliceArmory(source) then
		return cb({items = {}})
	end

	local items   = xPlayer.getInventory(false)

	cb({items = items})
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		TriggerEvent('esx_phone:removeNumber', 'police')
	end
end)
