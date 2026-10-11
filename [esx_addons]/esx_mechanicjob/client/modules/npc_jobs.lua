-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local Mechanic = ESXMechanicJob
local State = Mechanic.State

local function removeBlip(name)
	if State.blips[name] then
		RemoveBlip(State.blips[name])
		State.blips[name] = nil
	end
end

function Mechanic.startNPCJob()
	TriggerServerEvent('esx_mechanicjob:startNPCJob')
end

function Mechanic.stopNPCJob(cancel)
	removeBlip('NPCTargetTowableZone')
	removeBlip('NPCDelivery')

	Config.Zones.VehicleDelivery.Type = -1

	State.npcOnJob = false
	State.npcTargetTowable = nil
	State.npcTargetTowableNetId = nil
	State.npcTargetTowableZone = nil
	State.npcHasSpawnedTowable = false
	State.npcHasBeenNextToTowable = false
	State.npcTargetDeleterZone = false
	State.npcJobCompletionPending = false

	if cancel then
		TriggerServerEvent('esx_mechanicjob:stopNPCJob')
		ESX.ShowNotification(TranslateCap('mission_canceled'), "error")
	end
end

function Mechanic.activateNPCDeliveryRoute()
	ESX.ShowNotification(TranslateCap('please_drop_off'))
	Config.Zones.VehicleDelivery.Type = 1

	removeBlip('NPCTargetTowableZone')

	State.blips.NPCDelivery = xLib.blips.create({
		coords = Config.Zones.VehicleDelivery.Pos,
		route = true
	})
end

RegisterNetEvent('esx_mechanicjob:npcJobStarted')
AddEventHandler('esx_mechanicjob:npcJobStarted', function(targetZone)
	if State.npcOnJob or not Config.Zones[targetZone] then
		return
	end

	State.npcOnJob = true
	State.npcTargetTowableZone = targetZone

	local zone = Config.Zones[targetZone]
	State.blips.NPCTargetTowableZone = xLib.blips.create({
		coords = zone.Pos,
		route = true
	})

	ESX.ShowNotification(TranslateCap('drive_to_indicated'))
end)

RegisterNetEvent('esx_mechanicjob:npcJobCompleted')
AddEventHandler('esx_mechanicjob:npcJobCompleted', function(targetNetId)
	local targetVehicle = targetNetId and NetToVeh(targetNetId) or State.npcTargetTowable

	if Mechanic.vehicleExists(targetVehicle) then
		Mechanic.deleteVehicle(targetVehicle)
	end

	State.currentlyTowedVehicle = nil
	State.npcJobCompletionPending = false
	Mechanic.stopNPCJob()
end)

RegisterNetEvent('esx_mechanicjob:npcJobCompletionFailed')
AddEventHandler('esx_mechanicjob:npcJobCompletionFailed', function(message)
	State.npcJobCompletionPending = false

	if message then
		ESX.ShowNotification(message, "error")
	end
end)

CreateThread(function()
	while true do
		local sleep = 1500

		if State.npcTargetTowableZone and not State.npcHasSpawnedTowable then
			sleep = 0

			local coords = GetEntityCoords(PlayerPedId())
			local zone = Config.Zones[State.npcTargetTowableZone]

			if zone and #(coords - zone.Pos) < Config.NPCSpawnDistance then
				if Config.Vehicles and #Config.Vehicles > 0 then
					local model = Config.Vehicles[math.random(#Config.Vehicles)]

					xLib.game.spawnVehicle(model, zone.Pos, 0.0, function(vehicle)
						State.npcTargetTowable = vehicle
						State.npcTargetTowableNetId = Mechanic.getVehicleNetId(vehicle)

						if State.npcTargetTowableNetId then
							TriggerServerEvent('esx_mechanicjob:npcJobTargetSpawned', State.npcTargetTowableNetId)
						end
					end)
				end

				State.npcHasSpawnedTowable = true
			end
		end

		if State.npcTargetTowableZone and State.npcHasSpawnedTowable and not State.npcHasBeenNextToTowable then
			sleep = 500

			local coords = GetEntityCoords(PlayerPedId())
			local zone = Config.Zones[State.npcTargetTowableZone]

			if zone and #(coords - zone.Pos) < Config.NPCNextToDistance then
				State.npcTargetTowableNetId = State.npcTargetTowableNetId or Mechanic.getVehicleNetId(State.npcTargetTowable)

				if State.npcTargetTowableNetId then
					sleep = 0
					ESX.ShowNotification(TranslateCap('please_tow'))
					TriggerServerEvent('esx_mechanicjob:npcJobTargetReached', State.npcTargetTowableNetId)
					State.npcHasBeenNextToTowable = true
				end
			end
		end

		Wait(sleep)
	end
end)
