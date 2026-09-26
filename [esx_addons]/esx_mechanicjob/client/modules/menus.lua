-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local Mechanic = ESXMechanicJob
local State = Mechanic.State
local MenuNamespace = GetCurrentResourceName()

local function openMenu(name, title, elements, submit, cancel)
	return ESX.UI.Menu.Open('default', MenuNamespace, name, {
		title = title,
		align = 'top-left',
		elements = elements
	}, submit, cancel or function(data, menu)
		menu.close()
	end)
end

local function openAmountMenu(name, title, maxAmount, callback)
	ESX.UI.Menu.Open('dialog', MenuNamespace, name, { title = title }, function(data, menu)
		local amount = tonumber(data.value)

		if not amount or amount < 1 or amount > maxAmount then
			ESX.ShowNotification(TranslateCap('invalid_quantity'))
			return
		end

		menu.close()
		callback(amount)
	end, function(data, menu)
		menu.close()
	end)
end

local function spawnServiceVehicle(model, heading, vehicleProps)
	xLib.game.spawnVehicle(model, Config.Zones.VehicleSpawnPoint.Pos, heading or 90.0, function(vehicle)
		if vehicleProps then
			xLib.game.setVehicleProperties(vehicle, vehicleProps)
		end

		TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
	end)
end

local function openSocietyVehicleMenu()
	local elements = {
	}

	xLib.callback('esx_society:getVehiclesInGarage', false, function(vehicles)
		for i = 1, #vehicles do
			elements[#elements + 1] = {
				icon = 'fas fa-car',
				label = GetDisplayNameFromVehicleModel(vehicles[i].model) .. ' [' .. vehicles[i].plate .. ']',
				value = vehicles[i]
			}
		end

		openMenu('society_vehicles', TranslateCap('service_vehicle'), elements, function(data, menu)
			if not data.current.value then
				return
			end

			menu.close()
			spawnServiceVehicle(data.current.value.model, 270.0, data.current.value)
			TriggerServerEvent('esx_society:removeVehicleFromGarage', 'mechanic', data.current.value)
		end)
	end, 'mechanic')
end

local function openStaticVehicleMenu()
	local elements = {
		{ icon = "fas fa-truck", label = TranslateCap('flat_bed'),  value = 'flatbed' },
		{ icon = "fas fa-truck", label = TranslateCap('tow_truck'), value = 'towtruck2' }
	}

	if Config.EnablePlayerManagement and ESX.PlayerData.job
		and (ESX.PlayerData.job.grade_name == 'boss'
			or ESX.PlayerData.job.grade_name == 'chief'
			or ESX.PlayerData.job.grade_name == 'experimente') then
		elements[#elements + 1] = {
			icon = 'fas fa-truck',
			label = 'Slamvan',
			value = 'slamvan3'
		}
	end

	openMenu('static_vehicles', TranslateCap('service_vehicle'), elements, function(data, menu)
		if not data.current.value then
			return
		end

		if Config.MaxInService == -1 then
			menu.close()
			spawnServiceVehicle(data.current.value, 90.0)
			return
		end

		xLib.callback('esx_service:enableService', false, function(canTakeService, maxInService, inServiceCount)
			if canTakeService then
				menu.close()
				spawnServiceVehicle(data.current.value, 90.0)
			else
				ESX.ShowNotification(TranslateCap('service_full') .. inServiceCount .. '/' .. maxInService)
			end
		end, 'mechanic')
	end)
end

local function hasUniform(uniform)
	return type(uniform) == 'table' and next(uniform) ~= nil
end

local function getWorkWear(skin, jobSkin)
	if type(skin) ~= 'table' or type(jobSkin) ~= 'table' then
		return nil
	end

	local jobUniform = skin.sex == 0 and jobSkin.skin_male or jobSkin.skin_female

	if hasUniform(jobUniform) then
		return jobUniform
	end

	return nil
end

