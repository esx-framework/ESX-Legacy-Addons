-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local Mechanic = ESXMechanicJob
local State = Mechanic.State

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
	ESX.PlayerData = xPlayer
	ESX.PlayerLoaded = true
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	ESX.PlayerData.job = job
end)

RegisterNetEvent('esx_phone:loaded')
AddEventHandler('esx_phone:loaded', function()
	local specialContact = {
		name = TranslateCap('mechanic'),
		number = 'mechanic',
		base64Icon =
		'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAALEwAACxMBAJqcGAAAA4BJREFUWIXtll9oU3cUx7/nJA02aSSlFouWMnXVB0ejU3wcRteHjv1puoc9rA978cUi2IqgRYWIZkMwrahUGfgkFMEZUdg6C+u21z1o3fbgqigVi7NzUtNcmsac40Npltz7S3rvUHzxQODec87vfD+/e0/O/QFv7Q0beV3QeXqmgV74/7H7fZJvuLwv8q/Xeux1gUrNBpN/nmtavdaqDqBK8VT2RDyV2VHmF1lvLERSBtCVynzYmcp+A9WqT9kcVKX4gHUehF0CEVY+1jYTTIwvt7YSIQnCTvsSUYz6gX5uDt7MP7KOKuQAgxmqQ+neUA+I1B1AiXi5X6ZAvKrabirmVYFwAMRT2RMg7F9SyKspvk73hfrtbkMPyIhA5FVqi0iBiEZMMQdAui/8E4GPv0oAJkpc6Q3+6goAAGpWBxNQmTLFmgL3jSJNgQdGv4pMts2EKm7ICJB/aG0xNdz74VEk13UYCx1/twPR8JjDT8wttyLZtkoAxSb8ZDCz0gdfKxWkFURf2v9qTYH7SK7rQIDn0P3nA0ehixvfwZwE0X9vBE/mW8piohhl1WH18UQBhYnre8N/L8b8xQvlx4ACbB4NnzaeRYDnKm0EALCMLXy84hwuTCXL/ExoB1E7qcK/8NCLIq5HcTT0i6u8TYbXUM1cAyyveVq8Xls7XhYrvY/4n3gC8C+dsmAzL1YUiyfWxvHzsy/w/dNd+KjhW2yvv/RfXr7x9QDcmo1he2RBiCCI1Q8jVj9szPNixVfgz+UiIGyDSrcoRu2J16d3I6e1VYvNSQjXpnucAcEPUOkGYZs/l4uUhowt/3kqu1UIv9n90fAY9jT3YBlbRvFTD4fw++wHjhiTRL/bG75t0jI2ITcHb5om4Xgmhv57xpGOg3d/NIqryOR7z+r+MC6qBJB/ZB2t9Om1D5lFm843G/3E3HI7Yh1xDRAfzLQr5EClBf/HBHK462TG2J0OABXeyWDPZ8VqxmBWYscpyghwtTd4EKpDTjCZdCNmzFM9k+4LHXIFACJN94Z6FiFEpKDQw9HndWsEuhnADVMhAUaYJBp9XrcGQKJ4qFE9k+6r2+MG3k5N8VQ22TVglbX2ZwOzX2VvNKr91zmY6S7N6zqZicVT2WNLyVSehESaBhxnOALfMeYX+K/S2yv7wmMAlvwyuR7FxQUyf0fgc/jztfkJr7XeGgC8BJJgWNV8ImT+AAAAAElFTkSuQmCC'
	}

	TriggerEvent('esx_phone:addSpecialContact', specialContact.name, specialContact.number, specialContact.base64Icon)
end)

AddEventHandler('esx_mechanicjob:hasEnteredMarker', function(zone)
	if zone == 'VehicleDelivery' then
		State.npcTargetDeleterZone = true
		Mechanic.clearCurrentAction()
	elseif zone == 'MechanicActions' then
		Mechanic.setCurrentAction('mechanic_actions_menu', TranslateCap('open_actions'), {})
	elseif zone == 'Garage' then
		Mechanic.setCurrentAction('mechanic_harvest_menu', TranslateCap('harvest_menu'), {})
	elseif zone == 'Craft' then
		Mechanic.setCurrentAction('mechanic_craft_menu', TranslateCap('craft_menu'), {})
	elseif zone == 'VehicleDeleter' then
		local playerPed = PlayerPedId()

		if IsPedInAnyVehicle(playerPed, false) then
			Mechanic.setCurrentAction('delete_vehicle', TranslateCap('veh_stored'), {
				vehicle = GetVehiclePedIsIn(playerPed, false)
			})
		end
	end

	if zone ~= 'VehicleSpawnPoint' and zone ~= 'VehicleDelivery' then
		Mechanic.showCurrentAction()
	end
end)

AddEventHandler('esx_mechanicjob:hasExitedMarker', function(zone)
	if zone == 'VehicleDelivery' then
		State.npcTargetDeleterZone = false
	elseif zone == 'Craft' then
		TriggerServerEvent('esx_mechanicjob:stopCraft')
		TriggerServerEvent('esx_mechanicjob:stopCraft2')
		TriggerServerEvent('esx_mechanicjob:stopCraft3')
	elseif zone == 'Garage' then
		TriggerServerEvent('esx_mechanicjob:stopHarvest')
		TriggerServerEvent('esx_mechanicjob:stopHarvest2')
		TriggerServerEvent('esx_mechanicjob:stopHarvest3')
	end

	Mechanic.clearCurrentAction()
	Mechanic.closeInteractionUI()
end)

