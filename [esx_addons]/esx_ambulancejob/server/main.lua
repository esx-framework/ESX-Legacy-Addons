local playersHealing, deadPlayers = {}, {}
local reviveCooldowns = {}
local itemCooldowns, actionCooldowns = {}, {}

if GetResourceState("esx_phone") ~= 'missing' then
	TriggerEvent('esx_phone:registerNumber', 'ambulance', TranslateCap('alert_ambulance'), true, true)
end

if GetResourceState("esx_society") ~= 'missing' then
	TriggerEvent('esx_society:registerSociety', 'ambulance', 'Ambulance', 'society_ambulance', 'society_ambulance',
		'society_ambulance', { type = 'public' })
end

local function isDeadState(src, bool)
	if not src or bool == nil then return end

	Player(src).state:set('isDead', bool, true)
end

local function persistDeathStatus(src, bool)
	local xPlayer = src and ESX.GetPlayerFromId(src)
	if not xPlayer or type(bool) ~= 'boolean' then return end

	MySQL.update('UPDATE users SET is_dead = ? WHERE identifier = ?', { bool, xPlayer.identifier })
	isDeadState(src, bool)

	if bool then
		xPlayer.setMeta('deathTime', os.time())
	elseif xPlayer.getMeta().deathTime ~= nil then
		xPlayer.clearMeta('deathTime')
	end
end

local function isNearPlayer(source, target, distance)
	local nearby = xLib.player.isNearPlayer(source, target, distance)
	return nearby
end

local function isAmbulanceOnDuty(xPlayer)
	return xPlayer and xPlayer.job and xPlayer.job.name == 'ambulance' and xPlayer.job.onDuty ~= false
end

local function isNearHospitalMarker(source, markerName, distance)
	local ped = GetPlayerPed(source)
	if not ped or ped == 0 then return false end

	local coords = GetEntityCoords(ped)
	for _, hospital in pairs(Config.Hospitals) do
		for i = 1, #(hospital[markerName] or {}) do
			local marker = hospital[markerName][i]
			if #(coords - vector3(marker.x, marker.y, marker.z)) <= (distance or 8.0) then
				return true
			end
		end
	end

	return false
end

local function isNearAmbulanceVehicleShop(source, vehicleType)
	local ped = GetPlayerPed(source)
	if not ped or ped == 0 then return false end

	local coords = GetEntityCoords(ped)
	local shopKey = vehicleType == 'helicopter' and 'Helicopters' or 'Vehicles'

	for _, hospital in pairs(Config.Hospitals) do
		for i = 1, #(hospital[shopKey] or {}) do
			local shopCoords = hospital[shopKey][i].InsideShop or hospital[shopKey][i].Spawner
			if shopCoords and #(coords - vector3(shopCoords.x, shopCoords.y, shopCoords.z)) <= 35.0 then
				return true
			end
		end
	end

	return false
end

local function generateJobVehiclePlate()
	return xLib.vehiclePlate.generateUnique({
		prefix = 'AMB',
		letters = 2,
		numbers = 3
	}, function(plate)
		return MySQL.scalar.await('SELECT plate FROM owned_vehicles WHERE plate = ?', {plate}) ~= nil
	end)
end

local function getAuthorizedVehicle(vehicleHash, jobGrade, vehicleType)
	local vehicles = Config.AuthorizedVehicles[vehicleType] and Config.AuthorizedVehicles[vehicleType][jobGrade] or {}

	for i = 1, #vehicles do
		if joaat(vehicles[i].model) == vehicleHash then
			return vehicles[i]
		end
	end

	return nil
end

local function getValidItemAmount(amount)
	amount = tonumber(amount)
	if not amount then return nil end

	amount = math.floor(amount)
	if amount < 1 or amount > (Config.MaxPharmacyTake or 5) then return nil end

	return amount
end