function Mechanic.openActionsMenu()
	local elements = {
		{ icon = "fas fa-car",   label = TranslateCap('vehicle_list'),   value = 'vehicle_list' },
		{ icon = "fas fa-shirt", label = TranslateCap('work_wear'),      value = 'cloakroom' },
		{ icon = "fas fa-shirt", label = TranslateCap('civ_wear'),       value = 'cloakroom2' },
		{ icon = "fas fa-box",   label = TranslateCap('deposit_stock'),  value = 'put_stock' },
		{ icon = "fas fa-box",   label = TranslateCap('withdraw_stock'), value = 'get_stock' }
	}

	if Config.EnablePlayerManagement and ESX.PlayerData.job and ESX.PlayerData.job.grade_name == 'boss' then
		elements[#elements + 1] = {
			icon = 'fas fa-boss',
			label = TranslateCap('boss_actions'),
			value = 'boss_actions'
		}
	end

	openMenu('mechanic_actions', TranslateCap('mechanic'), elements, function(data, menu)
		if data.current.value == 'vehicle_list' then
			menu.close()
			if Config.EnableSocietyOwnedVehicles then
				openSocietyVehicleMenu()
			else
				openStaticVehicleMenu()
			end
		elseif data.current.value == 'cloakroom' then
			menu.close()
			xLib.callback('esx_skin:getPlayerSkin', false, function(skin, jobSkin)
				local uniform = getWorkWear(skin, jobSkin)

				if not uniform then
					ESX.ShowNotification(TranslateCap('no_outfit'), "error")
					return
				end

				TriggerEvent('skinchanger:loadClothes', skin, uniform)
			end)
		elseif data.current.value == 'cloakroom2' then
			menu.close()
			xLib.callback('esx_skin:getPlayerSkin', false, function(skin)
				TriggerEvent('skinchanger:loadSkin', skin)
			end)
		elseif Config.OxInventory and (data.current.value == 'put_stock' or data.current.value == 'get_stock') then
			exports.ox_inventory:openInventory('stash', 'society_mechanic')
			menu.close()
		elseif data.current.value == 'put_stock' then
			menu.close()
			Mechanic.openPutStocksMenu()
		elseif data.current.value == 'get_stock' then
			menu.close()
			Mechanic.openGetStocksMenu()
		elseif data.current.value == 'boss_actions' then
			TriggerEvent('esx_society:openBossMenu', 'mechanic', function()
				menu.close()
			end, { uniforms = true })
		end
	end, function(data, menu)
		menu.close()
		Mechanic.setCurrentAction('mechanic_actions_menu', TranslateCap('open_actions'), {})
	end)
end

function Mechanic.openHarvestMenu()
	if not ESX.PlayerData.job or (Config.EnablePlayerManagement and ESX.PlayerData.job.grade_name == 'recrue') then
		ESX.ShowNotification(TranslateCap('not_experienced_enough'))
		return
	end

	local elements = {
		{ icon = "fas fa-gear", label = TranslateCap('gas_can'),         value = 'gaz_bottle' },
		{ icon = "fas fa-gear", label = TranslateCap('repair_tools'),    value = 'fix_tool' },
		{ icon = "fas fa-gear", label = TranslateCap('body_work_tools'), value = 'caro_tool' }
	}

	openMenu('mechanic_harvest', 'Mechanic Harvest Menu', elements, function(data, menu)
		if data.current.value == 'gaz_bottle' then
			TriggerServerEvent('esx_mechanicjob:startHarvest')
		elseif data.current.value == 'fix_tool' then
			TriggerServerEvent('esx_mechanicjob:startHarvest2')
		elseif data.current.value == 'caro_tool' then
			TriggerServerEvent('esx_mechanicjob:startHarvest3')
		end
	end, function(data, menu)
		menu.close()
		Mechanic.setCurrentAction('mechanic_harvest_menu', TranslateCap('harvest_menu'), {})
	end)
end

