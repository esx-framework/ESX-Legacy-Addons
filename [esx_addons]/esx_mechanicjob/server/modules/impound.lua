-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local MechanicJob = ESXMechanicJob

local function normalizeImpoundPlate(plate)
	if type(plate) ~= 'string' then
		return nil
	end

	plate = plate:gsub("^%s+", ""):gsub("%s+$", "")
	if plate == "" or #plate > 12 then
		return nil
	end

	return plate
end

local function impoundPlateKey(plate)
	return plate:gsub("^%s+", ""):gsub("%s+$", ""):upper()
end

local function getVehicleFromNetId(netId)
	netId = tonumber(netId)

	if not netId then
		return nil
	end

	netId = math.floor(netId)
	if netId <= 0 then
		return nil
	end

	local vehicle = NetworkGetEntityFromNetworkId(netId)
	if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
		return nil
	end

	return vehicle
end

local function isImpoundVehicleNearPlayer(ped, coords, vehicle, plateKey)
	if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
		return false
	end

	if impoundPlateKey(GetVehicleNumberPlateText(vehicle) or '') ~= plateKey then
		return false
	end

	return GetVehiclePedIsIn(ped, false) == vehicle or #(GetEntityCoords(vehicle) - coords) <= 8.0
end

local function isNearImpoundVehicle(source, plate, vehicleNetId)
	local ped = GetPlayerPed(source)
	if not ped or ped == 0 then
		return false
	end

	local plateKey = impoundPlateKey(plate)
	local coords = GetEntityCoords(ped)
	local vehicle = getVehicleFromNetId(vehicleNetId)

	if isImpoundVehicleNearPlayer(ped, coords, vehicle, plateKey) then
		return true
	end

	vehicle = GetVehiclePedIsIn(ped, false)
	if isImpoundVehicleNearPlayer(ped, coords, vehicle, plateKey) then
		return true
	end

	local vehicles = GetAllVehicles()

	for i = 1, #vehicles do
		if isImpoundVehicleNearPlayer(ped, coords, vehicles[i], plateKey) then
			return true
		end
	end

	return false
end

RegisterNetEvent('esx_mechanicjob:impoundOwnedVehicle')
AddEventHandler('esx_mechanicjob:impoundOwnedVehicle', function(plate, vehicleNetId)
	local source = source

	if MechanicJob.rejectRateLimited(source, 'esx_mechanicjob:impoundOwnedVehicle', 1500) then
		return
	end

	if not MechanicJob.getMechanicPlayer(source) then
		print(('[^3WARNING^7] Player ^5%s^7 Attempted To Exploit Vehicle Impound!'):format(source))
		return
	end

	plate = normalizeImpoundPlate(plate)
	if not plate then
		return
	end

	if not isNearImpoundVehicle(source, plate, vehicleNetId) then
		return
	end

	pcall(function()
		exports['esx_garage']:impoundVehicle(plate)
	end)
end)
