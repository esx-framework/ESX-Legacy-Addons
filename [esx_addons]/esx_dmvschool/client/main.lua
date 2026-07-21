local CurrentTest       = nil
local CurrentTestType   = nil
local CurrentVehicle    = nil
local CurrentCheckPoint, DriveErrors = 0, 0
local LastCheckPoint    = -1
local CurrentBlip       = nil
local CurrentZoneType   = nil
local LastVehicleHealth = nil
local failedTest = false

function DrawMissionText(msg, time)
	ClearPrints()
	BeginTextCommandPrint('STRING')
	AddTextComponentSubstringPlayerName(msg)
	EndTextCommandPrint(time, true)
end

function StartTheoryTest()
	CurrentTest = 'theory'
	SendNUIMessage({
		openQuestion = true
	})
	ESX.SetTimeout(200, function()
		SetNuiFocus(true, true)
	end)
	ESX.HideUI()
end

function StopTheoryTest(success)
	CurrentTest = nil
	SendNUIMessage({
		openQuestion = false
	})
	SetNuiFocus(false)
	if success then
		TriggerServerEvent('esx_dmvschool:addLicense', 'dmv')
		ESX.ShowNotification(TranslateCap('passed_test'))
	else
		ESX.ShowNotification(TranslateCap('failed_test'))
	end
	ESX.TextUI(TranslateCap('press_open_menu'))
end

function StartDriveTest(type)
	ESX.Game.SpawnVehicle(Config.VehicleModels[type], vector3(Config.Zones.VehicleSpawnPoint.Pos.x, Config.Zones.VehicleSpawnPoint.Pos.y, Config.Zones.VehicleSpawnPoint.Pos.z), Config.Zones.VehicleSpawnPoint.Pos.h, function(vehicle)
		CurrentTest       = 'drive'
		CurrentTestType   = type
		CurrentCheckPoint = 0
		LastCheckPoint    = -1
		CurrentZoneType   = 'residence'
		DriveErrors       = 0
		IsAboveSpeedLimit = false
		CurrentVehicle    = vehicle
		LastVehicleHealth = GetEntityHealth(vehicle)
		failedTest = false
		local playerPed   = PlayerPedId()
		TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
		SetVehicleFuelLevel(vehicle, 100.0)
		DecorSetFloat(vehicle, "_FUEL_LEVEL", GetVehicleFuelLevel(vehicle))
	end)
end

function StopDriveTest(success)
	if success then
		TriggerServerEvent('esx_dmvschool:addLicense', CurrentTestType)
		ESX.ShowNotification(TranslateCap('passed_test'))
		ESX.ShowNotification(TranslateCap('driving_test_complete'))
	else
		ESX.ShowNotification(TranslateCap('failed_test'))
	end
	CurrentTest     = nil
	CurrentTestType = nil
end

function SetCurrentZoneType(type)
	CurrentZoneType = type
end

function OpenDMVSchoolMenu()
    ESX.TriggerServerCallback('esx_license:getLicenses', function(licenses)
        ESX.HideUI()

        local ownedLicenses = {}
        for i=1, #licenses do
            ownedLicenses[licenses[i].type] = true
        end

        local elements = {
            { unselectable = true, icon = "fas fa-car", title = TranslateCap("driving_school") }
        }

        local function addLicenseOption(icon, titleKey, priceKey, value, licType)
            elements[#elements+1] = {
                icon = icon,
                title = (('%s: <span style="color:green;">%s</span>'):format(
                    TranslateCap(titleKey),
                    TranslateCap('school_item', ESX.Math.GroupDigits(Config.Prices[priceKey]))
                )),
                value = value,
                type = licType
            }
        end

        if not ownedLicenses['dmv'] then
            addLicenseOption("fas fa-id-card", "theory", "dmv", "theory", "dmv")
        else
            local driveTests = {
                { icon = "fas fa-car", key = "drive", label = "road_test_car" },
                { icon = "fas fa-motorcycle", key = "drive_bike", label = "road_test_bike" },
                { icon = "fas fa-truck", key = "drive_truck", label = "road_test_truck" }
            }
            for _, test in ipairs(driveTests) do
                if not ownedLicenses[test.key] then
                    addLicenseOption(test.icon, test.label, test.key, "drive_test", test.key)
                end
            end
        end

        ESX.OpenContext("right", elements, function(menu, element)
            ESX.TriggerServerCallback('esx_dmvschool:canYouPay', function(haveMoney)
                if not haveMoney then
                    return ESX.ShowNotification(TranslateCap('not_enough_money'))
                end
                ESX.CloseContext()
                if element.value == "theory" then
                    StartTheoryTest()
                else
                    StartDriveTest(element.type)
                end
            end, element.type)
        end, function(menu)
            ESX.TextUI(TranslateCap('press_open_menu'))
        end)
    end, GetPlayerServerId(PlayerId()))
end

RegisterNUICallback('question', function(data, cb)
	SendNUIMessage({openSection = 'question'})
	cb()
end)

RegisterNUICallback('close', function(data, cb)
	StopTheoryTest(true)
	cb()
end)

RegisterNUICallback('kick', function(data, cb)
	StopTheoryTest(false)
	cb()
end)

AddEventHandler('esx_dmvschool:hasEnteredMarker', function(zone)
	ESX.TextUI(TranslateCap('press_open_menu'))
end)

AddEventHandler('esx_dmvschool:hasExitedMarker', function(zone)
	ESX.CloseContext()
	ESX.HideUI()
end)

