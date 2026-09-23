-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local Mechanic = ESXMechanicJob
local State = Mechanic.State

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
		{ unselectable = true, icon = "fas fa-car", title = TranslateCap('service_vehicle') }
	}

	xLib.callback('esx_society:getVehiclesInGarage', false, function(vehicles)
		for i = 1, #vehicles do
			elements[#elements + 1] = {
				icon = 'fas fa-car',
				title = GetDisplayNameFromVehicleModel(vehicles[i].model) .. ' [' .. vehicles[i].plate .. ']',
				value = vehicles[i]
			}
		end

		ESX.OpenContext("right", elements, function(menu, element)
			if not element.value then
				return
			end

			ESX.CloseContext()
			spawnServiceVehicle(element.value.model, 270.0, element.value)
			TriggerServerEvent('esx_society:removeVehicleFromGarage', 'mechanic', element.value)
		end)
	end, 'mechanic')
end

local function openStaticVehicleMenu()
	local elements = {
		{ unselectable = true,   icon = "fas fa-car",   title = TranslateCap('service_vehicle') },
		{ icon = "fas fa-truck", title = TranslateCap('flat_bed'),  value = 'flatbed' },
		{ icon = "fas fa-truck", title = TranslateCap('tow_truck'), value = 'towtruck2' }
	}

	if Config.EnablePlayerManagement and ESX.PlayerData.job
		and (ESX.PlayerData.job.grade_name == 'boss'
			or ESX.PlayerData.job.grade_name == 'chief'
			or ESX.PlayerData.job.grade_name == 'experimente') then
		elements[#elements + 1] = {
			icon = 'fas fa-truck',
			title = 'Slamvan',
			value = 'slamvan3'
		}
	end

	ESX.OpenContext("right", elements, function(menu, element)
		if not element.value then
			return
		end

		if Config.MaxInService == -1 then
			ESX.CloseContext()
			spawnServiceVehicle(element.value, 90.0)
			return
		end

		xLib.callback('esx_service:enableService', false, function(canTakeService, maxInService, inServiceCount)
			if canTakeService then
				ESX.CloseContext()
				spawnServiceVehicle(element.value, 90.0)
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
		{ unselectable = true,   icon = "fas fa-gear",  title = TranslateCap('mechanic') },
		{ icon = "fas fa-car",   title = TranslateCap('vehicle_list'),   value = 'vehicle_list' },
		{ icon = "fas fa-shirt", title = TranslateCap('work_wear'),      value = 'cloakroom' },
		{ icon = "fas fa-shirt", title = TranslateCap('civ_wear'),       value = 'cloakroom2' },
		{ icon = "fas fa-box",   title = TranslateCap('deposit_stock'),  value = 'put_stock' },
		{ icon = "fas fa-box",   title = TranslateCap('withdraw_stock'), value = 'get_stock' }
	}

	if Config.EnablePlayerManagement and ESX.PlayerData.job and ESX.PlayerData.job.grade_name == 'boss' then
		elements[#elements + 1] = {
			icon = 'fas fa-boss',
			title = TranslateCap('boss_actions'),
			value = 'boss_actions'
		}
	end

	ESX.OpenContext("right", elements, function(menu, element)
		if element.value == 'vehicle_list' then
			if Config.EnableSocietyOwnedVehicles then
				openSocietyVehicleMenu()
			else
				openStaticVehicleMenu()
			end
		elseif element.value == 'cloakroom' then
			ESX.CloseContext()
			xLib.callback('esx_skin:getPlayerSkin', false, function(skin, jobSkin)
				local uniform = getWorkWear(skin, jobSkin)

				if not uniform then
					ESX.ShowNotification(TranslateCap('no_outfit'), "error")
					return
				end

				TriggerEvent('skinchanger:loadClothes', skin, uniform)
			end)
		elseif element.value == 'cloakroom2' then
			ESX.CloseContext()
			xLib.callback('esx_skin:getPlayerSkin', false, function(skin)
				TriggerEvent('skinchanger:loadSkin', skin)
			end)
		elseif Config.OxInventory and (element.value == 'put_stock' or element.value == 'get_stock') then
			exports.ox_inventory:openInventory('stash', 'society_mechanic')
			ESX.CloseContext()
		elseif element.value == 'put_stock' then
			Mechanic.openPutStocksMenu()
		elseif element.value == 'get_stock' then
			Mechanic.openGetStocksMenu()
		elseif element.value == 'boss_actions' then
			TriggerEvent('esx_society:openBossMenu', 'mechanic', function()
				ESX.CloseContext()
			end, { uniforms = true })
		end
	end, function()
		Mechanic.setCurrentAction('mechanic_actions_menu', TranslateCap('open_actions'), {})
	end)
end

function Mechanic.openHarvestMenu()
	if not ESX.PlayerData.job or (Config.EnablePlayerManagement and ESX.PlayerData.job.grade_name == 'recrue') then
		ESX.ShowNotification(TranslateCap('not_experienced_enough'))
		return
	end

	local elements = {
		{ unselectable = true,  icon = "fas fa-gear", title = "Mechanic Harvest Menu" },
		{ icon = "fas fa-gear", title = TranslateCap('gas_can'),         value = 'gaz_bottle' },
		{ icon = "fas fa-gear", title = TranslateCap('repair_tools'),    value = 'fix_tool' },
		{ icon = "fas fa-gear", title = TranslateCap('body_work_tools'), value = 'caro_tool' }
	}

	ESX.OpenContext("right", elements, function(menu, element)
		if element.value == 'gaz_bottle' then
			TriggerServerEvent('esx_mechanicjob:startHarvest')
		elseif element.value == 'fix_tool' then
			TriggerServerEvent('esx_mechanicjob:startHarvest2')
		elseif element.value == 'caro_tool' then
			TriggerServerEvent('esx_mechanicjob:startHarvest3')
		end
	end, function()
		Mechanic.setCurrentAction('mechanic_harvest_menu', TranslateCap('harvest_menu'), {})
	end)
end

function Mechanic.openCraftMenu()
	if not ESX.PlayerData.job or (Config.EnablePlayerManagement and ESX.PlayerData.job.grade_name == 'recrue') then
		ESX.ShowNotification(TranslateCap('not_experienced_enough'))
		return
	end

	local elements = {
		{ unselectable = true,  icon = "fas fa-gear", title = "Mechanic Craft Menu" },
		{ icon = "fas fa-gear", title = TranslateCap('blowtorch'),  value = 'blow_pipe' },
		{ icon = "fas fa-gear", title = TranslateCap('repair_kit'), value = 'fix_kit' },
		{ icon = "fas fa-gear", title = TranslateCap('body_kit'),   value = 'caro_kit' }
	}

	ESX.OpenContext("right", elements, function(menu, element)
		if element.value == 'blow_pipe' then
			TriggerServerEvent('esx_mechanicjob:startCraft')
		elseif element.value == 'fix_kit' then
			TriggerServerEvent('esx_mechanicjob:startCraft2')
		elseif element.value == 'caro_kit' then
			TriggerServerEvent('esx_mechanicjob:startCraft3')
		end
	end, function()
		Mechanic.setCurrentAction('mechanic_craft_menu', TranslateCap('craft_menu'), {})
	end)
end

function Mechanic.openGetStocksMenu()
	xLib.callback('esx_mechanicjob:getStockItems', false, function(items)
		local elements = {
			{ unselectable = true, icon = "fas fa-box", title = TranslateCap('mechanic_stock') }
		}

		for i = 1, #(items or {}) do
			elements[#elements + 1] = {
				icon = 'fas fa-box',
				title = 'x' .. items[i].count .. ' ' .. items[i].label,
				value = items[i].name
			}
		end

		ESX.OpenContext("right", elements, function(menu, element)
			if not element.value then
				return
			end

			local elements2 = {
				{ unselectable = true,          icon = "fas fa-box", title = element.title },
				{ title = "Amount",             input = true,        inputType = "number", inputMin = 1, inputMax = 100, inputPlaceholder = "Amount to withdraw.." },
				{ icon = "fas fa-check-double", title = "Confirm",   value = "confirm" }
			}

			ESX.OpenContext("right", elements2, function(menu2)
				local count = tonumber(menu2.eles[2].inputValue)

				if not count then
					ESX.ShowNotification(TranslateCap('invalid_quantity'))
					return
				end

				ESX.CloseContext()
				TriggerServerEvent('esx_mechanicjob:getStockItem', element.value, count)

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
			{ unselectable = true, icon = "fas fa-box", title = TranslateCap('inventory') }
		}

		for i = 1, #items do
			local item = items[i]

			if item.count > 0 then
				elements[#elements + 1] = {
					icon = 'fas fa-box',
					title = item.label .. ' x' .. item.count,
					type = 'item_standard',
					value = item.name
				}
			end
		end

		ESX.OpenContext("right", elements, function(menu, element)
			if not element.value then
				return
			end

			local elements2 = {
				{ unselectable = true,          icon = "fas fa-box", title = element.title },
				{ title = "Amount",             input = true,        inputType = "number", inputMin = 1, inputMax = 100, inputPlaceholder = "Amount to deposit.." },
				{ icon = "fas fa-check-double", title = "Confirm",   value = "confirm" }
			}

			ESX.OpenContext("right", elements2, function(menu2)
				local count = tonumber(menu2.eles[2].inputValue)

				if not count then
					ESX.ShowNotification(TranslateCap('invalid_quantity'))
					return
				end

				ESX.CloseContext()
				TriggerServerEvent('esx_mechanicjob:putStockItems', element.value, count)

				Wait(1000)
				Mechanic.openPutStocksMenu()
			end)
		end)
	end)
end

local function openBillingMenu(title)
	local elements = {
		{ unselectable = true,          icon = "fas fa-scroll", title = title },
		{ title = "Amount",             input = true,           inputType = "number", inputMin = 1, inputMax = 250000, inputPlaceholder = "Amount to bill.." },
		{ icon = "fas fa-check-double", title = "Confirm",      value = "confirm" }
	}

	ESX.OpenContext("right", elements, function(menu)
		local amount = tonumber(menu.eles[2].inputValue)

		if not amount or amount < 0 then
			ESX.ShowNotification(TranslateCap('amount_invalid'), "error")
			return
		end

		local closestPlayer, closestDistance = xLib.game.getClosestPlayer()
		if closestPlayer == -1 or closestDistance > 3.0 then
			ESX.ShowNotification(TranslateCap('no_players_nearby'), "error")
			return
		end

		ESX.CloseContext()
		TriggerServerEvent('esx_billing:sendBill', GetPlayerServerId(closestPlayer), 'society_mechanic',
			TranslateCap('mechanic'), amount)
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
		SetVehicleEngineOn(targetVehicle, true, true)
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
		{ unselectable = true,    icon = "fas fa-object", title = TranslateCap('objects') },
		{ icon = "fas fa-object", title = TranslateCap('roadcone'), value = 'prop_roadcone02a' },
		{ icon = "fas fa-object", title = TranslateCap('toolbox'),  value = 'prop_toolchest_01' }
	}

	ESX.OpenContext("right", elements, function(menu, element)
		if element.value then
			Mechanic.spawnObject(element.value)
		end
	end)
end

function Mechanic.openMobileActionsMenu()
	local elements = {
		{ unselectable = true,  icon = "fas fa-gear", title = TranslateCap('mechanic') },
		{ icon = "fas fa-gear", title = TranslateCap('billing'), value = 'billing' },
		{ icon = "fas fa-gear", title = TranslateCap('hijack'), value = 'hijack_vehicle' },
		{ icon = "fas fa-gear", title = TranslateCap('repair'), value = 'fix_vehicle' },
		{ icon = "fas fa-gear", title = TranslateCap('clean'), value = 'clean_vehicle' },
		{ icon = "fas fa-gear", title = TranslateCap('imp_veh'), value = 'del_vehicle' },
		{ icon = "fas fa-gear", title = TranslateCap('flat_bed'), value = 'dep_vehicle' },
		{ icon = "fas fa-gear", title = TranslateCap('place_objects'), value = 'object_spawner' }
	}

	ESX.OpenContext("right", elements, function(menu, element)
		if State.isBusy then
			return
		end

		if element.value == 'billing' then
			openBillingMenu(element.title)
		elseif element.value == 'hijack_vehicle' then
			handleHijackVehicle()
		elseif element.value == 'fix_vehicle' then
			handleRepairVehicle()
		elseif element.value == 'clean_vehicle' then
			handleCleanVehicle()
		elseif element.value == 'del_vehicle' then
			handleImpoundVehicle()
		elseif element.value == 'dep_vehicle' then
			handleTowVehicle()
		elseif element.value == 'object_spawner' then
			openObjectSpawnerMenu()
		end
	end)
end
