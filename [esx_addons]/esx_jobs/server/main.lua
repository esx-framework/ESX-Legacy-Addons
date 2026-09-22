-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local playersWorking = {}
local cautions = {}

local function getVector3(coords)
	if type(coords) == "vector3" then
		return coords
	end

	if type(coords) == "table" and coords.x and coords.y and coords.z then
		return vector3(coords.x, coords.y, coords.z)
	end
end

local function getZoneDistance(zone)
	local size = zone and zone.Size
	if type(size) ~= "table" then
		return 5.0
	end

	return math.max(tonumber(size.x) or 0.0, tonumber(size.y) or 0.0, tonumber(size.z) or 0.0, 5.0)
end

local function isNearZone(xPlayer, zone)
	local coords = getVector3(zone and zone.Pos)
	if not coords then
		return false
	end

	return #(xPlayer.getCoords(true) - coords) <= getZoneDistance(zone)
end

local function getNearJobZone(xPlayer, zoneKey, zoneType)
	if type(zoneKey) ~= "string" then
		return
	end

	local jobObject = Config.Jobs[xPlayer.getJob().name]
	local zone = jobObject and jobObject.Zones and jobObject.Zones[zoneKey]
	if not zone or zone.Type ~= zoneType or not isNearZone(xPlayer, zone) then
		return
	end

	return zone, jobObject
end

local function getJobVehicleSpawn(xPlayer, zoneKey)
	local spawnerZone, jobObject = getNearJobZone(xPlayer, zoneKey, "vehspawner")
	if not spawnerZone then
		return
	end

	local spawnPoint
	for _, zone in pairs(jobObject.Zones) do
		if zone.Type == "vehspawnpt" and zone.Spawner == spawnerZone.Spawner then
			spawnPoint = zone
			break
		end
	end

	local vehicle
	for _, jobVehicle in pairs(jobObject.Vehicles or {}) do
		if jobVehicle.Spawner == spawnerZone.Spawner then
			vehicle = jobVehicle
			break
		end
	end

	if not spawnPoint or not vehicle then
		return
	end

	return spawnerZone, spawnPoint, vehicle
end

local function isSpawnPointClear(spawnPoint)
	local coords = getVector3(spawnPoint and spawnPoint.Pos)
	if not coords then
		return false
	end

	return #xLib.onesync.getVehiclesInArea(coords, 5.0) == 0
end

local function getCaution(playerId, spawner)
	local playerCautions = cautions[playerId]
	return playerCautions and playerCautions[spawner]
end

local function setCaution(playerId, spawner, entry)
	local playerCautions = cautions[playerId]
	if not playerCautions then
		playerCautions = {}
		cautions[playerId] = playerCautions
	end

	playerCautions[spawner] = entry
end

local function getCautionEntity(entry)
	local entity = entry.netId and NetworkGetEntityFromNetworkId(entry.netId)
	if not entity or entity == 0 or entity ~= entry.entity or not DoesEntityExist(entity) then
		return
	end

	return entity
end

local function clearCaution(playerId, spawner)
	local playerCautions = cautions[playerId]
	local entry = playerCautions and playerCautions[spawner]
	if not entry then
		return
	end

	playerCautions[spawner] = nil
	if not next(playerCautions) then
		cautions[playerId] = nil
	end

	local entity = getCautionEntity(entry)
	if entity then
		DeleteEntity(entity)
	end

	return entry
end

local function isCautionVehicleLost(entry)
	local entity = getCautionEntity(entry)
	return not entity or GetVehicleEngineHealth(entity) <= 0.0
end

local function getVehicleCondition(entity)
	local engineHealth = math.max(0.0, math.min(GetVehicleEngineHealth(entity), 1000.0))
	local bodyHealth = math.max(0.0, math.min(GetVehicleBodyHealth(entity), 1000.0))

	return ESX.Math.Round((engineHealth + bodyHealth) / 2000.0, 2)
end

local function settleCaution(playerId, amount, ratio)
	if amount <= 0 then
		return
	end

	local xPlayer = ESX.Player(playerId)
	if not xPlayer then
		return
	end

	TriggerEvent('esx_addonaccount:getAccount', 'caution', xPlayer.getIdentifier(), function(account)
		if not account then
			return
		end

		local held = math.max(0, math.min(amount, account.money))
		local toGive = ESX.Math.Round(held * ratio)

		if held > 0 then
			account.removeMoney(held)
		end

		if toGive > 0 then
			xPlayer.addAccountMoney('bank', toGive, "Caution Return")
		end

		xPlayer.showNotification(TranslateCap('bank_deposit_returned', ESX.Math.GroupDigits(toGive)))
	end)
