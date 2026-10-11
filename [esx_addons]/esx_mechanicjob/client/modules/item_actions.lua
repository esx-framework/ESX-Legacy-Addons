-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local Mechanic = ESXMechanicJob
local State = Mechanic.State

local function getNearbyVehicle(playerPed, coords)
	if IsPedInAnyVehicle(playerPed, false) then
		return GetVehiclePedIsIn(playerPed, false)
	end

	local vehicle = xLib.game.getClosestVehicle(coords)
	if Mechanic.vehicleExists(vehicle) then
		return vehicle
	end

	return nil
end

local function runItemVehicleAction(scenario, duration, successKey, action, beforeAction)
	if State.isBusy then
		return
	end

	local playerPed = PlayerPedId()
	local coords = GetEntityCoords(playerPed)

	if not IsAnyVehicleNearPoint(coords.x, coords.y, coords.z, 5.0) then
		ESX.ShowNotification(TranslateCap('no_vehicle_nearby'))
		return
	end

	local vehicle = getNearbyVehicle(playerPed, coords)
	if not vehicle then
		ESX.ShowNotification(TranslateCap('no_vehicle_nearby'))
		return
	end

	State.isBusy = true

	if beforeAction then
		beforeAction(vehicle)
	end

	TaskStartScenarioInPlace(playerPed, scenario, 0, true)

	CreateThread(function()
		Wait(duration)

		if Mechanic.vehicleExists(vehicle) and Mechanic.requestEntityControl(vehicle, 1000) then
			action(vehicle)
			ESX.ShowNotification(TranslateCap(successKey))
		else
			ESX.ShowNotification(TranslateCap('no_vehicle_nearby'))
		end

		ClearPedTasksImmediately(playerPed)
		State.isBusy = false
	end)
end

RegisterNetEvent('esx_mechanicjob:onHijack')
AddEventHandler('esx_mechanicjob:onHijack', function()
	local chance = math.random(100)
	local alarm = math.random(100)

	runItemVehicleAction('WORLD_HUMAN_WELDING', 10000, chance <= 66 and 'veh_unlocked' or 'hijack_failed', function(vehicle)
		if chance <= 66 then
			SetVehicleDoorsLocked(vehicle, 1)
			SetVehicleDoorsLockedForAllPlayers(vehicle, false)
		end
	end, function(vehicle)
		if alarm <= 33 then
			SetVehicleAlarm(vehicle, true)
			StartVehicleAlarm(vehicle)
		end
	end)
end)

RegisterNetEvent('esx_mechanicjob:onCarokit')
AddEventHandler('esx_mechanicjob:onCarokit', function()
	runItemVehicleAction('WORLD_HUMAN_HAMMERING', 10000, 'body_repaired', function(vehicle)
		SetVehicleFixed(vehicle)
		SetVehicleDeformationFixed(vehicle)
	end)
end)

RegisterNetEvent('esx_mechanicjob:onFixkit')
AddEventHandler('esx_mechanicjob:onFixkit', function()
	runItemVehicleAction('PROP_HUMAN_BUM_BIN', 20000, 'veh_repaired', function(vehicle)
		SetVehicleFixed(vehicle)
		SetVehicleDeformationFixed(vehicle)
		SetVehicleUndriveable(vehicle, false)
	end)
end)
