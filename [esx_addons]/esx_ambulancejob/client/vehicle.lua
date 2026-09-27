-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local spawnedVehicles = {}

function OpenVehicleSpawnerMenu(type, hospital, part, partNum)
	local playerCoords = GetEntityCoords(PlayerPedId())
	local elements = {
		{label = TranslateCap('garage_storeditem'), action = 'garage'},
		{label = TranslateCap('garage_storeitem'), action = 'store_garage'},
		{label = TranslateCap('garage_buyitem'), action = 'buy_vehicle'}
	}

	OpenAmbulanceMenu('default', 'vehicle_spawner', TranslateCap('garage_title'), elements, function(data, menu)
		if data.current.action == "buy_vehicle" then
			local shopElements = {}
			local authorizedVehicles = Config.AuthorizedVehicles[type][ESX.PlayerData.job.grade_name] 	
			local shopCoords = Config.Hospitals[hospital][part][partNum].InsideShop

			if #authorizedVehicles > 0 then
				for k,vehicle in ipairs(authorizedVehicles) do
					if IsModelInCdimage(vehicle.model) then
						local vehicleLabel = GetLabelText(GetDisplayNameFromVehicleModel(vehicle.model))

						shopElements[#shopElements+1] = {
							label = ('%s - <span style="color:green;">%s</span>'):format(vehicleLabel, TranslateCap('shop_item', ESX.Math.GroupDigits(vehicle.price))),
							name  = vehicleLabel,
							model = vehicle.model,
							price = vehicle.price,
							props = vehicle.props,
							type  = type
						}
					end
				end

				if #shopElements > 0 then
					OpenShopMenu(shopElements, playerCoords, shopCoords)
				else
					ESX.ShowNotification(TranslateCap('garage_notauthorized'))
				end
			else
				ESX.ShowNotification(TranslateCap('garage_notauthorized'))
			end
		elseif data.current.action == "garage" then
			local garage = {}

			xLib.callback('esx_vehicleshop:retrieveJobVehicles', false, function(jobVehicles)
				if #jobVehicles > 0 then
					local allVehicleProps = {}

					for k,v in ipairs(jobVehicles) do
						local props = json.decode(v.vehicle)

						if IsModelInCdimage(props.model) then
							local vehicleName = GetLabelText(GetDisplayNameFromVehicleModel(props.model))
							local label = ('%s - <span style="color:darkgoldenrod;">%s</span>: '):format(vehicleName, props.plate)

							if v.stored == 1 or v.stored == true then
								label = label .. ('<span style="color:green;">%s</span>'):format(TranslateCap('garage_stored'))
							elseif v.stored == 0 or v.stored == false then
								label = label .. ('<span style="color:darkred;">%s</span>'):format(TranslateCap('garage_notstored'))
							end

							garage[#garage+1] = {
								label = label,
								stored = v.stored,
								model = props.model,
								plate = props.plate
							}

							allVehicleProps[props.plate] = props
						end
					end

					if #garage > 0 then
						OpenAmbulanceMenu('default', 'vehicle_garage', 'Garage', garage, function(dataG, menuG)
							if dataG.current.stored == 1 then
								local foundSpawn, spawnPoint = GetAvailableVehicleSpawnPoint(hospital, part, partNum)

								if foundSpawn then
									menuG.close()
									menu.close()

									xLib.game.spawnVehicle(dataG.current.model, spawnPoint.coords, spawnPoint.heading, function(vehicle)
										local vehicleProps = allVehicleProps[dataG.current.plate]
										xLib.game.setVehicleProperties(vehicle, vehicleProps)

										TriggerServerEvent('esx_vehicleshop:setJobVehicleState', dataG.current.plate, false)
										ESX.ShowNotification(TranslateCap('garage_released'))
									end)
								end
							else
								ESX.ShowNotification(TranslateCap('garage_notavailable'))
							end
						end, function(dataG, menuG)
							menuG.close()
						end)
					else
						ESX.ShowNotification(TranslateCap('garage_empty'))
					end
				else
					ESX.ShowNotification(TranslateCap('garage_empty'))
				end
			end, type)
		elseif data.current.action == "store_garage" then
			StoreNearbyVehicle(playerCoords)
		end
	end, function(data, menu)
		menu.close()
	end)
end