RegisterNetEvent('esx_ambulancejob:revive')
AddEventHandler('esx_ambulancejob:revive', function(playerId)
	playerId = tonumber(playerId)
	local xPlayer = source and ESX.GetPlayerFromId(source)
	local now = os.clock()

	if xPlayer and xPlayer.job.name == 'ambulance' and playerId and (not reviveCooldowns[source] or now - reviveCooldowns[source] > 8) then
		local xTarget = ESX.GetPlayerFromId(playerId)
		if xTarget then
			if deadPlayers[playerId] and isNearPlayer(source, playerId, 8.0) then
				reviveCooldowns[source] = now
				if Config.ReviveReward > 0 then
					xPlayer.showNotification(TranslateCap('revive_complete_award', xTarget.name, Config.ReviveReward))
					xPlayer.addMoney(Config.ReviveReward, "Revive Reward")
					xTarget.triggerEvent('esx_ambulancejob:revive')
					persistDeathStatus(xTarget.source, false)
				else
					xPlayer.showNotification(TranslateCap('revive_complete', xTarget.name))
					xTarget.triggerEvent('esx_ambulancejob:revive')
					persistDeathStatus(xTarget.source, false)
				end
				local Ambulance = ESX.GetExtendedPlayers("job", "ambulance")

				for _, xPlayer in pairs(Ambulance) do
					if xPlayer.job.name == 'ambulance' then
						xPlayer.triggerEvent('esx_ambulancejob:PlayerNotDead', playerId)
					end
				end
				deadPlayers[playerId] = nil
			else
				xPlayer.showNotification(TranslateCap('player_not_unconscious'))
			end
		else
			xPlayer.showNotification(TranslateCap('revive_fail_offline'))
		end
	end
end)

AddEventHandler('txAdmin:events:healedPlayer', function(eventData)
	if GetInvokingResource() ~= "monitor" or type(eventData) ~= "table" or type(eventData.id) ~= "number" then
		return
	end
	if deadPlayers[eventData.id] then
		persistDeathStatus(eventData.id, false)
		TriggerClientEvent('esx_ambulancejob:revive', eventData.id)
		local Ambulance = ESX.GetExtendedPlayers("job", "ambulance")

		for _, xPlayer in pairs(Ambulance) do
			if xPlayer.job.name == 'ambulance' then
				xPlayer.triggerEvent('esx_ambulancejob:PlayerNotDead', eventData.id)
			end
		end
		deadPlayers[eventData.id] = nil
	end
end)

RegisterNetEvent('esx:onPlayerDeath')
AddEventHandler('esx:onPlayerDeath', function(data)
	local source = source
	if deadPlayers[source] then return end

	deadPlayers[source] = 'dead'
	local Ambulance = ESX.GetExtendedPlayers("job", "ambulance")
	persistDeathStatus(source, true)

	for _, xPlayer in pairs(Ambulance) do
		xPlayer.triggerEvent('esx_ambulancejob:PlayerDead', source)
	end
end)

RegisterServerEvent('esx_ambulancejob:svsearch')
AddEventHandler('esx_ambulancejob:svsearch', function()
	TriggerClientEvent('esx_ambulancejob:clsearch', -1, source)
end)

RegisterNetEvent('esx_ambulancejob:onPlayerDistress')
AddEventHandler('esx_ambulancejob:onPlayerDistress', function()
	local source = source
	local injuredPed = GetPlayerPed(source)
	local injuredCoords = GetEntityCoords(injuredPed)

	if deadPlayers[source] then
		deadPlayers[source] = 'distress'
		local Ambulance = ESX.GetExtendedPlayers("job", "ambulance")

		for _, xPlayer in pairs(Ambulance) do
			xPlayer.triggerEvent('esx_ambulancejob:PlayerDistressed', source, injuredCoords)
		end
	end
end)