end

local function releaseCaution(playerId, spawner)
	local entry = getCaution(playerId, spawner)
	if not entry then
		return
	end

	local ratio = 1.0
	if not entry.pending then
		local entity = getCautionEntity(entry)
		ratio = entity and GetVehicleEngineHealth(entity) > 0.0 and getVehicleCondition(entity) or 0.0
	end

	clearCaution(playerId, spawner)
	settleCaution(playerId, entry.amount, ratio)
end

local function releasePlayerCautions(playerId)
	local playerCautions = cautions[playerId]
	if not playerCautions then
		return
	end

	for spawner in pairs(playerCautions) do
		releaseCaution(playerId, spawner)
	end
end

local function spawnCautionVehicle(playerId, entry, spawnPoint, vehicle)
	local plate = 'WORK' .. math.random(100, 900)

	ESX.OneSync.SpawnVehicle(vehicle.Hash, getVector3(spawnPoint.Pos), spawnPoint.Heading or 0.0, { plate = plate }, function(netId)
		local entity = netId and NetworkGetEntityFromNetworkId(netId)
		local isCurrent = getCaution(playerId, entry.spawner) == entry

		if not entity or entity == 0 or not DoesEntityExist(entity) then
			if isCurrent then
				clearCaution(playerId, entry.spawner)
				settleCaution(playerId, entry.amount, 1.0)
			end

			return
		end

		if not isCurrent then
			DeleteEntity(entity)
			return
		end

		SetVehicleNumberPlateText(entity, plate)
		SetEntityRoutingBucket(entity, GetPlayerRoutingBucket(playerId))

		entry.netId, entry.entity, entry.pending = netId, entity, nil

		TriggerClientEvent('esx_jobs:spawnJobVehicle', playerId, netId, spawnPoint, vehicle)
	end)
end

CreateThread(function()
	while true do
		Wait(1000)
		local timeNow = os.clock()

		for playerId,data in pairs(playersWorking) do
			Wait(0)
			local xPlayer = ESX.Player(playerId)

			-- is player still online?
			if xPlayer then
				local distance = #(xPlayer.getCoords(true) - data.zoneCoords)

				-- player still within zone limits?
				if distance <= data.zoneMaxDistance then
					-- calculate the elapsed time
					local timeElapsed = timeNow - data.time

					if timeElapsed > data.jobItem[1].time then
						data.time = os.clock()

						for k,v in ipairs(data.jobItem) do
							local itemQtty, requiredItemQtty = 0, 0

							if v.name ~= TranslateCap('delivery') then
								itemQtty = xPlayer.getInventoryItem(v.db_name).count
							end

							if data.jobItem[1].requires ~= 'nothing' then
								requiredItemQtty = xPlayer.getInventoryItem(data.jobItem[1].requires).count
							end
			
							if v.name ~= TranslateCap('delivery') and itemQtty >= v.max then
								xPlayer.showNotification(TranslateCap('max_limit', v.name))
								playersWorking[playerId] = nil
							elseif v.requires ~= 'nothing' and requiredItemQtty <= 0 then
								xPlayer.showNotification(TranslateCap('not_enough', data.jobItem[1].requires_name))
								playersWorking[playerId] = nil
							else
								if v.name ~= TranslateCap('delivery') then
									-- chances to drop the item
									if v.drop == 100 then
										xPlayer.addInventoryItem(v.db_name, v.add)
									else
										local chanceToDrop = math.random(100)
										if chanceToDrop <= v.drop then
											xPlayer.addInventoryItem(v.db_name, v.add)
										end
									end
								else
									xPlayer.addMoney(v.price, "Job Payment")
								end
							end
						end
			
						if data.jobItem[1].requires ~= 'nothing' then
							local itemToRemoveQtty = xPlayer.getInventoryItem(data.jobItem[1].requires).count
							if itemToRemoveQtty > 0 then
								xPlayer.removeInventoryItem(data.jobItem[1].requires, data.jobItem[1].remove)
							end
						end
					end
				else
					playersWorking[playerId] = nil
				end
			else
				playersWorking[playerId] = nil
			end
		end
	end
end)