function StoreNearbyVehicle(playerCoords)
	local vehicles, plates, index = xLib.game.getVehiclesInArea(playerCoords, 30.0), {}, {}

	if next(vehicles) then
		for i = 1, #vehicles do
			local vehicle = vehicles[i]
			
			-- Make sure the vehicle we're saving is empty, or else it won't be deleted
			if GetVehicleNumberOfPassengers(vehicle) == 0 and IsVehicleSeatFree(vehicle, -1) then
				local plate = ESX.Math.Trim(GetVehicleNumberPlateText(vehicle))
				plates[#plates + 1] = plate
				index[plate] = vehicle
			end
		end
	else
		ESX.ShowNotification(TranslateCap('garage_store_nearby'))
		return
	end

	xLib.callback('esx_ambulancejob:storeNearbyVehicle', false, function(plate)
		if plate then
			local vehicleId = index[plate]
			local attempts = 0
			xLib.game.deleteVehicle(vehicleId)
			isBusy = true

			CreateThread(function()
				BeginTextCommandBusyspinnerOn('STRING')
				AddTextComponentSubstringPlayerName(TranslateCap('garage_storing'))
				EndTextCommandBusyspinnerOn(4)

				while isBusy do
					Wait(100)
				end

				BusyspinnerOff()
			end)

			-- Workaround for vehicle not deleting when other players are near it.
			while DoesEntityExist(vehicleId) do
				Wait(500)
				attempts = attempts + 1

				-- Give up
				if attempts > 30 then
					break
				end

				vehicles = xLib.game.getVehiclesInArea(playerCoords, 30.0)
				if #vehicles > 0 then
					for i = 1, #vehicles do
						local vehicle = vehicles[i]
						if ESX.Math.Trim(GetVehicleNumberPlateText(vehicle)) == plate then
							xLib.game.deleteVehicle(vehicle)
							break
						end
					end
				end
			end

			isBusy = false
			ESX.ShowNotification(TranslateCap('garage_has_stored'))
		else
			ESX.ShowNotification(TranslateCap('garage_has_notstored'))
		end
	end, plates)
end

function GetAvailableVehicleSpawnPoint(hospital, part, partNum)
	local spawnPoints = Config.Hospitals[hospital][part][partNum].SpawnPoints
	local found, foundSpawnPoint = false, nil

	for i=1, #spawnPoints, 1 do
		if xLib.game.isSpawnPointClear(spawnPoints[i].coords, spawnPoints[i].radius) then
			found, foundSpawnPoint = true, spawnPoints[i]
			break
		end
	end

	if found then
		return true, foundSpawnPoint
	else
		ESX.ShowNotification(TranslateCap('garage_blocked'))
		return false
	end
end

function OpenShopMenu(elements, restoreCoords, shopCoords)
	local playerPed = PlayerPedId()
	isInShopMenu = true

	OpenAmbulanceMenu('default', 'vehicle_shop', TranslateCap('vehicleshop_title'), elements, function(data, menu)
		OpenAmbulanceMenu('default', 'vehicle_shop_confirm', data.current.name, {
			{label = 'View', value = 'view'}
		}, function(data2, menu2)
			if data2.current.value == 'view' then
				DeleteSpawnedVehicles()
				WaitForVehicleToLoad(data.current.model)

				xLib.game.spawnLocalVehicle(data.current.model, shopCoords.xyz, shopCoords.w, function(vehicle)
					table.insert(spawnedVehicles, vehicle)
					TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
					FreezeEntityPosition(vehicle, true)
					SetModelAsNoLongerNeeded(data.current.model)

					if data.current.props then
						xLib.game.setVehicleProperties(vehicle, data.current.props)
					end
				end)

				OpenAmbulanceMenu('default', 'vehicle_shop_buy', data.current.name, {
					{label = 'Buy', value = 'buy'},
					{label = 'Stop Viewing', value = 'stop'}
				}, function(data3, menu3)
					if data3.current.value == 'stop' then
						isInShopMenu = false
						menu3.close()

						DeleteSpawnedVehicles()
						FreezeEntityPosition(playerPed, false)
						SetEntityVisible(playerPed, true)

						xLib.entity.Teleport(playerPed, restoreCoords)
					elseif data3.current.value == 'buy' then
						local newPlate = exports['esx_vehicleshop']:GeneratePlate()
						local vehicle  = GetVehiclePedIsIn(playerPed, false)
						local props    = xLib.game.getVehicleProperties(vehicle)
						props.plate    = newPlate

						xLib.callback('esx_ambulancejob:buyJobVehicle', false, function (bought)
							if bought then
								ESX.ShowNotification(TranslateCap('vehicleshop_bought', data.current.name, ESX.Math.GroupDigits(data.current.price)))

								isInShopMenu = false
								menu3.close()
								menu2.close()
								menu.close()
								DeleteSpawnedVehicles()
								FreezeEntityPosition(playerPed, false)
								SetEntityVisible(playerPed, true)

								xLib.entity.Teleport(playerPed, restoreCoords)
							else
								ESX.ShowNotification(TranslateCap('vehicleshop_money'))
								menu3.close()
							end
						end, props, data.current.type)
					end
				end, function(data3, menu3)
					isInShopMenu = false
					menu3.close()

					DeleteSpawnedVehicles()
					FreezeEntityPosition(playerPed, false)
					SetEntityVisible(playerPed, true)

					xLib.entity.Teleport(playerPed, restoreCoords)
				end)
			end
		end, function(data2, menu2)
			menu2.close()
		end)
	end, function(data, menu)
		isInShopMenu = false
		menu.close()
	end)
end

CreateThread(function()
	while true do
		sleep = 1500

		if isInShopMenu then
			sleep = 0
			DisableControlAction(0, 75, true)  -- Disable exit vehicle
			DisableControlAction(27, 75, true) -- Disable exit vehicle
		end
		Wait(sleep)
	end
end)

function DeleteSpawnedVehicles()
	while #spawnedVehicles > 0 do
		local vehicle = spawnedVehicles[1]
		xLib.game.deleteVehicle(vehicle)
		table.remove(spawnedVehicles, 1)
	end
end

function WaitForVehicleToLoad(modelHash)
	xLib.streaming.requestModelWithSpinner(modelHash, TranslateCap('vehicleshop_awaiting_model'))
end