RegisterNetEvent('esx:onPlayerSpawn')
AddEventHandler('esx:onPlayerSpawn', function()
	local source = source
	if deadPlayers[source] then
		deadPlayers[source] = nil
		isDeadState(source, false)
		local Ambulance = ESX.GetExtendedPlayers("job", "ambulance")

		for _, xPlayer in pairs(Ambulance) do
			xPlayer.triggerEvent('esx_ambulancejob:PlayerNotDead', source)
		end
	end
end)

AddEventHandler('esx:playerDropped', function(playerId, reason)
	reviveCooldowns[playerId] = nil
	itemCooldowns[playerId] = nil
	actionCooldowns[playerId] = nil
	if deadPlayers[playerId] then
		deadPlayers[playerId] = nil
		isDeadState(playerId, false)
		local Ambulance = ESX.GetExtendedPlayers("job", "ambulance")

		for _, xPlayer in pairs(Ambulance) do
			if xPlayer.job.name == 'ambulance' then
				xPlayer.triggerEvent('esx_ambulancejob:PlayerNotDead', playerId)
			end
		end
	end
end)

RegisterNetEvent('esx_ambulancejob:heal')
AddEventHandler('esx_ambulancejob:heal', function(target, type)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(source)
	local xTarget = ESX.GetPlayerFromId(tonumber(target))
	local now = GetGameTimer()
	type = tostring(type or '')

	if not isAmbulanceOnDuty(xPlayer) or not xTarget or (type ~= 'small' and type ~= 'big') or not isNearPlayer(src, xTarget.source, 8.0) then return end
	if actionCooldowns[src] and now - actionCooldowns[src] < 3000 then return end

	actionCooldowns[src] = now
	TriggerClientEvent('esx_ambulancejob:heal', xTarget.source, type)
end)

RegisterNetEvent('esx_ambulancejob:putInVehicle')
AddEventHandler('esx_ambulancejob:putInVehicle', function(target)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(source)
	local xTarget = ESX.GetPlayerFromId(tonumber(target))
	local now = GetGameTimer()

	if not isAmbulanceOnDuty(xPlayer) or not xTarget or not isNearPlayer(src, xTarget.source, 8.0) then return end
	if actionCooldowns[src] and now - actionCooldowns[src] < 3000 then return end

	actionCooldowns[src] = now
	TriggerClientEvent('esx_ambulancejob:putInVehicle', xTarget.source)
end)

xLib.callback.registerCompat('esx_ambulancejob:removeItemsAfterRPDeath', function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)
	if not xPlayer then return cb() end

	if deadPlayers[source] then
		persistDeathStatus(source, false)
	end

	if Config.OxInventory and Config.RemoveItemsAfterRPDeath then
		exports.ox_inventory:ClearInventory(xPlayer.source)
		return cb()
	end

	if Config.RemoveCashAfterRPDeath then
		if xPlayer.getMoney() > 0 then
			xPlayer.removeMoney(xPlayer.getMoney(), "Death")
		end

		if xPlayer.getAccount('black_money').money > 0 then
			xPlayer.setAccountMoney('black_money', 0, "Death")
		end
	end

	if Config.RemoveItemsAfterRPDeath then
		for itemName, item in pairs(xPlayer.inventory) do
			if item.count > 0 then
				xPlayer.setInventoryItem(itemName, 0)
			end
		end
	end

	if Config.OxInventory then return cb() end

	local playerLoadout = {}
	if Config.RemoveWeaponsAfterRPDeath then
		for i = 1, #xPlayer.loadout, 1 do
			xPlayer.removeWeapon(xPlayer.loadout[i].name)
		end
	else -- save weapons & restore em' since spawnmanager removes them
		for i = 1, #xPlayer.loadout, 1 do
			table.insert(playerLoadout, xPlayer.loadout[i])
		end

		-- give back wepaons after a couple of seconds
		CreateThread(function()
			Wait(5000)
			for i = 1, #playerLoadout, 1 do
				if playerLoadout[i].label ~= nil then
					xPlayer.addWeapon(playerLoadout[i].name, playerLoadout[i].ammo)
				end
			end
		end)
	end

	cb()
