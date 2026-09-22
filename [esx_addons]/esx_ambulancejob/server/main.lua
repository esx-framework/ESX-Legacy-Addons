-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local playersHealing = {}
local reviveLimiter = xLib.rateLimiter({ capacity = 1, refill = 1, interval = 8000, staleMs = 60000 })
local actionLimiter = xLib.rateLimiter({ capacity = 1, refill = 1, interval = 3000, staleMs = 60000 })
local pharmacyLimiter = xLib.rateLimiter({
    capacity = 1,
    refill = 1,
    interval = math.max(1, tonumber(Config.PharmacyCooldown) or 5000),
    staleMs = 60000
})

local function deathDbg(message, data)
    if not Config.DebugDeath then return end
    local suffix = ''
    if data ~= nil then
        local ok, encoded = pcall(function() return json.encode(data) end)
        suffix = (' | %s'):format(ok and encoded or tostring(data))
    end
    print(('[esx_ambulancejob:death-debug] %s%s'):format(message, suffix))
end

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

local function hasItem(xPlayer, itemName)
	local item = xPlayer.getInventoryItem(itemName)
	return item ~= nil and (tonumber(item.count) or 0) >= 1
end

local function consumeItem(xPlayer, itemName)
	xPlayer.removeInventoryItem(itemName, 1)
	xPlayer.showNotification(TranslateCap(itemName == 'bandage' and 'used_bandage' or 'used_medikit'))
end

-- EMS permissions and rewards stay here; the lifecycle belongs to esx_death.
RegisterNetEvent('esx_ambulancejob:revive', function(playerId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local target = tonumber(playerId)
    local xTarget = target and ESX.GetPlayerFromId(target)
    deathDbg('revive:attempt', { src = src, target = target, hasMedic = xPlayer ~= nil, hasTarget = xTarget ~= nil })
    if not isAmbulanceOnDuty(xPlayer) then
        deathDbg('revive:blocked-medic-not-on-duty', { src = src, job = xPlayer and xPlayer.job })
        return
    end
    if not xTarget then
        deathDbg('revive:blocked-target-missing', { src = src, target = target })
        return
    end
    local medicDead = exports.esx_death:IsDead(src)
    if medicDead then
        deathDbg('revive:blocked-medic-dead', { src = src })
        return
    end
    local reviveAllowed, reviveRetry = reviveLimiter:consume(src)
    if not reviveAllowed then
        deathDbg('revive:blocked-cooldown', { src = src, retryAfter = reviveRetry })
        return
    end
    local nearby = isNearPlayer(src, target, 8.0)
    local targetDead = exports.esx_death:IsDead(target)
    if not nearby or not targetDead then
        deathDbg('revive:blocked-nearby-or-target-alive', { src = src, target = target, nearby = nearby, targetDead = targetDead })
        return
    end
    if not hasItem(xPlayer, 'medikit') then
        xPlayer.showNotification(TranslateCap('not_enough_medikit'))
        return
    end
    local ok = exports.esx_death:Revive(target, 'ems')
    deathDbg('revive:export-result', { src = src, target = target, ok = ok })
    if ok then
        consumeItem(xPlayer, 'medikit')
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
    playersHealing[playerId] = nil
end)

RegisterNetEvent('esx_ambulancejob:heal')
AddEventHandler('esx_ambulancejob:heal', function(target, type)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(source)
	local xTarget = ESX.GetPlayerFromId(tonumber(target))
	type = tostring(type or '')

	if not isAmbulanceOnDuty(xPlayer) or not xTarget or (type ~= 'small' and type ~= 'big') or not isNearPlayer(src, xTarget.source, 8.0) then return end
	if not actionLimiter:consume(src) then return end

	local itemName = type == 'small' and 'bandage' or 'medikit'
	if not hasItem(xPlayer, itemName) then
		xPlayer.showNotification(TranslateCap(itemName == 'bandage' and 'not_enough_bandage' or 'not_enough_medikit'))
		return
	end

	consumeItem(xPlayer, itemName)
	TriggerClientEvent('esx_ambulancejob:heal', xTarget.source, type)
end)

RegisterNetEvent('esx_ambulancejob:putInVehicle')
AddEventHandler('esx_ambulancejob:putInVehicle', function(target)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(source)
	local xTarget = ESX.GetPlayerFromId(tonumber(target))

	if not isAmbulanceOnDuty(xPlayer) or not xTarget or not isNearPlayer(src, xTarget.source, 8.0) then return end
	if not actionLimiter:consume(src) then return end

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

RegisterNetEvent('esx_ambulancejob:giveItem')
AddEventHandler('esx_ambulancejob:giveItem', function(itemName, amount)
	local xPlayer = ESX.GetPlayerFromId(source)
	amount = getValidItemAmount(amount)

	if not isAmbulanceOnDuty(xPlayer) then
		print(('[^2WARNING^7] Player ^5%s^7 Tried Giving Themselves -> ^5' .. tostring(itemName) .. '^7!'):format(source))
		return
	elseif (itemName ~= 'medikit' and itemName ~= 'bandage') or not amount or not isNearHospitalMarker(source, 'Pharmacies', 8.0) then
		print(('[^2WARNING^7] Player ^5%s^7 Tried Giving Themselves -> ^5' .. tostring(itemName) .. '^7!'):format(xPlayer.source))
		return
	end

	if not pharmacyLimiter:consume(source) then return end

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
