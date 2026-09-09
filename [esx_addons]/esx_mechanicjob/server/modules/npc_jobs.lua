-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local MechanicJob = ESXMechanicJob
local PlayersNPCJobs = MechanicJob.PlayersNPCJobs
local LastNPCJobReward = MechanicJob.LastNPCJobReward
local NPC_JOB_MIN_DURATION = 30000
local NPC_JOB_REWARD_COOLDOWN = 60000
local NPC_JOB_START_COOLDOWN = 5000
local NPC_JOB_COMPLETE_COOLDOWN = 5000
local NPC_JOB_DELIVERY_DISTANCE = 25.0
local NPC_JOB_VEHICLE_DISTANCE = 15.0
local FLATBED_MODEL = `flatbed`

local function failNPCJobCompletion(source, translationKey)
	local message = translationKey and TranslateCap(translationKey) or nil
	TriggerClientEvent('esx_mechanicjob:npcJobCompletionFailed', source, message)
end

local function getRandomTowableZone()
	if not Config.Towables or #Config.Towables == 0 then
		return nil
	end

	return ('Towable%s'):format(math.random(1, #Config.Towables))
end

local function isPlayerInFlatbed(source)
	local ped = GetPlayerPed(source)
	if not ped or ped == 0 then
		return false
	end

	local vehicle = GetVehiclePedIsIn(ped, false)
	return vehicle ~= 0 and GetEntityModel(vehicle) == FLATBED_MODEL
end

local function normalizeNetId(netId)
	netId = tonumber(netId)

	if not netId then
		return nil
	end

	netId = math.floor(netId)
	if netId <= 0 then
		return nil
	end

	return netId
end

local function getVehicleFromNetId(netId)
	netId = normalizeNetId(netId)
	if not netId then
		return nil
	end

	local vehicle = NetworkGetEntityFromNetworkId(netId)
	if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
		return nil
	end

	return vehicle
end

local function isAllowedTowableModel(model)
	if not Config.Vehicles then
		return false
	end

	for i = 1, #Config.Vehicles do
		if model == joaat(Config.Vehicles[i]) then
			return true
		end
	end

	return false
end

local function isEntityNearCoords(entity, coords, distance)
	return entity and entity ~= 0 and DoesEntityExist(entity) and #(GetEntityCoords(entity) - coords) <= distance
end

local function isEntityNearZone(entity, zoneName, distance)
	local zone = Config.Zones and Config.Zones[zoneName]
	if not zone or not zone.Pos then
		return false
	end

	return isEntityNearCoords(entity, zone.Pos, distance)
end

local function areEntitiesNear(firstEntity, secondEntity, distance)
	if not firstEntity or not secondEntity
		or firstEntity == 0 or secondEntity == 0
		or not DoesEntityExist(firstEntity) or not DoesEntityExist(secondEntity) then
		return false
	end

	return #(GetEntityCoords(firstEntity) - GetEntityCoords(secondEntity)) <= distance
end

local function registerTargetVehicle(npcJob, targetNetId)
	local targetVehicle = getVehicleFromNetId(targetNetId)
	if not targetVehicle then
		return false
	end

	if not isAllowedTowableModel(GetEntityModel(targetVehicle)) then
		return false
	end

	if not isEntityNearZone(targetVehicle, npcJob.targetZone, Config.NPCNextToDistance + 10.0) then
		return false
	end

	npcJob.targetNetId = normalizeNetId(targetNetId)
	return true
end

RegisterNetEvent('esx_mechanicjob:startNPCJob')
AddEventHandler('esx_mechanicjob:startNPCJob', function()
	local source = source
	if MechanicJob.rejectRateLimited(source, 'esx_mechanicjob:startNPCJob', NPC_JOB_START_COOLDOWN) then
		return
	end

	if not MechanicJob.getMechanicPlayer(source) then
		return
	end

	if not isPlayerInFlatbed(source) then
		return
	end

	if PlayersNPCJobs[source] then
		return
	end

	local targetZone = getRandomTowableZone()
	if not targetZone or not Config.Zones[targetZone] then
		return
	end

	PlayersNPCJobs[source] = {
		startedAt = MechanicJob.currentTimeMs(),
		targetZone = targetZone,
		targetNetId = nil,
		targetReached = false
	}

	TriggerClientEvent('esx_mechanicjob:npcJobStarted', source, targetZone)
end)

RegisterNetEvent('esx_mechanicjob:stopNPCJob')
AddEventHandler('esx_mechanicjob:stopNPCJob', function()
	PlayersNPCJobs[source] = nil
end)

RegisterNetEvent('esx_mechanicjob:npcJobTargetSpawned')
AddEventHandler('esx_mechanicjob:npcJobTargetSpawned', function(targetNetId)
	local source = source
	if MechanicJob.rejectRateLimited(source, 'esx_mechanicjob:npcJobTargetSpawned', 2000) then
		return
	end

	if not MechanicJob.getMechanicPlayer(source) then
		PlayersNPCJobs[source] = nil
		return
	end

	local npcJob = PlayersNPCJobs[source]
	if not npcJob or not npcJob.targetZone then
		return
	end

	registerTargetVehicle(npcJob, targetNetId)
end)

RegisterNetEvent('esx_mechanicjob:npcJobTargetReached')
AddEventHandler('esx_mechanicjob:npcJobTargetReached', function(targetNetId)
	local source = source
	if MechanicJob.rejectRateLimited(source, 'esx_mechanicjob:npcJobTargetReached', 2000) then
		return
	end

	if not MechanicJob.getMechanicPlayer(source) then
		PlayersNPCJobs[source] = nil
		return
	end

	local npcJob = PlayersNPCJobs[source]
	if not npcJob or not npcJob.targetZone then
		return
	end

	if not npcJob.targetNetId and not registerTargetVehicle(npcJob, targetNetId) then
		return
	end

	local targetVehicle = getVehicleFromNetId(npcJob.targetNetId)
	if not targetVehicle or not isEntityNearZone(targetVehicle, npcJob.targetZone, Config.NPCNextToDistance + 10.0) then
		return
	end

	if not MechanicJob.isPlayerNearZone(source, npcJob.targetZone, Config.NPCNextToDistance + 5.0) then
		return
	end

	npcJob.targetReached = true
end)

RegisterServerEvent('esx_mechanicjob:onNPCJobMissionCompleted')
AddEventHandler('esx_mechanicjob:onNPCJobMissionCompleted', function(targetNetId, flatbedNetId)
	local source = source
	if MechanicJob.rejectRateLimited(source, 'esx_mechanicjob:onNPCJobMissionCompleted', NPC_JOB_COMPLETE_COOLDOWN) then
		failNPCJobCompletion(source)
		return
	end

	local xPlayer, job = MechanicJob.getMechanicPlayer(source)
	if not xPlayer then
		PlayersNPCJobs[source] = nil
		failNPCJobCompletion(source)
		return
	end

	local now = MechanicJob.currentTimeMs()
	local npcJob = PlayersNPCJobs[source]

	if not npcJob or now - npcJob.startedAt < NPC_JOB_MIN_DURATION then
		failNPCJobCompletion(source, 'not_right_place')
		return
	end

	if not npcJob.targetReached then
		failNPCJobCompletion(source, 'not_right_place')
		return
	end

	targetNetId = normalizeNetId(targetNetId)
	if not targetNetId or not npcJob.targetNetId or targetNetId ~= npcJob.targetNetId then
		failNPCJobCompletion(source, 'not_right_veh')
		return
	end

	local targetVehicle = getVehicleFromNetId(targetNetId)
	if not targetVehicle then
		failNPCJobCompletion(source, 'not_right_veh')
		return
	end

	local flatbedVehicle = getVehicleFromNetId(flatbedNetId)
	if not flatbedVehicle or GetEntityModel(flatbedVehicle) ~= FLATBED_MODEL then
		failNPCJobCompletion(source, 'imp_flatbed')
		return
	end

	if not MechanicJob.isPlayerNearZone(source, 'VehicleDelivery', NPC_JOB_DELIVERY_DISTANCE) then
		failNPCJobCompletion(source, 'not_right_place')
		return
	end

	if not isEntityNearZone(targetVehicle, 'VehicleDelivery', NPC_JOB_DELIVERY_DISTANCE) then
		failNPCJobCompletion(source, 'not_right_place')
		return
	end

	if not MechanicJob.isPlayerNearCoords(source, GetEntityCoords(flatbedVehicle), NPC_JOB_VEHICLE_DISTANCE) then
		failNPCJobCompletion(source, 'not_right_place')
		return
	end

	if not areEntitiesNear(targetVehicle, flatbedVehicle, NPC_JOB_VEHICLE_DISTANCE) then
		failNPCJobCompletion(source, 'not_right_place')
		return
	end

	if (LastNPCJobReward[source] or 0) > now then
		failNPCJobCompletion(source)
		return
	end

	PlayersNPCJobs[source] = nil
	LastNPCJobReward[source] = now + NPC_JOB_REWARD_COOLDOWN

	local total = math.random(Config.NPCJobEarnings.min, Config.NPCJobEarnings.max)

	if (tonumber(job.grade) or 0) >= 3 then
		total = total * 2
	end

	TriggerEvent('esx_addonaccount:getSharedAccount', 'society_mechanic', function(account)
		if not account then
			return
		end

		account.addMoney(total)
	end)

	TriggerClientEvent("esx:showNotification", source, TranslateCap('your_comp_earned') .. total)
	TriggerClientEvent('esx_mechanicjob:npcJobCompleted', source, targetNetId)
end)
