-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local Mechanic = ESXMechanicJob

function Mechanic.vehicleExists(vehicle)
	return vehicle and vehicle ~= 0 and DoesEntityExist(vehicle)
end

function Mechanic.requestEntityControl(entity, timeout)
	if not Mechanic.vehicleExists(entity) then
		return false
	end

	if NetworkHasControlOfEntity(entity) then
		return true
	end

	local deadline = GetGameTimer() + (timeout or 750)

	repeat
		NetworkRequestControlOfEntity(entity)
		Wait(0)
	until NetworkHasControlOfEntity(entity) or GetGameTimer() >= deadline

	return NetworkHasControlOfEntity(entity)
end

function Mechanic.getVehicleNetId(vehicle)
	if not Mechanic.vehicleExists(vehicle) then
		return nil
	end

	if not NetworkGetEntityIsNetworked(vehicle) then
		NetworkRegisterEntityAsNetworked(vehicle)
	end

	local netId = VehToNet(vehicle)
	if not netId or netId == 0 then
		return nil
	end

	return netId
end

function Mechanic.getVehicleInDirection()
	local vehicle = xLib.game.getVehicleInDirection()

	if Mechanic.vehicleExists(vehicle) then
		return vehicle
	end

	local playerPed = PlayerPedId()
	local coords = GetEntityCoords(playerPed)
	local closestVehicle, closestDistance = xLib.game.getClosestVehicle(coords)
	local maxDistance = Config.ActionVehicleDistance or 5.0

	if Mechanic.vehicleExists(closestVehicle) and closestDistance ~= -1 and closestDistance <= maxDistance then
		return closestVehicle
	end

	return nil
end

function Mechanic.getNearbyFlatbed(playerPed)
	local coords = GetEntityCoords(playerPed)
	local lastVehicle = GetVehiclePedIsIn(playerPed, true)

	if Mechanic.vehicleExists(lastVehicle)
		and IsVehicleModel(lastVehicle, `flatbed`)
		and #(coords - GetEntityCoords(lastVehicle)) <= 12.0 then
		return lastVehicle
	end

	local flatbedFilter = {}
	flatbedFilter[`flatbed`] = true

	local closestVehicle, closestDistance = xLib.game.getClosestVehicle(coords, flatbedFilter)

	if Mechanic.vehicleExists(closestVehicle) and closestDistance ~= -1 and closestDistance <= 12.0 then
		return closestVehicle
	end

	return nil
end

function Mechanic.isNPCTargetVehicle(vehicle)
	local state = Mechanic.State

	if not state.npcOnJob or not Mechanic.vehicleExists(vehicle) then
		return false
	end

	if state.npcTargetTowable and vehicle == state.npcTargetTowable then
		return true
	end

	local netId = Mechanic.getVehicleNetId(vehicle)
	return state.npcTargetTowableNetId and netId and state.npcTargetTowableNetId == netId
end

function Mechanic.attachVehicleToFlatbed(targetVehicle, flatbedVehicle)
	if not Mechanic.vehicleExists(targetVehicle) or not Mechanic.vehicleExists(flatbedVehicle) then
		return false
	end

	if not Mechanic.requestEntityControl(targetVehicle) or not Mechanic.requestEntityControl(flatbedVehicle) then
		return false
	end

	AttachEntityToEntity(targetVehicle, flatbedVehicle, 20, -0.5, -5.0, 1.0, 0.0, 0.0, 0.0, false,
		false, false, false, 20, true)

	return true
end

function Mechanic.detachVehicleFromFlatbed(targetVehicle, flatbedVehicle)
	if not Mechanic.vehicleExists(targetVehicle) or not Mechanic.vehicleExists(flatbedVehicle) then
		return false
	end

	if not Mechanic.requestEntityControl(targetVehicle) or not Mechanic.requestEntityControl(flatbedVehicle) then
		return false
	end

	AttachEntityToEntity(targetVehicle, flatbedVehicle, 20, -0.5, -12.0, 1.0, 0.0, 0.0, 0.0, false,
		false, false, false, 20, true)
	DetachEntity(targetVehicle, true, true)

	return true
end

function Mechanic.deleteVehicle(vehicle)
	if not Mechanic.vehicleExists(vehicle) then
		return false
	end

	Mechanic.requestEntityControl(vehicle, 1000)
	xLib.game.deleteVehicle(vehicle)

	return true
end

function Mechanic.markVehicleImpounded(vehicle)
	if not Mechanic.vehicleExists(vehicle) then
		return
	end

	local plate = ESX.Math.Trim(GetVehicleNumberPlateText(vehicle) or '')
	if plate ~= '' then
		TriggerServerEvent('esx_mechanicjob:impoundOwnedVehicle', plate, Mechanic.getVehicleNetId(vehicle))
	end
end

function Mechanic.spawnObject(model)
	local playerPed = PlayerPedId()
	local coords = GetEntityCoords(playerPed)
	local forward = GetEntityForwardVector(playerPed)
	local x, y, z = table.unpack(coords + forward * 1.0)

	if model == 'prop_roadcone02a' or model == 'prop_toolchest_01' then
		z = z - 2.0
	end

	xLib.game.spawnObject(model, { x = x, y = y, z = z }, function(object)
		SetEntityHeading(object, GetEntityHeading(playerPed))
		PlaceObjectOnGroundProperly(object)
	end)
end