end)

if Config.EarlyRespawnFine then
	xLib.callback.registerCompat('esx_ambulancejob:checkBalance', function(source, cb)
		local xPlayer = ESX.GetPlayerFromId(source)
		local bankBalance = xPlayer.getAccount('bank').money

		cb(bankBalance >= Config.EarlyRespawnFineAmount)
	end)

	RegisterNetEvent('esx_ambulancejob:payFine')
	AddEventHandler('esx_ambulancejob:payFine', function()
		local xPlayer = ESX.GetPlayerFromId(source)
		local fineAmount = Config.EarlyRespawnFineAmount

		xPlayer.showNotification(TranslateCap('respawn_bleedout_fine_msg', ESX.Math.GroupDigits(fineAmount)))
		xPlayer.removeAccountMoney('bank', fineAmount, "Respawn Fine")
	end)
end

xLib.callback.registerCompat('esx_ambulancejob:getItemAmount', function(source, cb, item)
	local xPlayer = ESX.GetPlayerFromId(source)
	local quantity = xPlayer.getInventoryItem(item).count

	cb(quantity)
end)

xLib.callback.registerCompat('esx_ambulancejob:buyJobVehicle', function(source, cb, vehicleProps, type)
	local xPlayer = ESX.GetPlayerFromId(source)
	local model = _G.type(vehicleProps) == 'table' and tonumber(vehicleProps.model)
	local authorizedVehicle = xPlayer and model and getAuthorizedVehicle(model, xPlayer.job.grade_name, type)
	local price = authorizedVehicle and tonumber(authorizedVehicle.price) or 0

	-- vehicle model not found
	if not isAmbulanceOnDuty(xPlayer) or price == 0 or not isNearAmbulanceVehicleShop(source, type) then
		cb(false)
		return
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

	xPlayer.removeMoney(price, "Job Vehicle Purchase")

	MySQL.insert('INSERT INTO owned_vehicles (owner, vehicle, plate, type, job, `stored`) VALUES (?, ?, ?, ?, ?, ?)',
		{ xPlayer.identifier, json.encode(storedProps), plate, type, xPlayer.job.name, true },
		function(insertId)
			if not insertId then
				xPlayer.addMoney(price, "Job Vehicle Refund")
				return cb(false)
			end

			cb(true)
		end)
end)