function Mechanic.openCraftMenu()
	if not ESX.PlayerData.job or (Config.EnablePlayerManagement and ESX.PlayerData.job.grade_name == 'recrue') then
		ESX.ShowNotification(TranslateCap('not_experienced_enough'))
		return
	end

	local elements = {
		{ icon = "fas fa-gear", label = TranslateCap('blowtorch'),  value = 'blow_pipe' },
		{ icon = "fas fa-gear", label = TranslateCap('repair_kit'), value = 'fix_kit' },
		{ icon = "fas fa-gear", label = TranslateCap('body_kit'),   value = 'caro_kit' }
	}

	openMenu('mechanic_craft', 'Mechanic Craft Menu', elements, function(data, menu)
		if data.current.value == 'blow_pipe' then
			TriggerServerEvent('esx_mechanicjob:startCraft')
		elseif data.current.value == 'fix_kit' then
			TriggerServerEvent('esx_mechanicjob:startCraft2')
		elseif data.current.value == 'caro_kit' then
			TriggerServerEvent('esx_mechanicjob:startCraft3')
		end
	end, function(data, menu)
		menu.close()
		Mechanic.setCurrentAction('mechanic_craft_menu', TranslateCap('craft_menu'), {})
	end)
end

function Mechanic.openGetStocksMenu()
	xLib.callback('esx_mechanicjob:getStockItems', false, function(items)
		local elements = {
		}

		for i = 1, #(items or {}) do
			elements[#elements + 1] = {
				icon = 'fas fa-box',
				label = 'x' .. items[i].count .. ' ' .. items[i].label,
				value = items[i].name
			}
		end

		openMenu('mechanic_get_stock', TranslateCap('mechanic_stock'), elements, function(data, menu)
			if not data.current.value then
				return
			end

			menu.close()
			openAmountMenu('mechanic_get_amount', data.current.label, 100, function(count)
				TriggerServerEvent('esx_mechanicjob:getStockItem', data.current.value, count)

				Wait(1000)
				Mechanic.openGetStocksMenu()
			end)
		end)
	end)
end

function Mechanic.openPutStocksMenu()
	xLib.callback('esx_mechanicjob:getPlayerInventory', false, function(inventory)
		local items = (inventory and inventory.items) or {}
		local elements = {
		}

		for i = 1, #items do
			local item = items[i]

			if item.count > 0 then
				elements[#elements + 1] = {
					icon = 'fas fa-box',
					label = item.label .. ' x' .. item.count,
					type = 'item_standard',
					value = item.name
				}
			end
		end

		openMenu('mechanic_put_stock', TranslateCap('inventory'), elements, function(data, menu)
			if not data.current.value then
				return
			end

			menu.close()
			openAmountMenu('mechanic_put_amount', data.current.label, 100, function(count)
				TriggerServerEvent('esx_mechanicjob:putStockItems', data.current.value, count)

				Wait(1000)
				Mechanic.openPutStocksMenu()
			end)
		end)
	end)
end

local function openBillingMenu(title)
	local closestPlayer, closestDistance = xLib.game.getClosestPlayer()
	if closestPlayer == -1 or closestDistance > 3.0 then
		ESX.ShowNotification(TranslateCap('no_players_nearby'), "error")
		return
	end

	ESX.UI.Menu.Open('dialog', MenuNamespace, 'mechanic_billing_amount', { title = title }, function(data, menu)
		local amount = tonumber(data.value)

		if not amount or amount < 0 or amount > 250000 then
			ESX.ShowNotification(TranslateCap('amount_invalid'), "error")
			return
		end

		local closestPlayer, closestDistance = xLib.game.getClosestPlayer()
		if closestPlayer == -1 or closestDistance > 3.0 then
			ESX.ShowNotification(TranslateCap('no_players_nearby'), "error")
			return
		end

		menu.close()
		TriggerServerEvent('esx_billing:sendBill', GetPlayerServerId(closestPlayer), 'society_mechanic',
			TranslateCap('mechanic'), amount)
	end, function(data, menu)
		menu.close()
	end)
end

local function ensureOutsideVehicle(playerPed)
	if IsPedSittingInAnyVehicle(playerPed) then
		ESX.ShowNotification(TranslateCap('inside_vehicle'))
		return false
	end

	return true
end

local function runVehicleScenario(vehicle, scenario, duration, successKey, action)
	local playerPed = PlayerPedId()

	State.isBusy = true
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

