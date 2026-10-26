-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

ESXCatalog.awaitReady()

function ParkBoats()
	MySQL.update('UPDATE owned_vehicles SET `stored` = true WHERE `stored` = false AND type = @type', {
		['@type'] = 'boat'
	}, function (rowsChanged)
		if rowsChanged > 0 then
			print(('[^2INFO^7] Stored ^5%s^7 %s !'):format(rowsChanged, rowsChanged > 1 and 'boats' or 'boat'))
		end
	end)
end

MySQL.ready(function()
	ParkBoats()
end)

local normalizePlate = xLib.vehiclePlate.normalize

local function generateBoatPlate()
	return xLib.vehiclePlate.generateUnique({
		prefix = 'BO',
		letters = 2,
		numbers = 4
	}, function(plate)
		return MySQL.scalar.await('SELECT plate FROM owned_vehicles WHERE plate = ?', {plate}) ~= nil
	end)
end

local getPlayerCoords = xLib.player.getCoords
local function isNearCoords(source, coords, distance)
	if type(coords) == 'vector4' then
		coords = vector3(coords.x, coords.y, coords.z)
	end

	return xLib.player.isNearCoords(source, coords, distance)
end

local function isNearBoatShop(source)
	for i = 1, #(Config.Zones.BoatShops or {}) do
		local shop = Config.Zones.BoatShops[i]
		if isNearCoords(source, shop.Outside, 20.0) or isNearCoords(source, shop.Inside, 35.0) then
			return true
		end
	end

	return false
end

local function isNearGarage(source, key, distance)
	for i = 1, #(Config.Zones.Garages or {}) do
		local garage = Config.Zones.Garages[i]
		if isNearCoords(source, garage[key], distance) then
			return true
		end
	end

	return false
end

local function isNearBoatWithPlate(source, plate, distance)
	local ped = GetPlayerPed(source)
	if ped <= 0 then return false end

	local playerCoords = GetEntityCoords(ped)
	local currentVehicle = GetVehiclePedIsIn(ped, false)
	if currentVehicle ~= 0 and normalizePlate(GetVehicleNumberPlateText(currentVehicle)) == plate then
		return true
	end

	for _, vehicle in ipairs(GetAllVehicles()) do
		if DoesEntityExist(vehicle) and normalizePlate(GetVehicleNumberPlateText(vehicle)) == plate and #(GetEntityCoords(vehicle) - playerCoords) <= (distance or 15.0) then
			return true
		end
	end

	return false
end

local function getVehicleFromHash(model)
	for k,v in ipairs(Config.Vehicles) do
		if joaat(v.model) == model then
			return v
		end
	end

	return nil
end

xLib.callback.registerCompat('esx_boat:buyBoat', function(source, cb, vehicleProps, account)
    local xPlayer = ESX.GetPlayerFromId(source)
    local model = type(vehicleProps) == 'table' and tonumber(vehicleProps.model)
    local vehicleData = model and getVehicleFromHash(model)
    local price = vehicleData and tonumber(vehicleData.price) or 0

    -- vehicle model not found
    if not xPlayer or price == 0 or not isNearBoatShop(source) then
        print(('[^2INFO^7] Player ^5%s^7 Attempted To Exploit Shop'):format(source))
        return cb(false, 'invalid_purchase')
    end

    local plate = generateBoatPlate()

    if not plate then
        return cb(false, 'plate_unavailable')
    end

    if xPlayer.isCurrent() ~= true or not isNearBoatShop(source) then
        return cb(false, 'purchase_invalidated')
    end

    local storedProps = {model = model, plate = plate}
    if type(vehicleData.props) == 'table' then
        for key, value in pairs(vehicleData.props) do
            storedProps[key] = value
        end
    end

    local charged, failure = PaymentGateway.Charge(xPlayer, account, price, "Boat Purchase")

    if not charged then
        return cb(false, failure)
    end

    local query = 'INSERT INTO owned_vehicles (owner, plate, vehicle, type, `stored`) '
        .. 'VALUES (@owner, @plate, @vehicle, @type, @stored)'

    MySQL.insert(query, {
        ['@owner']   = xPlayer.getIdentifier(),
        ['@plate']   = plate,
        ['@vehicle'] = json.encode(storedProps),
        ['@type']    = 'boat',
        ['@stored']  = true
    }, function(insertId)
        if not insertId then
            PaymentGateway.Refund(xPlayer, account, price, "Boat Purchase Refund")
            return cb(false, 'persistence_failed')
        end

        cb(true)
    end)
end)