xLib.callback.registerCompat('esx_ambulancejob:storeNearbyVehicle', function(source, cb, plates)
	local xPlayer = ESX.GetPlayerFromId(source)
	if not isAmbulanceOnDuty(xPlayer) or type(plates) ~= 'table' or #plates == 0 then return cb(false) end

	local plate = MySQL.scalar.await('SELECT plate FROM owned_vehicles WHERE owner = ? AND plate IN (?) AND job = ?',
		{ xPlayer.identifier, plates, xPlayer.job.name })

	if plate then
		MySQL.update('UPDATE owned_vehicles SET `stored` = true WHERE owner = ? AND plate = ? AND job = ?',
			{ xPlayer.identifier, plate, xPlayer.job.name },
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
	local vehicles = Config.AuthorizedVehicles[type][jobGrade]

	for i = 1, #vehicles do
		local vehicle = vehicles[i]
		if joaat(vehicle.model) == vehicleHash then
			return vehicle.price
		end
	end

	return 0
end

RegisterNetEvent('esx_ambulancejob:removeItem')
AddEventHandler('esx_ambulancejob:removeItem', function(item)
	local xPlayer = ESX.GetPlayerFromId(source)
	xPlayer.removeInventoryItem(item, 1)

	if item == 'bandage' then
		xPlayer.showNotification(TranslateCap('used_bandage'))
	elseif item == 'medikit' then
		xPlayer.showNotification(TranslateCap('used_medikit'))
	end
end)

RegisterNetEvent('esx_ambulancejob:giveItem')
AddEventHandler('esx_ambulancejob:giveItem', function(itemName, amount)
	local xPlayer = ESX.GetPlayerFromId(source)
	amount = getValidItemAmount(amount)
	local now = GetGameTimer()

	if not isAmbulanceOnDuty(xPlayer) then
		print(('[^2WARNING^7] Player ^5%s^7 Tried Giving Themselves -> ^5' .. tostring(itemName) .. '^7!'):format(source))
		return
	elseif (itemName ~= 'medikit' and itemName ~= 'bandage') or not amount or not isNearHospitalMarker(source, 'Pharmacies', 8.0) then
		print(('[^2WARNING^7] Player ^5%s^7 Tried Giving Themselves -> ^5' .. tostring(itemName) .. '^7!'):format(xPlayer.source))
		return
	end

	if itemCooldowns[source] and now - itemCooldowns[source] < (Config.PharmacyCooldown or 5000) then return end
	itemCooldowns[source] = now

	if xPlayer.canCarryItem(itemName, amount) then
		xPlayer.addInventoryItem(itemName, amount)
	else
		xPlayer.showNotification(TranslateCap('max_item'))
	end
end)

ESX.RegisterCommand('revive', 'admin', function(xPlayer, args, showError)
	persistDeathStatus(args.playerId.source, false)
	deadPlayers[args.playerId.source] = nil
	args.playerId.triggerEvent('esx_ambulancejob:revive')
end, true, { help = TranslateCap('revive_help'), validate = true, arguments = {
	{ name = 'playerId', help = 'The player id', type = 'player' }
} })

ESX.RegisterCommand('reviveall', "admin", function(xPlayer, args, showError)
	for targetId in pairs(deadPlayers) do
		persistDeathStatus(targetId, false)
		deadPlayers[targetId] = nil
	end
	TriggerClientEvent('esx_ambulancejob:revive', -1)
end, false)

ESX.RegisterUsableItem('medikit', function(source)
	if not playersHealing[source] then
		local xPlayer = ESX.GetPlayerFromId(source)
		xPlayer.removeInventoryItem('medikit', 1)

		playersHealing[source] = true
		TriggerClientEvent('esx_ambulancejob:useItem', source, 'medikit')

		Wait(10000)
		playersHealing[source] = nil
	end
end)

ESX.RegisterUsableItem('bandage', function(source)
	if not playersHealing[source] then
		local xPlayer = ESX.GetPlayerFromId(source)
		xPlayer.removeInventoryItem('bandage', 1)

		playersHealing[source] = true
		TriggerClientEvent('esx_ambulancejob:useItem', source, 'bandage')

		Wait(10000)
		playersHealing[source] = nil
	end
end)

xLib.callback.registerCompat('esx_ambulancejob:getDeadPlayers', function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)
	if xPlayer.job.name == "ambulance" then
		cb(deadPlayers)
	end
end)

RegisterNetEvent('esx_ambulancejob:requestDeathRestore')
AddEventHandler('esx_ambulancejob:requestDeathRestore', function()
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
	if not xPlayer then return end

	MySQL.scalar('SELECT is_dead FROM users WHERE identifier = ?', { xPlayer.identifier }, function(isDead)
		if isDead ~= true and isDead ~= 1 then return end
		if deadPlayers[_source] then return end

		deadPlayers[_source] = 'dead'
		isDeadState(_source, true)

		local deathTime = xPlayer.getMeta().deathTime
		local elapsed = deathTime and (os.time() - deathTime) or 0
		if elapsed < 0 then elapsed = 0 end

		local Ambulance = ESX.GetExtendedPlayers("job", "ambulance")
		for _, xAmbulance in pairs(Ambulance) do
			xAmbulance.triggerEvent('esx_ambulancejob:PlayerDead', _source)
		end

		xPlayer.triggerEvent('esx_ambulancejob:restoreDeath', elapsed)
	end)
end)