CreateThread(function()
	local blip = AddBlipForCoord(Config.Zones.DMVSchool.Pos.x, Config.Zones.DMVSchool.Pos.y, Config.Zones.DMVSchool.Pos.z)

	SetBlipSprite (blip, 408)
	SetBlipColour (blip, 0)
	SetBlipDisplay(blip, 4)
	SetBlipScale  (blip, 1.2)
	SetBlipAsShortRange(blip, true)

	BeginTextCommandSetBlipName("STRING")
	AddTextComponentSubstringPlayerName(TranslateCap('driving_school_blip'))
	EndTextCommandSetBlipName(blip)
end)

CreateThread(function()
	while true do
		local sleep = 1500
		local playerPed = PlayerPedId()
		local coords = GetEntityCoords(playerPed)

		local isInMarker = false
		local currentZone = nil

		for k, v in pairs(Config.Zones) do
			local Pos = vector3(v.Pos.x, v.Pos.y, v.Pos.z)
			local distance = #(coords - Pos)

			if v.Type ~= -1 and distance < Config.DrawDistance then
				sleep = 0
				DrawMarker(v.Type, v.Pos.x, v.Pos.y, v.Pos.z,0.0, 0.0, 0.0, 0, 0.0, 0.0,v.Size.x, v.Size.y, v.Size.z,v.Color.r, v.Color.g, v.Color.b, 100,false, true, 2, false, false, false, false)
			end

			if distance < v.Size.x then
				sleep = 0
				isInMarker = true
				currentZone = k
			end
		end

		if CurrentTest == 'theory' then
			sleep = 0
			DisableControlAction(0, 1, true)
			DisableControlAction(0, 2, true)
			DisablePlayerFiring(playerPed, true)
			DisableControlAction(0, 142, true)
			DisableControlAction(0, 106, true)
		end

		if CurrentTest == 'drive' then
			sleep = 0
			local nextCheckPoint = CurrentCheckPoint + 1

			if Config.CheckPoints[nextCheckPoint] == nil then
				if DoesBlipExist(CurrentBlip) then
					RemoveBlip(CurrentBlip)
				end
				CurrentTest = nil
				StopDriveTest(DriveErrors < Config.MaxErrors)
			else
				if CurrentCheckPoint ~= LastCheckPoint then
					if DoesBlipExist(CurrentBlip) then
						RemoveBlip(CurrentBlip)
					end
					CurrentBlip = AddBlipForCoord(Config.CheckPoints[nextCheckPoint].Pos.x, Config.CheckPoints[nextCheckPoint].Pos.y, Config.CheckPoints[nextCheckPoint].Pos.z)
					SetBlipRoute(CurrentBlip, true)
					LastCheckPoint = CurrentCheckPoint
				end

				local Pos = vector3(Config.CheckPoints[nextCheckPoint].Pos.x, Config.CheckPoints[nextCheckPoint].Pos.y, Config.CheckPoints[nextCheckPoint].Pos.z)
				local distance = #(coords - Pos)

				if distance <= Config.DrawDistance then
					DrawMarker(1, Pos.x, Pos.y, Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 1.5, 1.5, 1.5, 102, 204, 102, 100, false, true, 2, false, false, false, false)
				end

				if distance <= 3.0 then
					Config.CheckPoints[nextCheckPoint].Action(playerPed, CurrentVehicle, SetCurrentZoneType)
					CurrentCheckPoint = CurrentCheckPoint + 1
				end
			end
		else
			sleep = 0
			if isInMarker and IsControlJustReleased(0, 38) then
				OpenDMVSchoolMenu()
				ESX.HideUI()
			end
		end

		if (isInMarker and not HasAlreadyEnteredMarker) or (isInMarker and LastZone ~= currentZone) then
			HasAlreadyEnteredMarker = true
			LastZone = currentZone
			TriggerEvent('esx_dmvschool:hasEnteredMarker', currentZone)
		end

		if not isInMarker and HasAlreadyEnteredMarker then
			HasAlreadyEnteredMarker = false
			TriggerEvent('esx_dmvschool:hasExitedMarker', LastZone)
		end

		Wait(sleep)
	end
end)

function TestFailedGoToLastCheckPoint()
	CurrentCheckPoint = #Config.CheckPoints - 1
	failedTest = true
end

CreateThread(function()
	while true do
		local sleep = 1500
		if CurrentTest == 'drive' then
			sleep = 0
			local playerPed = PlayerPedId()
			
			if IsPedInAnyVehicle(playerPed, false) then
				local vehicle = GetVehiclePedIsIn(playerPed, false)
				local speed = GetEntitySpeed(vehicle) * Config.SpeedMultiplier
				local health = GetEntityHealth(vehicle)

				for k, v in pairs(Config.SpeedLimits) do
					if CurrentZoneType == k and speed > v then
						DriveErrors += 1
						if DriveErrors <= Config.MaxErrors then
							ESX.ShowNotification(TranslateCap('driving_too_fast', v))
							ESX.ShowNotification(TranslateCap('errors', DriveErrors, Config.MaxErrors))
						end

						sleep = (Config.SpeedingErrorDelay < 5000) and 5000 or Config.SpeedingErrorDelay
					end
				end

				if health < LastVehicleHealth then
					DriveErrors += 1
					if DriveErrors <= Config.MaxErrors then
						ESX.ShowNotification(TranslateCap('you_damaged_veh'))
						ESX.ShowNotification(TranslateCap('errors', DriveErrors, Config.MaxErrors))
					end
					LastVehicleHealth = health
					sleep = 1500
				end

				if DriveErrors > Config.MaxErrors then
					ESX.ShowNotification(TranslateCap('test_failed_go_to_start_point'))
					if not failedTest then
						TestFailedGoToLastCheckPoint()
					end
					sleep = 5000
				end
			end
		end
		Wait(sleep)
	end
end)