RegisterServerEvent('esx_jobs:startWork', function(zoneIndex, zoneKey)
	if not playersWorking[source] then
		local xPlayer = ESX.Player(source)

		if xPlayer then
			local jobObject = Config.Jobs[xPlayer.getJob().name]

			if jobObject then
				local jobZone = jobObject.Zones[zoneKey]

				if jobZone and jobZone.Item then
					playersWorking[source] = {
						jobItem = jobZone.Item,
						zoneCoords = vector3(jobZone.Pos.x, jobZone.Pos.y, jobZone.Pos.z),
						zoneMaxDistance = jobZone.Size.x,
						time = os.clock()
					}
				end
			end
		end
	end
end)

RegisterServerEvent('esx_jobs:stopWork', function()
	if playersWorking[source] then
		playersWorking[source] = nil
	end
end)

RegisterNetEvent('esx_jobs:caution', function(cautionType, requestValue)
	local playerId = source
	local xPlayer = ESX.Player(playerId)
	if not xPlayer then
		return
	end

	if cautionType == 'take' then
		local spawnerZone, spawnPoint, vehicle = getJobVehicleSpawn(xPlayer, requestValue)
		if not spawnerZone then
			return
		end

		local spawner = spawnerZone.Spawner
		local current = getCaution(playerId, spawner)
		if current then
			if current.pending or not isCautionVehicleLost(current) then
				xPlayer.showNotification(TranslateCap('vehicle_already_out'))
				return
			end

			releaseCaution(playerId, spawner)
		end

		if not isSpawnPointClear(spawnPoint) then
			xPlayer.showNotification(TranslateCap('spawn_blocked'))
			return
		end

		local cautionAmount = ESX.Math.Round(tonumber(spawnerZone.Caution) or 0)
		if cautionAmount > Config.MaxCaution or cautionAmount < 0 then
			return
		end

		local entry = { amount = cautionAmount, spawner = spawner, pending = true }
		setCaution(playerId, spawner, entry)

		if cautionAmount == 0 then
			spawnCautionVehicle(playerId, entry, spawnPoint, vehicle)
			return
		end

		TriggerEvent('esx_addonaccount:getAccount', 'caution', xPlayer.getIdentifier(), function(account)
			if account and xPlayer.getAccount('bank').money >= cautionAmount then
				xPlayer.removeAccountMoney('bank', cautionAmount, "Caution Fine")
				account.addMoney(cautionAmount)
				xPlayer.showNotification(TranslateCap('bank_deposit_taken', ESX.Math.GroupDigits(cautionAmount)))
				spawnCautionVehicle(playerId, entry, spawnPoint, vehicle)
				return
			end

			clearCaution(playerId, spawner)

			if account then
				xPlayer.showNotification(TranslateCap('caution_afford', ESX.Math.GroupDigits(cautionAmount)))
			end
		end)
	elseif cautionType == 'give_back' then
		local returnZone = getNearJobZone(xPlayer, requestValue, "vehdelete")
		if not returnZone then
			return
		end

		local entry = getCaution(playerId, returnZone.Spawner)
		if not entry or entry.pending then
			return
		end

		local entity = getCautionEntity(entry)
		local ped = GetPlayerPed(playerId)
		if not entity or GetVehiclePedIsIn(ped, false) ~= entity or GetPedInVehicleSeat(entity, -1) ~= ped then
			xPlayer.showNotification(TranslateCap('not_your_vehicle'))
			return
		end

		local condition = getVehicleCondition(entity)

		clearCaution(playerId, returnZone.Spawner)
		settleCaution(playerId, entry.amount, condition)
		TriggerClientEvent('esx_jobs:vehicleReturned', playerId, entry.netId, returnZone.Teleport)
	end
end)

AddEventHandler('esx:setJob', function(playerId, job, lastJob)
	if job and lastJob and job.name == lastJob.name then
		return
	end

	releasePlayerCautions(playerId)
end)

AddEventHandler('esx:playerDropped', function(playerId)
	releasePlayerCautions(playerId)
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	for playerId in pairs(cautions) do
		releasePlayerCautions(playerId)
	end
end)