local function handleHijackVehicle()
	local playerPed = PlayerPedId()
	if not ensureOutsideVehicle(playerPed) then
		return
	end

	local vehicle = Mechanic.getVehicleInDirection()
	if not vehicle then
		ESX.ShowNotification(TranslateCap('no_vehicle_nearby'))
		return
	end

	runVehicleScenario(vehicle, 'WORLD_HUMAN_WELDING', 10000, 'vehicle_unlocked', function(targetVehicle)
		SetVehicleDoorsLocked(targetVehicle, 1)
		SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)
	end)
end

local function handleRepairVehicle()
	local playerPed = PlayerPedId()
	if not ensureOutsideVehicle(playerPed) then
		return
	end

	local vehicle = Mechanic.getVehicleInDirection()
	if not vehicle then
		ESX.ShowNotification(TranslateCap('no_vehicle_nearby'))
		return
	end

	runVehicleScenario(vehicle, 'PROP_HUMAN_BUM_BIN', 20000, 'vehicle_repaired', function(targetVehicle)
		SetVehicleFixed(targetVehicle)
		SetVehicleDeformationFixed(targetVehicle)
		SetVehicleUndriveable(targetVehicle, false)
		SetVehicleEngineOn(targetVehicle, true, true, false)
	end)
end

local function handleCleanVehicle()
	local playerPed = PlayerPedId()
	if not ensureOutsideVehicle(playerPed) then
		return
	end

	local vehicle = Mechanic.getVehicleInDirection()
	if not vehicle then
		ESX.ShowNotification(TranslateCap('no_vehicle_nearby'))
		return
	end

	runVehicleScenario(vehicle, 'WORLD_HUMAN_MAID_CLEAN', 10000, 'vehicle_cleaned', function(targetVehicle)
		SetVehicleDirtLevel(targetVehicle, 0)
	end)
end

local function impoundVehicle(vehicle)
	ESX.ShowNotification(TranslateCap('vehicle_impounded'))
	Mechanic.markVehicleImpounded(vehicle)
	Mechanic.deleteVehicle(vehicle)
end

local function handleImpoundVehicle()
	local playerPed = PlayerPedId()

	if IsPedSittingInAnyVehicle(playerPed) then
		local vehicle = GetVehiclePedIsIn(playerPed, false)

		if GetPedInVehicleSeat(vehicle, -1) == playerPed then
			impoundVehicle(vehicle)
		else
			ESX.ShowNotification(TranslateCap('must_seat_driver'))
		end

		return
	end

	local vehicle = Mechanic.getVehicleInDirection()
	if vehicle then
		impoundVehicle(vehicle)
	else
		ESX.ShowNotification(TranslateCap('must_near'))
	end
end

