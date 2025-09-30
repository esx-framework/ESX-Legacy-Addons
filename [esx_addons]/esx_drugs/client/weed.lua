local spawnedWeeds = 0
local weedPlants = {}
local isPickingUp, isProcessing = false, false
local displayed_process_prompt = false
local displayed_pickup_prompt = false

CreateThread(function()
	local sleep = 700
	while true do
		local coords = GetEntityCoords(PlayerPedId())

		if #(coords - Config.CircleZones.WeedField.coords) < 50 then
			SpawnWeedPlants()
		end

		Wait(sleep)
	end
end)

CreateThread(function()
	local sleep
	while true do
		local playerPed = PlayerPedId()
		local coords = GetEntityCoords(playerPed)

		if #(coords - Config.CircleZones.WeedProcessing.coords) < 1 then
			sleep = 0
		
			if not isProcessing and not displayed_process_prompt then
				ESX.TextUI(TranslateCap('weed_processprompt'))
				displayed_process_prompt = true
			end

			if IsControlJustReleased(0, 38) and not isProcessing then
				ESX.TriggerServerCallback('esx_drugs:cannabis_count', function(xCannabis)
					if Config.LicenseEnable then
						ESX.TriggerServerCallback('esx_license:checkLicense', function(hasProcessingLicense)
							if hasProcessingLicense then
								ProcessWeed(xCannabis)
							else
								OpenBuyLicenseMenu('weed_processing')
							end
						end, GetPlayerServerId(PlayerId()), 'weed_processing')
					else
						ProcessWeed(xCannabis)
					end
				end)
			end
		else
			sleep = 1500
			if displayed_process_prompt then
				displayed_process_prompt = false
				ESX.HideUI()
			end
		end

		Wait(sleep)
	end
end)


function ProcessWeed(xCannabis)
	isProcessing = true
	ESX.ShowNotification(TranslateCap('weed_processingstarted'))
  	TriggerServerEvent('esx_drugs:processCannabis')
	if(xCannabis <= 3) then
		xCannabis = 0
	end
  local timeLeft = (Config.Delays.WeedProcessing * xCannabis) / 1000
	local playerPed = PlayerPedId()

	while timeLeft > 0 do
		Wait(1000)
		timeLeft = timeLeft - 1

		if #(GetEntityCoords(playerPed) - Config.CircleZones.WeedProcessing.coords) > 4 then
			ESX.ShowNotification(TranslateCap('weed_processingtoofar'))
			TriggerServerEvent('esx_drugs:cancelProcessing')
			TriggerServerEvent('esx_drugs:outofbound')
			break
		end
	end

	isProcessing = false
end

CreateThread(function()
	local sleep
	while true do

		local playerPed = PlayerPedId()
		local coords = GetEntityCoords(playerPed)
		local nearbyObject, nearbyID

		for i=1, #weedPlants, 1 do
			if #(coords - GetEntityCoords(weedPlants[i])) < 1.5 then
				nearbyObject, nearbyID = weedPlants[i], i
			end
		end

		if nearbyObject and IsPedOnFoot(playerPed) then
			sleep = 0
		
			if not isPickingUp and not displayed_pickup_prompt then
				ESX.TextUI(TranslateCap('weed_pickupprompt'))
				displayed_pickup_prompt = true
			end

			if IsControlJustReleased(0, 38) and not isPickingUp then
				isPickingUp = true
			
				ESX.TriggerServerCallback('esx_drugs:canPickUp', function(canPickUp)
					if canPickUp then
						TaskStartScenarioInPlace(playerPed, 'world_human_gardener_plant', 0, false)
					
						Wait(2000)
						ClearPedTasks(playerPed)
						Wait(1500)
						
						ESX.Game.DeleteObject(nearbyObject)
						
						table.remove(weedPlants, nearbyID)
						spawnedWeeds = spawnedWeeds - 1
						
						TriggerServerEvent('esx_drugs:pickedUpCannabis')
						if displayed_pickup_prompt then
							displayed_pickup_prompt = false
							ESX.HideUI()
						end
					else
						ESX.ShowNotification(TranslateCap('weed_inventoryfull'))
						if displayed_pickup_prompt then
							displayed_pickup_prompt = false
							ESX.HideUI()
						end
					end
					
					isPickingUp = false
				end, 'cannabis')
			end
		else
			sleep = 1500
			if displayed_pickup_prompt then
				displayed_pickup_prompt = false
				ESX.HideUI()
			end
		end

		if displayed_pickup_prompt and (not nearbyObject or not IsPedOnFoot(playerPed)) then
			displayed_pickup_prompt = false
			ESX.HideUI()
		end

		Wait(sleep)
	end
end)


AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		for k, v in pairs(weedPlants) do
			ESX.Game.DeleteObject(v)
		end
	end
end)

function SpawnWeedPlants()
	while spawnedWeeds < 25 do
		Wait(0)
		local weedCoords = GenerateWeedCoords()

		ESX.Game.SpawnLocalObject('prop_weed_02', weedCoords, function(obj)
			PlaceObjectOnGroundProperly(obj)
			FreezeEntityPosition(obj, true)

			table.insert(weedPlants, obj)
			spawnedWeeds = spawnedWeeds + 1
		end)
	end
end

function ValidateWeedCoord(plantCoord)
	if spawnedWeeds > 0 then
		local validate = true

		for k, v in pairs(weedPlants) do
			if #(plantCoord - GetEntityCoords(v)) < 5 then
				validate = false
			end
		end

		if #(plantCoord - Config.CircleZones.WeedField.coords) > 50 then
			validate = false
		end

		return validate
	else
		return true
	end
end

function GenerateWeedCoords()
	while true do
		Wait(0)

		local weedCoordX, weedCoordY

		math.randomseed(GetGameTimer())
		local modX = math.random(-90, 90)

		Wait(100)

		math.randomseed(GetGameTimer())
		local modY = math.random(-90, 90)

		weedCoordX = Config.CircleZones.WeedField.coords.x + modX
		weedCoordY = Config.CircleZones.WeedField.coords.y + modY

		local coordZ = GetCoordZ(weedCoordX, weedCoordY)
		local coord = vector3(weedCoordX, weedCoordY, coordZ)

		if ValidateWeedCoord(coord) then
			return coord
		end
	end
end

function GetCoordZ(x, y)
	local groundCheckHeights = { 48.0, 49.0, 50.0, 51.0, 52.0, 53.0, 54.0, 55.0, 56.0, 57.0, 58.0 }

	for i, height in ipairs(groundCheckHeights) do
		local foundGround, z = GetGroundZFor_3dCoord(x, y, height)

		if foundGround then
			return z
		end
	end

	return 43.0
end