RegisterServerEvent('esx_boat:takeOutVehicle')
AddEventHandler('esx_boat:takeOutVehicle', function(plate)
	local xPlayer = ESX.Player(source)
	plate = normalizePlate(plate)

	if not xPlayer or not plate or not isNearGarage(source, 'GaragePos', 20.0) then return end

	MySQL.update('UPDATE owned_vehicles SET `stored` = @stored WHERE owner = @owner AND plate = @plate AND type = @type AND `stored` = true', {
		['@stored'] = false,
		['@owner']  = xPlayer.getIdentifier(),
		['@plate']  = plate,
		['@type']   = 'boat'
	}, function(rowsChanged)
		if rowsChanged == 0 then
			print(('[^2INFO^7] Player ^5%s^7 Attempted To Exploit Garage'):format(xPlayer.src))
		end
	end)
end)

xLib.callback.registerCompat('esx_boat:storeVehicle', function (source, cb, plate)
	local xPlayer = ESX.Player(source)
	plate = normalizePlate(plate)

	if not xPlayer or not plate or not isNearGarage(source, 'StorePos', 25.0) or not isNearBoatWithPlate(source, plate, 20.0) then
		return cb(0)
	end

	MySQL.update('UPDATE owned_vehicles SET `stored` = @stored WHERE owner = @owner AND plate = @plate AND type = @type AND `stored` = false', {
		['@stored'] = true,
		['@owner']  = xPlayer.getIdentifier(),
		['@plate']  = plate,
		['@type']   = 'boat'
	}, function(rowsChanged)
		cb(rowsChanged)
	end)
end)

xLib.callback.registerCompat('esx_boat:getGarage', function(source, cb)
	local xPlayer = ESX.Player(source)
	if not xPlayer or not isNearGarage(source, 'GaragePos', 20.0) then return cb({}) end

	MySQL.query('SELECT vehicle FROM owned_vehicles WHERE owner = @owner AND type = @type AND `stored` = @stored', {
		['@owner']  = xPlayer.getIdentifier(),
		['@type']   = 'boat',
		['@stored'] = true
	}, function(result)
		local vehicles = {}

		for i=1, #result, 1 do
			table.insert(vehicles, result[i].vehicle)
		end

		cb(vehicles)
	end)
end)

xLib.callback.registerCompat('esx_boat:buyBoatLicense', function(source, cb, account)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer or not isNearBoatShop(source) then
        return cb(false, 'invalid_purchase')
    end

    TriggerEvent('esx_license:checkLicense', source, 'boat', function(hasLicense)
        if xPlayer.isCurrent() ~= true then
            return cb(false, 'session_closing')
        end

        if hasLicense then
            return cb(false, 'already_owned')
        end

        if not isNearBoatShop(source) then
            return cb(false, 'not_near_shop')
        end

        local charged, failure =
            PaymentGateway.Charge(xPlayer, account, Config.LicensePrice, "Boat License Purchase")

        if not charged then
            return cb(false, failure)
        end
        TriggerEvent('esx_license:addLicense', source, 'boat', function(result)
            if not result then
                PaymentGateway.Refund(xPlayer, account, Config.LicensePrice, "Boat License Refund")
                return cb(false, 'license_failed')
            end

            cb(true)
        end)
    end)
end)

function getPriceFromModel(model)
	for k,v in ipairs(Config.Vehicles) do
		if joaat(v.model) == model then
			return v.price
		end
	end

	return 0
end