local function handleTowVehicle()
	local playerPed = PlayerPedId()
	local flatbedVehicle = Mechanic.getNearbyFlatbed(playerPed)

	if not Mechanic.vehicleExists(flatbedVehicle) or not IsVehicleModel(flatbedVehicle, `flatbed`) then
		ESX.ShowNotification(TranslateCap('imp_flatbed'))
		return
	end

	if IsPedInAnyVehicle(playerPed, false) then
		ESX.ShowNotification(TranslateCap('inside_vehicle'))
		return
	end

	if not State.currentlyTowedVehicle then
		local targetVehicle = Mechanic.getVehicleInDirection()

		if not targetVehicle then
			ESX.ShowNotification(TranslateCap('no_veh_att'))
			return
		end

		if targetVehicle == flatbedVehicle then
			ESX.ShowNotification(TranslateCap('cant_attach_own_tt'))
			return
		end

		if not Mechanic.attachVehicleToFlatbed(targetVehicle, flatbedVehicle) then
			ESX.ShowNotification(TranslateCap('no_veh_att'))
			return
		end

		State.currentlyTowedVehicle = targetVehicle
		ESX.ShowNotification(TranslateCap('vehicle_success_attached'))

		if Mechanic.isNPCTargetVehicle(targetVehicle) then
			State.npcTargetTowableNetId = State.npcTargetTowableNetId or Mechanic.getVehicleNetId(targetVehicle)
			Mechanic.activateNPCDeliveryRoute()
		end

		return
	end

	if State.npcJobCompletionPending then
		return
	end

	if not Mechanic.vehicleExists(State.currentlyTowedVehicle) then
		State.currentlyTowedVehicle = nil
		ESX.ShowNotification(TranslateCap('no_veh_att'))
		return
	end

	if Mechanic.isNPCTargetVehicle(State.currentlyTowedVehicle) then
		if not State.npcTargetDeleterZone then
			ESX.ShowNotification(TranslateCap('not_right_place'))
			return
		end

		State.npcTargetTowableNetId = State.npcTargetTowableNetId or Mechanic.getVehicleNetId(State.currentlyTowedVehicle)
		local flatbedNetId = Mechanic.getVehicleNetId(flatbedVehicle)

		if not State.npcTargetTowableNetId or not flatbedNetId then
			ESX.ShowNotification(TranslateCap('not_right_veh'))
			return
		end

		State.npcJobCompletionPending = true
		TriggerServerEvent('esx_mechanicjob:onNPCJobMissionCompleted', State.npcTargetTowableNetId, flatbedNetId)
		return
	end

	if not Mechanic.detachVehicleFromFlatbed(State.currentlyTowedVehicle, flatbedVehicle) then
		ESX.ShowNotification(TranslateCap('no_veh_att'))
		return
	end

	if State.npcOnJob then
		ESX.ShowNotification(TranslateCap('not_right_veh'))
	end

	State.currentlyTowedVehicle = nil
	ESX.ShowNotification(TranslateCap('veh_det_succ'))
end

local function openObjectSpawnerMenu()
	local playerPed = PlayerPedId()

	if IsPedSittingInAnyVehicle(playerPed) then
		ESX.ShowNotification(TranslateCap('inside_vehicle'))
		return
	end

	local elements = {
		{ icon = "fas fa-object", label = TranslateCap('roadcone'), value = 'prop_roadcone02a' },
		{ icon = "fas fa-object", label = TranslateCap('toolbox'),  value = 'prop_toolchest_01' }
	}

	openMenu('mechanic_objects', TranslateCap('objects'), elements, function(data, menu)
		if data.current.value then
			menu.close()
			Mechanic.spawnObject(data.current.value)
		end
	end)
end

function Mechanic.openMobileActionsMenu()
	local elements = {
		{ icon = "fas fa-gear", label = TranslateCap('billing'), value = 'billing' },
		{ icon = "fas fa-gear", label = TranslateCap('hijack'), value = 'hijack_vehicle' },
		{ icon = "fas fa-gear", label = TranslateCap('repair'), value = 'fix_vehicle' },
		{ icon = "fas fa-gear", label = TranslateCap('clean'), value = 'clean_vehicle' },
		{ icon = "fas fa-gear", label = TranslateCap('imp_veh'), value = 'del_vehicle' },
		{ icon = "fas fa-gear", label = TranslateCap('flat_bed'), value = 'dep_vehicle' },
		{ icon = "fas fa-gear", label = TranslateCap('place_objects'), value = 'object_spawner' }
	}

	openMenu('mechanic_mobile_actions', TranslateCap('mechanic'), elements, function(data, menu)
		if State.isBusy then
			return
		end

		if data.current.value == 'billing' then
			menu.close()
			openBillingMenu(data.current.label)
		elseif data.current.value == 'hijack_vehicle' then
			menu.close()
			handleHijackVehicle()
		elseif data.current.value == 'fix_vehicle' then
			menu.close()
			handleRepairVehicle()
		elseif data.current.value == 'clean_vehicle' then
			menu.close()
			handleCleanVehicle()
		elseif data.current.value == 'del_vehicle' then
			menu.close()
			handleImpoundVehicle()
		elseif data.current.value == 'dep_vehicle' then
			menu.close()
			handleTowVehicle()
		elseif data.current.value == 'object_spawner' then
			menu.close()
			openObjectSpawnerMenu()
		end
	end)
end
