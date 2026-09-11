-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local playersHealing = {}
local reviveCooldowns = {}
local itemCooldowns, actionCooldowns = {}, {}

if GetResourceState("esx_phone") ~= 'missing' then
	TriggerEvent('esx_phone:registerNumber', 'ambulance', TranslateCap('alert_ambulance'), true, true)
end

if GetResourceState("esx_society") ~= 'missing' then
	TriggerEvent('esx_society:registerSociety', 'ambulance', 'Ambulance', 'society_ambulance', 'society_ambulance',
		'society_ambulance', { type = 'public' })
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

-- EMS permissions and rewards stay here; the lifecycle belongs to esx_death.
RegisterNetEvent('esx_ambulancejob:revive', function(playerId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local target = tonumber(playerId)
    local xTarget = target and ESX.GetPlayerFromId(target)
    local now = GetGameTimer()
    if not isAmbulanceOnDuty(xPlayer) or not xTarget or exports.esx_death:IsDead(src) then return end
    if reviveCooldowns[src] and now - reviveCooldowns[src] < 8000 then return end
    if not isNearPlayer(src, target, 8.0) or not exports.esx_death:IsDead(target) then return end
    reviveCooldowns[src] = now
    if exports.esx_death:Revive(target, 'ems') then
        if Config.ReviveReward > 0 then
            xPlayer.addMoney(Config.ReviveReward, 'Revive Reward')
            xPlayer.showNotification(TranslateCap('revive_complete_award', xTarget.name, Config.ReviveReward))
        else
            xPlayer.showNotification(TranslateCap('revive_complete', xTarget.name))
        end
    end
end)

local function notifyMedics(event, ...)
    for _, xPlayer in pairs(ESX.GetExtendedPlayers('job', 'ambulance')) do
        xPlayer.triggerEvent(event, ...)
    end
end

AddEventHandler('esx_death:stateChanged', function(playerId, dead)
    notifyMedics(dead and 'esx_ambulancejob:PlayerDead' or 'esx_ambulancejob:PlayerNotDead', playerId)
end)

AddEventHandler('esx_death:distress', function(playerId, coords)
    notifyMedics('esx_ambulancejob:PlayerDistressed', playerId, coords)
end)

RegisterNetEvent('esx_ambulancejob:svsearch', function()
    local src = source
    if not isAmbulanceOnDuty(ESX.GetPlayerFromId(src)) or exports.esx_death:IsDead(src) then return end
    for target in pairs(exports.esx_death:GetDeadPlayers()) do
        if isNearPlayer(src, target, 3.0) then
            TriggerClientEvent('esx_ambulancejob:clsearch', target, src)
        end
    end
end)

AddEventHandler('esx:playerDropped', function(playerId)
    reviveCooldowns[playerId], itemCooldowns[playerId], actionCooldowns[playerId], playersHealing[playerId] = nil, nil, nil, nil
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
    if not isAmbulanceOnDuty(xPlayer) then return cb({}) end
    cb(exports.esx_death:GetDeadPlayers(), exports.esx_death:GetDeadPlayerLocations())
end)