AddEventHandler('esx_mechanicjob:hasEnteredEntityZone', function(entity)
	if Mechanic.isMechanic() and not IsPedInAnyVehicle(PlayerPedId(), false) then
		Mechanic.setCurrentAction('remove_entity', TranslateCap('press_remove_obj'), { entity = entity })
		Mechanic.showCurrentAction()
	end
end)

AddEventHandler('esx_mechanicjob:hasExitedEntityZone', function()
	if State.currentAction == 'remove_entity' then
		Mechanic.clearCurrentAction()
	end

	ESX.HideUI()
end)

CreateThread(function()
	xLib.blips.create({
		coords = Config.Zones.MechanicActions.Pos,
		sprite = 446,
		display = 4,
		scale = 1.0,
		color = 5,
		shortRange = true,
		label = TranslateCap('mechanic')
	})
end)

CreateThread(function()
	while true do
		local sleep = 2000

		if Mechanic.isMechanic() then
			sleep = 500

			local coords = GetEntityCoords(PlayerPedId())

			for _, zone in pairs(Config.Zones) do
				if zone.Type ~= -1 and #(coords - zone.Pos) < Config.DrawDistance then
					sleep = 0
					DrawMarker(zone.Type, zone.Pos.x, zone.Pos.y, zone.Pos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
						zone.Size.x, zone.Size.y, zone.Size.z, zone.Color.r, zone.Color.g, zone.Color.b, 100,
						true, true, 2, true, nil, nil, false)
				end
			end
		end

		Wait(sleep)
	end
end)

CreateThread(function()
	while true do
		local sleep = 500

		if Mechanic.isMechanic() then
			local coords = GetEntityCoords(PlayerPedId())
			local isInMarker = false
			local currentZone = nil

			for zoneName, zone in pairs(Config.Zones) do
				if #(coords - zone.Pos) < zone.Size.x then
					sleep = 0
					isInMarker = true
					currentZone = zoneName
				end
			end

			if (isInMarker and not State.hasAlreadyEnteredMarker) or (isInMarker and State.lastZone ~= currentZone) then
				State.hasAlreadyEnteredMarker = true
				State.lastZone = currentZone
				TriggerEvent('esx_mechanicjob:hasEnteredMarker', currentZone)
			end

			if not isInMarker and State.hasAlreadyEnteredMarker then
				State.hasAlreadyEnteredMarker = false
				TriggerEvent('esx_mechanicjob:hasExitedMarker', State.lastZone)
			end
		end

		Wait(sleep)
	end
end)

CreateThread(function()
	while true do
		Wait(500)

		local playerPed = PlayerPedId()
		local coords = GetEntityCoords(playerPed)
		local closestDistance = -1
		local closestEntity = nil

		for i = 1, #Mechanic.TrackedObjects do
			local object = GetClosestObjectOfType(coords, 3.0, joaat(Mechanic.TrackedObjects[i]), false, false, false)

			if DoesEntityExist(object) then
				local distance = #(coords - GetEntityCoords(object))

				if closestDistance == -1 or closestDistance > distance then
					closestDistance = distance
					closestEntity = object
				end
			end
		end

		if closestDistance ~= -1 and closestDistance <= 3.0 then
			if State.lastEntity ~= closestEntity then
				TriggerEvent('esx_mechanicjob:hasEnteredEntityZone', closestEntity)
				State.lastEntity = closestEntity
			end
		elseif State.lastEntity then
			TriggerEvent('esx_mechanicjob:hasExitedEntityZone', State.lastEntity)
			State.lastEntity = nil
		end
	end
end)

CreateThread(function()
	while true do
		local sleep = 500

		if State.currentAction then
			sleep = 0

			if IsControlJustReleased(0, 38) and Mechanic.isMechanic() and not State.isDead then
				if State.currentAction == 'mechanic_actions_menu' then
					Mechanic.openActionsMenu()
				elseif State.currentAction == 'mechanic_harvest_menu' then
					Mechanic.openHarvestMenu()
				elseif State.currentAction == 'mechanic_craft_menu' then
					Mechanic.openCraftMenu()
				elseif State.currentAction == 'delete_vehicle' then
					local vehicle = State.currentActionData.vehicle

					if Config.EnableSocietyOwnedVehicles then
						local vehicleProps = xLib.game.getVehicleProperties(vehicle)
						TriggerServerEvent('esx_society:putVehicleInGarage', 'mechanic', vehicleProps)
					else
						local entityModel = GetEntityModel(vehicle)

						if entityModel == `flatbed` or entityModel == `towtruck2` or entityModel == `slamvan3` then
							xLib.callback('esx_service:disableService', false, function() end, 'mechanic')
						end
					end

					Mechanic.deleteVehicle(vehicle)
				elseif State.currentAction == 'remove_entity' then
					DeleteEntity(State.currentActionData.entity)
				end

				Mechanic.clearCurrentAction()
			end
		end

		Wait(sleep)
	end
end)
