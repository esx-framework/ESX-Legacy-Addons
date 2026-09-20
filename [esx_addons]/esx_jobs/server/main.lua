-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local playersWorking = {}

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

local function getJobVehicleSpawn(xPlayer, zoneKey)
	if type(zoneKey) ~= "string" then
		return
	end

	local jobObject = Config.Jobs[xPlayer.getJob().name]
	local spawnerZone = jobObject and jobObject.Zones and jobObject.Zones[zoneKey]
	if not spawnerZone or spawnerZone.Type ~= "vehspawner" or not isNearZone(xPlayer, spawnerZone) then
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
	local xPlayer = ESX.Player(source)
	if not xPlayer then
		return
	end

	local identifier = xPlayer.getIdentifier()
	if cautionType == 'take' then
		local spawnerZone, spawnPoint, vehicle = getJobVehicleSpawn(xPlayer, requestValue)
		if not spawnerZone then
			return
		end

		if not isSpawnPointClear(spawnPoint) then
			xPlayer.showNotification(TranslateCap('spawn_blocked'))
			return
		end

		local cautionAmount = ESX.Math.Round(tonumber(spawnerZone.Caution) or 0)
		if cautionAmount <= Config.MaxCaution and cautionAmount >= 0 then
			if cautionAmount == 0 then
				TriggerClientEvent('esx_jobs:spawnJobVehicle', xPlayer.src, spawnPoint, vehicle)
				return
			end

			TriggerEvent('esx_addonaccount:getAccount', 'caution', identifier, function(account)
				if not account then
					return
				end

				if xPlayer.getAccount('bank').money >= cautionAmount then
					xPlayer.removeAccountMoney('bank', cautionAmount, "Caution Fine")
					account.addMoney(cautionAmount)
					xPlayer.showNotification(TranslateCap('bank_deposit_taken', ESX.Math.GroupDigits(cautionAmount)))
					TriggerClientEvent('esx_jobs:spawnJobVehicle', xPlayer.src, spawnPoint, vehicle)
				else
					xPlayer.showNotification(TranslateCap('caution_afford', ESX.Math.GroupDigits(cautionAmount)))
				end
			end)
		end
	elseif cautionType == 'give_back' then
		local cautionAmount = tonumber(requestValue)
		if cautionAmount and cautionAmount <= 1 and cautionAmount > 0 then
			TriggerEvent('esx_addonaccount:getAccount', 'caution', identifier, function(account)
				if not account then
					return
				end

				local caution = account.money
				local toGive = ESX.Math.Round(caution * cautionAmount)
	
				xPlayer.addAccountMoney('bank', toGive, "Caution Return")
				account.removeMoney(toGive)
				TriggerClientEvent('esx:showNotification', source, TranslateCap('bank_deposit_returned', ESX.Math.GroupDigits(toGive)))
			end)
		end
	end
end)
