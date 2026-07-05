local spectating = false
local escCooldownUntil = 0
local lastCoords = nil
local noClipActive = false
local godmodeActive = false
local invisibleActive = false
local noClipForcedInvisible = false
local namesActive = false
local blipsActive = false
local infiniteAmmoActive = false
local noClipEntity = nil
local godmodeVehicle = nil
local invisibleVehicle = nil
local playerBlips = {}
local vehicleEngineLevel = 1
local vehicleBrakeLevel = 1
local vehicleTransmissionLevel = 1
local vehicleSuspensionLevel = 1
local vehicleArmorLevel = 1
local vehicleColorIndex = 1
local neonColorIndex = 1

ClientActions = ClientActions or {}

local function getNoClipSpeed()
	return (Config.AdminMenu and Config.AdminMenu.NoClipSpeed) or 1.5
end

local function getCameraDirection()
	local ped = PlayerPedId()
	local heading = GetEntityHeading(ped) + GetGameplayCamRelativeHeading()
	local pitch = GetGameplayCamRelativePitch()
	local headingRadians = math.rad(heading)
	local pitchRadians = math.rad(pitch)
	local cosPitch = math.abs(math.cos(pitchRadians))

	return vector3(
		-math.sin(headingRadians) * cosPitch,
		math.cos(headingRadians) * cosPitch,
		math.sin(pitchRadians)
	)
end

local function drawWorldText(coords, text)
	local onScreen, screenX, screenY = World3dToScreen2d(coords.x, coords.y, coords.z)
	if not onScreen then
		return
	end

	SetTextScale(0.3, 0.3)
	SetTextFont(4)
	SetTextProportional(true)
	SetTextColour(255, 255, 255, 215)
	SetTextCentre(true)
	SetTextEntry("STRING")
	AddTextComponentString(text)
	DrawText(screenX, screenY)
end

local function requestModel(model)
	local modelHash = type(model) == "number" and model or joaat(model)
	if not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then
		return nil, "Invalid model."
	end

	RequestModel(modelHash)

	local timeout = GetGameTimer() + 5000
	while not HasModelLoaded(modelHash) do
		Wait(0)
		if GetGameTimer() > timeout then
			return nil, "Model load timed out."
		end
	end

	return modelHash
end

local function trimString(value)
	if type(value) ~= "string" then
		return ""
	end

	return value:match("^%s*(.-)%s*$")
end

local function getVehicleConfig()
	return Config.VehicleSpawner or {}
end

local function getColorPresets()
	local vehicleConfig = getVehicleConfig()
	return vehicleConfig.ColorPresets or {}
end

local function getNeonPresets()
	local vehicleConfig = getVehicleConfig()
	return vehicleConfig.NeonPresets or {}
end

local function getWheelCategories()
	local vehicleConfig = getVehicleConfig()
	return vehicleConfig.WheelCategories or {}
end

local function getControlledEntity()
	local ped = PlayerPedId()
	local vehicle = GetVehiclePedIsIn(ped, false)

	if vehicle ~= 0 then
		return vehicle, ped
	end

	return ped, ped
end

local function getCurrentVehicle()
	local ped = PlayerPedId()
	local vehicle = GetVehiclePedIsIn(ped, false)

	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return nil, "You must be in a vehicle."
	end

	return vehicle
end

local function findColorPreset(colorId)
	local presets = getColorPresets()

	for i = 1, #presets do
		local preset = presets[i]
		if preset.id == colorId then
			return preset, i
		end
	end

	return presets[1], 1
end

local function applyVehicleColor(vehicle, colorId)
	local preset, index = findColorPreset(colorId)
	if not preset then
		return nil, nil
	end

	SetVehicleColours(vehicle, tonumber(preset.primary) or 0, tonumber(preset.secondary) or tonumber(preset.primary) or 0)
	vehicleColorIndex = index

	return preset.label or preset.id or "Color", preset.id
end

local function applyVehicleColors(vehicle, primaryColorId, secondaryColorId)
	local primaryPreset, primaryIndex = findColorPreset(primaryColorId)
	if not primaryPreset then
		return nil, nil
	end

	local secondaryPreset = findColorPreset(secondaryColorId)
	if not secondaryPreset then
		secondaryPreset = primaryPreset
	end

	SetVehicleColours(
		vehicle,
		tonumber(primaryPreset.primary) or 0,
		tonumber(secondaryPreset.secondary) or tonumber(secondaryPreset.primary) or tonumber(primaryPreset.secondary) or tonumber(primaryPreset.primary) or 0
	)
	vehicleColorIndex = primaryIndex

	return primaryPreset.label or primaryPreset.id or "Color", primaryPreset.id
end

local function findNeonPreset(colorId)
	local presets = getNeonPresets()

	for i = 1, #presets do
		local preset = presets[i]
		if preset.id == colorId then
			return preset, i
		end
	end

	return presets[1], 1
end

local function findWheelCategory(categoryId)
	local categories = getWheelCategories()

	for i = 1, #categories do
		local category = categories[i]
		if category.id == categoryId then
			return category
		end
	end

	return categories[1] or { id = "sport", label = "Sport", type = 0 }
end

local function applyVehicleNeon(vehicle, enabled, colorId)
	for i = 0, 3 do
		SetVehicleNeonLightEnabled(vehicle, i, enabled == true)
	end

	local preset, index = findNeonPreset(colorId)
	if preset then
		SetVehicleNeonLightsColour(vehicle, tonumber(preset.r) or 255, tonumber(preset.g) or 255, tonumber(preset.b) or 255)
		neonColorIndex = index
		return preset.label or preset.id or "Neon"
	end

	return nil
end

local function applyVehicleWheels(vehicle, categoryId, design)
	local category = findWheelCategory(categoryId)
	local wheelType = tonumber(category.type) or 0
	local wheelDesign = math.floor(tonumber(design) or -1)

	SetVehicleModKit(vehicle, 0)
	SetVehicleWheelType(vehicle, wheelType)

	local frontCount = GetNumVehicleMods(vehicle, 23)
	if frontCount > 0 then
		local frontIndex = math.max(-1, math.min(wheelDesign, frontCount - 1))
		SetVehicleMod(vehicle, 23, frontIndex, false)
	end

	local rearCount = GetNumVehicleMods(vehicle, 24)
	if rearCount > 0 then
		local rearIndex = math.max(-1, math.min(wheelDesign, rearCount - 1))
		SetVehicleMod(vehicle, 24, rearIndex, false)
	end
end

local function levelToModIndex(vehicle, modType, level)
	level = math.max(1, math.min(5, math.floor(tonumber(level) or 1)))
	local count = GetNumVehicleMods(vehicle, modType)

	if count <= 0 or level <= 1 then
		return -1, level
	end

	local modIndex = math.min(count - 1, level - 2)
	return modIndex, level
end

local function applyVehicleModLevel(vehicle, modType, level)
	SetVehicleModKit(vehicle, 0)

	local modIndex, normalizedLevel = levelToModIndex(vehicle, modType, level)
	SetVehicleMod(vehicle, modType, modIndex, false)

	return normalizedLevel
end

local function applyVehicleCustomizations(vehicle, data)
	data = data or {}
	local useMaxPerformance = data.maxPerformance == true

	local engineLevel = applyVehicleModLevel(vehicle, 11, useMaxPerformance and 5 or data.engineLevel or vehicleEngineLevel)
	local brakeLevel = applyVehicleModLevel(vehicle, 12, useMaxPerformance and 5 or data.brakeLevel or vehicleBrakeLevel)
	local transmissionLevel = applyVehicleModLevel(vehicle, 13, useMaxPerformance and 5 or data.transmissionLevel or vehicleTransmissionLevel)
	local suspensionLevel = applyVehicleModLevel(vehicle, 15, useMaxPerformance and 5 or data.suspensionLevel or vehicleSuspensionLevel)
	local armorLevel = applyVehicleModLevel(vehicle, 16, useMaxPerformance and 5 or data.armorLevel or vehicleArmorLevel)

	vehicleEngineLevel = engineLevel
	vehicleBrakeLevel = brakeLevel
	vehicleTransmissionLevel = transmissionLevel
	vehicleSuspensionLevel = suspensionLevel
	vehicleArmorLevel = armorLevel

	if useMaxPerformance then
		ToggleVehicleMod(vehicle, 18, true)
	end

	if data.turbo ~= nil then
		ToggleVehicleMod(vehicle, 18, data.turbo == true)
	end

	if data.xenon ~= nil then
		ToggleVehicleMod(vehicle, 22, data.xenon == true)
	end

	if data.primaryColor or data.secondaryColor then
		local primaryColor = trimString(data.primaryColor or data.color)
		local secondaryColor = trimString(data.secondaryColor or data.primaryColor or data.color)
		applyVehicleColors(vehicle, primaryColor, secondaryColor)
	elseif data.color then
		applyVehicleColor(vehicle, trimString(data.color))
	end

	if data.neon ~= nil or data.neonColor then
		applyVehicleNeon(vehicle, data.neon == true, trimString(data.neonColor))
	end

	if data.windowTint ~= nil then
		SetVehicleWindowTint(vehicle, math.floor(tonumber(data.windowTint) or 0))
	end

	if data.wheelCategory ~= nil or data.wheelDesign ~= nil then
		applyVehicleWheels(vehicle, trimString(data.wheelCategory), data.wheelDesign)
	end

	if data.bulletproofTires ~= nil then
		SetVehicleTyresCanBurst(vehicle, data.bulletproofTires ~= true)
	end

	return {
		engineLevel = engineLevel,
		brakeLevel = brakeLevel,
		transmissionLevel = transmissionLevel,
		suspensionLevel = suspensionLevel,
		armorLevel = armorLevel,
	}
end

local function applyVehiclePerformance(vehicle, engineLevel, brakeLevel, maxPerformance)
	local levels = applyVehicleCustomizations(vehicle, {
		engineLevel = engineLevel,
		brakeLevel = brakeLevel,
		transmissionLevel = maxPerformance and 5 or vehicleTransmissionLevel,
		suspensionLevel = maxPerformance and 5 or vehicleSuspensionLevel,
		armorLevel = maxPerformance and 5 or vehicleArmorLevel,
		turbo = maxPerformance and true or nil,
		maxPerformance = maxPerformance,
	})

	return levels.engineLevel, levels.brakeLevel
end

local function notifyAction(message, notificationType)
	if ESX and ESX.ShowNotification then
		ESX.ShowNotification(message, notificationType or "success")
	end
end

local function setNoClipEntityState(entity, enabled)
	if not entity or entity == 0 or not DoesEntityExist(entity) then
		return
	end

	FreezeEntityPosition(entity, enabled)
	SetEntityCollision(entity, not enabled, not enabled)
	SetEntityInvincible(entity, enabled)
	SetEntityVelocity(entity, 0.0, 0.0, 0.0)
end

local function applyGodmodeVehicle(vehicle)
	if godmodeVehicle and godmodeVehicle ~= vehicle and DoesEntityExist(godmodeVehicle) then
		SetEntityInvincible(godmodeVehicle, false)
	end

	if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
		SetEntityInvincible(vehicle, godmodeActive)
		godmodeVehicle = godmodeActive and vehicle or nil
	else
		godmodeVehicle = nil
	end
end

local function applyInvisibleVehicle(vehicle)
	if invisibleVehicle and invisibleVehicle ~= vehicle and DoesEntityExist(invisibleVehicle) then
		SetEntityVisible(invisibleVehicle, true, false)
		NetworkSetEntityInvisibleToNetwork(invisibleVehicle, false)
	end

	if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
		SetEntityVisible(vehicle, not invisibleActive, false)
		NetworkSetEntityInvisibleToNetwork(vehicle, invisibleActive)
		invisibleVehicle = invisibleActive and vehicle or nil
	else
		invisibleVehicle = nil
	end
end

local function watchGodmodeVehicle()
	CreateThread(function()
		while godmodeActive do
			applyGodmodeVehicle(GetVehiclePedIsIn(PlayerPedId(), false))
			Wait(500)
		end

		applyGodmodeVehicle(0)
	end)
end

local function watchInvisibleVehicle()
	CreateThread(function()
		while invisibleActive do
			applyInvisibleVehicle(GetVehiclePedIsIn(PlayerPedId(), false))
			Wait(500)
		end

		applyInvisibleVehicle(0)
	end)
end

local function setInvisibleActive(enabled)
	enabled = enabled == true

	if invisibleActive == enabled then
		local ped = PlayerPedId()
		SetEntityVisible(ped, not invisibleActive, false)
		NetworkSetEntityInvisibleToNetwork(ped, invisibleActive)
		applyInvisibleVehicle(GetVehiclePedIsIn(ped, false))
		return invisibleActive
	end

	invisibleActive = enabled
	local ped = PlayerPedId()
	local vehicle = GetVehiclePedIsIn(ped, false)

	SetEntityVisible(ped, not invisibleActive, false)
	NetworkSetEntityInvisibleToNetwork(ped, invisibleActive)
	applyInvisibleVehicle(vehicle)

	if invisibleActive then
		watchInvisibleVehicle()
	end

	return invisibleActive
end

local function runNoClip()
	CreateThread(function()
		local entity, ped = getControlledEntity()
		noClipEntity = entity
		setNoClipEntityState(entity, true)

		while noClipActive do
			Wait(0)

			local currentEntity, currentPed = getControlledEntity()
			if currentEntity ~= entity then
				setNoClipEntityState(entity, false)
				entity = currentEntity
				noClipEntity = entity
				setNoClipEntityState(entity, true)
			end

			ped = currentPed
			local coords = GetEntityCoords(entity)
			local forward = getCameraDirection()
			local right = vector3(forward.y, -forward.x, 0.0)
			local speed = getNoClipSpeed()

			if IsDisabledControlPressed(0, 21) then
				speed = speed * 3.0
			elseif IsDisabledControlPressed(0, 36) then
				speed = speed * 0.35
			end

			DisableControlAction(0, 30, true)
			DisableControlAction(0, 31, true)
			DisableControlAction(0, 32, true)
			DisableControlAction(0, 33, true)
			DisableControlAction(0, 34, true)
			DisableControlAction(0, 35, true)
			DisableControlAction(0, 22, true)
			DisableControlAction(0, 44, true)
			DisableControlAction(0, 75, true)

			if IsDisabledControlPressed(0, 32) then
				coords = coords + forward * speed
			end
			if IsDisabledControlPressed(0, 33) then
				coords = coords - forward * speed
			end
			if IsDisabledControlPressed(0, 34) then
				coords = coords - right * speed
			end
			if IsDisabledControlPressed(0, 35) then
				coords = coords + right * speed
			end
			if IsDisabledControlPressed(0, 22) then
				coords = coords + vector3(0.0, 0.0, speed)
			end
			if IsDisabledControlPressed(0, 44) then
				coords = coords - vector3(0.0, 0.0, speed)
			end

			SetEntityCoordsNoOffset(entity, coords.x, coords.y, coords.z, true, true, true)
			SetEntityHeading(entity, GetGameplayCamRot(0).z)
		end

		setNoClipEntityState(entity, false)
		noClipEntity = nil
	end)
end

function ClientActions.ToggleNoClip()
	noClipActive = not noClipActive

	if noClipActive then
		if not invisibleActive then
			noClipForcedInvisible = true
			setInvisibleActive(true)
		else
			noClipForcedInvisible = false
		end

		runNoClip()
	else
		local entity = noClipEntity
		if not entity then
			entity = getControlledEntity()
		end

		setNoClipEntityState(entity, false)
		noClipEntity = nil

		if noClipForcedInvisible then
			noClipForcedInvisible = false
			setInvisibleActive(false)
		end
	end

	return noClipActive
end

local function nativeRevivePlayer()
	local ped = PlayerPedId()
	local coords = GetEntityCoords(ped)
	local heading = GetEntityHeading(ped)

	NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
	ped = PlayerPedId()
	ClearPedTasksImmediately(ped)
	ClearPedBloodDamage(ped)
	SetEntityHealth(ped, GetEntityMaxHealth(ped))
end

function ClientActions.Revive()
	local ped = PlayerPedId()

	if IsEntityDead(ped) or IsPedFatallyInjured(ped) or GetEntityHealth(ped) <= 0 then
		nativeRevivePlayer()
	else
		ClearPedTasksImmediately(ped)
		ClearPedBloodDamage(ped)
		SetEntityHealth(ped, GetEntityMaxHealth(ped))
	end

	return true
end

function ClientActions.Heal()
	local ped = PlayerPedId()

	ClearPedBloodDamage(ped)
	SetEntityHealth(ped, GetEntityMaxHealth(ped))

	return true
end

function ClientActions.SetArmor(amount)
	SetPedArmour(PlayerPedId(), amount or 100)

	return true
end

function ClientActions.ToggleGodmode()
	godmodeActive = not godmodeActive
	local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)

	SetPlayerInvincible(PlayerId(), godmodeActive)
	SetEntityInvincible(PlayerPedId(), godmodeActive)
	applyGodmodeVehicle(vehicle)

	if godmodeActive then
		watchGodmodeVehicle()
	end

	return godmodeActive
end

function ClientActions.ToggleInvisible()
	if noClipActive then
		if not invisibleActive then
			noClipForcedInvisible = true
		end

		return setInvisibleActive(true)
	end

	noClipForcedInvisible = false
	return setInvisibleActive(not invisibleActive)
end

function ClientActions.IsInvisibleActive()
	return invisibleActive
end

function ClientActions.ToggleInfiniteAmmo()
	infiniteAmmoActive = not infiniteAmmoActive
	local ped = PlayerPedId()

	SetPedInfiniteAmmoClip(ped, infiniteAmmoActive)

	if infiniteAmmoActive then
		CreateThread(function()
			while infiniteAmmoActive do
				ped = PlayerPedId()

				SetPedInfiniteAmmoClip(ped, true)

				Wait(500)
			end

			SetPedInfiniteAmmoClip(PlayerPedId(), false)
		end)
	end

	return infiniteAmmoActive
end

function ClientActions.ToggleNames()
	namesActive = not namesActive

	if namesActive then
		CreateThread(function()
			while namesActive do
				Wait(0)

				local myPed = PlayerPedId()
				local myCoords = GetEntityCoords(myPed)
				local maxDistance = (Config.AdminMenu and Config.AdminMenu.NamesDistance) or 75.0

				for _, player in ipairs(GetActivePlayers()) do
					if player ~= PlayerId() then
						local ped = GetPlayerPed(player)
						if ped ~= 0 and DoesEntityExist(ped) then
							local coords = GetEntityCoords(ped)
							local distance = #(myCoords - coords)

							if distance <= maxDistance then
								local serverId = GetPlayerServerId(player)
								drawWorldText(coords + vector3(0.0, 0.0, 1.05), ("[%s] %s"):format(serverId, GetPlayerName(player)))
							end
						end
					end
				end
			end
		end)
	end

	return namesActive
end

function ClientActions.ToggleBlips()
	blipsActive = not blipsActive

	if not blipsActive then
		for serverId, blip in pairs(playerBlips) do
			if DoesBlipExist(blip) then
				RemoveBlip(blip)
			end
			playerBlips[serverId] = nil
		end

		return false
	end

	CreateThread(function()
		while blipsActive do
			local activeServerIds = {}

			for _, player in ipairs(GetActivePlayers()) do
				if player ~= PlayerId() then
					local ped = GetPlayerPed(player)
					local serverId = GetPlayerServerId(player)
					activeServerIds[serverId] = true

					if ped ~= 0 and DoesEntityExist(ped) then
						if not playerBlips[serverId] or not DoesBlipExist(playerBlips[serverId]) then
							local blip = AddBlipForEntity(ped)
							SetBlipSprite(blip, 1)
							SetBlipScale(blip, 0.85)
							SetBlipColour(blip, 5)
							ShowHeadingIndicatorOnBlip(blip, true)
							BeginTextCommandSetBlipName("STRING")
							AddTextComponentString(("[%s] %s"):format(serverId, GetPlayerName(player)))
							EndTextCommandSetBlipName(blip)
							playerBlips[serverId] = blip
						end
					end
				end
			end

			for serverId, blip in pairs(playerBlips) do
				if not activeServerIds[serverId] then
					if DoesBlipExist(blip) then
						RemoveBlip(blip)
					end
					playerBlips[serverId] = nil
				end
			end

			Wait(1500)
		end
	end)

	return true
end

function ClientActions.RepairVehicle()
	local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
	if vehicle == 0 then
		return false, "You must be in a vehicle."
	end

	SetVehicleFixed(vehicle)
	SetVehicleDeformationFixed(vehicle)
	SetVehicleUndriveable(vehicle, false)
	SetVehicleEngineOn(vehicle, true, true, false)

	return true
end

function ClientActions.CleanVehicle()
	local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
	if vehicle == 0 then
		return false, "You must be in a vehicle."
	end

	SetVehicleDirtLevel(vehicle, 0.0)

	return true
end

function ClientActions.FlipVehicle()
	local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
	if vehicle == 0 then
		return false, "You must be in a vehicle."
	end

	SetVehicleOnGroundProperly(vehicle)

	return true
end

function ClientActions.DeleteVehicle()
	local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
	if vehicle == 0 then
		return false, "You must be in a vehicle."
	end

	SetEntityAsMissionEntity(vehicle, true, true)
	DeleteEntity(vehicle)

	return true
end

function ClientActions.SpawnVehicle(data)
	data = data or {}
	local vehicleConfig = getVehicleConfig()
	local model = trimString(data.model)

	if model == "" then
		model = vehicleConfig.DefaultModel or "sultan"
	end

	local modelHash, err = requestModel(model)
	if not modelHash then
		return false, err or "Invalid vehicle model."
	end
	if not IsModelAVehicle(modelHash) then
		SetModelAsNoLongerNeeded(modelHash)
		return false, "Model must be a vehicle."
	end

	local ped = PlayerPedId()
	local currentVehicle = GetVehiclePedIsIn(ped, false)
	local deleteCurrent = true

	if currentVehicle ~= 0 and deleteCurrent then
		SetEntityAsMissionEntity(currentVehicle, true, true)
		DeleteEntity(currentVehicle)
	end

	local coords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 4.5, 0.0)
	local heading = GetEntityHeading(ped)
	local vehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading, true, false)

	if not vehicle or vehicle == 0 then
		SetModelAsNoLongerNeeded(modelHash)
		return false, "Failed to spawn vehicle."
	end

	SetEntityAsMissionEntity(vehicle, true, true)
	SetVehicleOnGroundProperly(vehicle)
	SetVehicleHasBeenOwnedByPlayer(vehicle, true)
	SetVehicleNeedsToBeHotwired(vehicle, false)
	SetVehRadioStation(vehicle, "OFF")

	local fallbackColor = trimString(data.color)
	if fallbackColor == "" then
		fallbackColor = vehicleConfig.DefaultColor or "black"
	end

	local primaryColor = trimString(data.primaryColor)
	if primaryColor == "" then
		primaryColor = fallbackColor
	end

	local secondaryColor = trimString(data.secondaryColor)
	if secondaryColor == "" then
		secondaryColor = primaryColor
	end

	local colorLabel = applyVehicleColors(vehicle, primaryColor, secondaryColor)
	if data.maxPerformance == true then
		applyVehicleCustomizations(vehicle, {
			engineLevel = 5,
			brakeLevel = 5,
			transmissionLevel = 5,
			suspensionLevel = 5,
			armorLevel = 5,
			turbo = true,
			xenon = true,
			color = fallbackColor,
			primaryColor = primaryColor,
			secondaryColor = secondaryColor,
			maxPerformance = true,
		})
	elseif data.engineLevel or data.brakeLevel or data.transmissionLevel or data.suspensionLevel or data.armorLevel or data.turbo ~= nil or data.xenon ~= nil or data.neon ~= nil or data.windowTint ~= nil or data.wheelCategory ~= nil or data.wheelDesign ~= nil or data.bulletproofTires ~= nil then
		applyVehicleCustomizations(vehicle, data)
	end

	if vehicleConfig.WarpIntoVehicle ~= false and data.warp ~= false then
		SetPedIntoVehicle(ped, vehicle, -1)
	end

	SetModelAsNoLongerNeeded(modelHash)

	local label = Helpers and Helpers.resolveVehicleName and Helpers.resolveVehicleName(modelHash) or model
	notifyAction(("Spawned %s%s."):format(label, colorLabel and (" (" .. colorLabel .. ")") or ""))

	return true
end

function ClientActions.SetVehiclePerformance(data)
	data = data or {}
	local vehicle, err = getCurrentVehicle()
	if not vehicle then
		return false, err
	end

	local levels = applyVehicleCustomizations(vehicle, data)
	return true, nil, { value = ("E%s B%s T%s S%s A%s"):format(levels.engineLevel, levels.brakeLevel, levels.transmissionLevel, levels.suspensionLevel, levels.armorLevel) }
end

function ClientActions.CustomizeVehicle(data)
	return ClientActions.SetVehiclePerformance(data)
end

function ClientActions.CycleVehicleEngine()
	local vehicle, err = getCurrentVehicle()
	if not vehicle then
		return false, err
	end

	vehicleEngineLevel = vehicleEngineLevel + 1
	if vehicleEngineLevel > 5 then
		vehicleEngineLevel = 1
	end

	applyVehiclePerformance(vehicle, vehicleEngineLevel, vehicleBrakeLevel, false)
	return true, nil, { active = true, value = ("%s/5"):format(vehicleEngineLevel) }
end

function ClientActions.CycleVehicleBrakes()
	local vehicle, err = getCurrentVehicle()
	if not vehicle then
		return false, err
	end

	vehicleBrakeLevel = vehicleBrakeLevel + 1
	if vehicleBrakeLevel > 5 then
		vehicleBrakeLevel = 1
	end

	applyVehiclePerformance(vehicle, vehicleEngineLevel, vehicleBrakeLevel, false)
	return true, nil, { active = true, value = ("%s/5"):format(vehicleBrakeLevel) }
end

function ClientActions.CycleVehicleTransmission()
	local vehicle, err = getCurrentVehicle()
	if not vehicle then
		return false, err
	end

	vehicleTransmissionLevel = vehicleTransmissionLevel + 1
	if vehicleTransmissionLevel > 5 then
		vehicleTransmissionLevel = 1
	end

	applyVehicleCustomizations(vehicle, { transmissionLevel = vehicleTransmissionLevel })
	return true, nil, { active = true, value = ("%s/5"):format(vehicleTransmissionLevel) }
end

function ClientActions.CycleVehicleSuspension()
	local vehicle, err = getCurrentVehicle()
	if not vehicle then
		return false, err
	end

	vehicleSuspensionLevel = vehicleSuspensionLevel + 1
	if vehicleSuspensionLevel > 5 then
		vehicleSuspensionLevel = 1
	end

	applyVehicleCustomizations(vehicle, { suspensionLevel = vehicleSuspensionLevel })
	return true, nil, { active = true, value = ("%s/5"):format(vehicleSuspensionLevel) }
end

function ClientActions.CycleVehicleArmor()
	local vehicle, err = getCurrentVehicle()
	if not vehicle then
		return false, err
	end

	vehicleArmorLevel = vehicleArmorLevel + 1
	if vehicleArmorLevel > 5 then
		vehicleArmorLevel = 1
	end

	applyVehicleCustomizations(vehicle, { armorLevel = vehicleArmorLevel })
	return true, nil, { active = true, value = ("%s/5"):format(vehicleArmorLevel) }
end

function ClientActions.CycleVehicleColor()
	local vehicle, err = getCurrentVehicle()
	if not vehicle then
		return false, err
	end

	local presets = getColorPresets()
	if #presets == 0 then
		return false, "No vehicle color presets configured."
	end

	vehicleColorIndex = vehicleColorIndex + 1
	if vehicleColorIndex > #presets then
		vehicleColorIndex = 1
	end

	local preset = presets[vehicleColorIndex]
	local label = applyVehicleColor(vehicle, preset.id)

	return true, nil, { active = true, value = label or preset.id or "Color" }
end

function ClientActions.CycleVehicleNeonColor()
	local vehicle, err = getCurrentVehicle()
	if not vehicle then
		return false, err
	end

	local presets = getNeonPresets()
	if #presets == 0 then
		return false, "No neon color presets configured."
	end

	neonColorIndex = neonColorIndex + 1
	if neonColorIndex > #presets then
		neonColorIndex = 1
	end

	local preset = presets[neonColorIndex]
	local label = applyVehicleNeon(vehicle, true, preset.id)

	return true, nil, { active = true, value = label or preset.id or "Neon" }
end

function ClientActions.MaxVehiclePerformance()
	local vehicle, err = getCurrentVehicle()
	if not vehicle then
		return false, err
	end

	local levels = applyVehicleCustomizations(vehicle, { maxPerformance = true })
	return true, nil, { active = true, value = ("E%s B%s T%s S%s A%s"):format(levels.engineLevel, levels.brakeLevel, levels.transmissionLevel, levels.suspensionLevel, levels.armorLevel) }
end

function ClientActions.TeleportToWaypoint()
	local waypoint = GetFirstBlipInfoId(8)
	if not DoesBlipExist(waypoint) then
		return false, "No waypoint set."
	end

	local coords = GetBlipInfoIdCoord(waypoint)
	local ped = PlayerPedId()
	local vehicle = GetVehiclePedIsIn(ped, false)
	local entity = vehicle ~= 0 and vehicle or ped
	local foundGround = false
	local groundZ = coords.z

	for height = 0, 1000, 25 do
		SetEntityCoordsNoOffset(entity, coords.x, coords.y, height + 0.0, false, false, false)
		Wait(0)

		foundGround, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, height + 0.0, false)
		if foundGround then
			break
		end
	end

	SetEntityCoordsNoOffset(entity, coords.x, coords.y, (foundGround and groundZ or coords.z) + 1.0, false, false, false)

	return true
end

function ClientActions.CopyCoords()
	local ped = PlayerPedId()
	local coords = GetEntityCoords(ped)
	local heading = GetEntityHeading(ped)
	local text = string.format("vec4(%.2f, %.2f, %.2f, %.2f)", coords.x, coords.y, coords.z, heading)

	SendNUIMessage({
		action = "copyToClipboard",
		data = text,
	})

	return true
end

function ClientActions.SetWeather(weather)
	ClearOverrideWeather()
	ClearWeatherTypePersist()
	SetWeatherTypeNowPersist(weather)
	SetWeatherTypeNow(weather)
	SetWeatherTypePersist(weather)
end

function ClientActions.SetTime(hour, minute)
	NetworkOverrideClockTime(hour or 12, minute or 0, 0)
end

function ClientActions.SetBlackout(enabled)
	SetArtificialLightsState(enabled == true)
	SetArtificialLightsStateAffectsVehicles(enabled == true)
end

function ClientActions.SetPvp(enabled)
	NetworkSetFriendlyFireOption(enabled == true)
	SetCanAttackFriendly(PlayerPedId(), enabled == true, false)
end

function ClientActions.SetFrozen(enabled)
	local entity = getControlledEntity()
	FreezeEntityPosition(entity, enabled == true)
end

function ClientActions.Kill()
	SetEntityHealth(PlayerPedId(), 0)
end

function ClientActions.DeleteGamePool(poolName)
	for _, entity in ipairs(GetGamePool(poolName)) do
		if DoesEntityExist(entity) then
			if poolName ~= "CPed" or not IsPedAPlayer(entity) then
				SetEntityAsMissionEntity(entity, true, true)
				DeleteEntity(entity)
			end
		end
	end
end

RegisterNetEvent("esx-adminmenu:client:setWeather", function(weather)
	ClientActions.SetWeather(weather)
end)

RegisterNetEvent("esx-adminmenu:client:setTime", function(hour, minute)
	ClientActions.SetTime(hour, minute)
end)

RegisterNetEvent("esx-adminmenu:client:setBlackout", function(enabled)
	ClientActions.SetBlackout(enabled)
end)

RegisterNetEvent("esx-adminmenu:client:setPvp", function(enabled)
	ClientActions.SetPvp(enabled)
end)

RegisterNetEvent("esx-adminmenu:client:setFrozen", function(enabled)
	ClientActions.SetFrozen(enabled)
end)

RegisterNetEvent("esx-adminmenu:client:kill", function()
	ClientActions.Kill()
end)

RegisterNetEvent("esx-adminmenu:client:revive", function()
	ClientActions.Revive()
end)

RegisterNetEvent("esx-adminmenu:client:deletePool", function(poolName)
	ClientActions.DeleteGamePool(poolName)
end)

RegisterNetEvent("esx-adminmenu:client:setPlayerStats", function(health, armor)
	local ped = PlayerPedId()

	if health ~= nil then
		local maxHealth = GetEntityMaxHealth(ped)
		SetEntityHealth(ped, math.max(0, math.min(maxHealth, tonumber(health) + 100)))
	end

	if armor ~= nil then
		SetPedArmour(ped, math.max(0, math.min(100, tonumber(armor))))
	end
end)

RegisterNetEvent("esx-adminmenu:client:setModel", function(model)
	local modelHash, err = requestModel(model)
	if not modelHash then
		if ESX and ESX.ShowNotification then
			ESX.ShowNotification(err or "Invalid model.", "error")
		end
		return
	end

	SetPlayerModel(PlayerId(), modelHash)
	SetPedDefaultComponentVariation(PlayerPedId())
	SetModelAsNoLongerNeeded(modelHash)
end)

RegisterNetEvent("esx-adminmenu:client:openClothing", function()
	local events = (Config.Clothing and Config.Clothing.Events) or { "esx_skin:openSaveableMenu" }

	for i = 1, #events do
		TriggerEvent(events[i])
	end
end)

RegisterNetEvent("esx-adminmenu:client:setRadioChannel", function(channel)
	channel = tonumber(channel) or 0

	local ok = pcall(function()
		exports["pma-voice"]:setRadioChannel(channel)
	end)

	if not ok and ESX and ESX.ShowNotification then
		ESX.ShowNotification("pma-voice radio export was not available.", "error")
	end
end)

RegisterNetEvent("esx-adminmenu:client:troll", function(action)
	local ped = PlayerPedId()
	local coords = GetEntityCoords(ped)

	if action == "burn" then
		StartEntityFire(ped)
	elseif action == "explode" then
		AddExplosion(coords.x, coords.y, coords.z, 2, 1.0, true, false, 1.0)
	elseif action == "sky" then
		SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z + 120.0, false, false, false)
	elseif action == "randomTeleport" then
		local xOffset = math.random(-500, 500) + 0.0
		local yOffset = math.random(-500, 500) + 0.0
		SetEntityCoordsNoOffset(ped, coords.x + xOffset, coords.y + yOffset, coords.z + 40.0, false, false, false)
	elseif action == "nausea" then
		ShakeGameplayCam("DRUNK_SHAKE", 1.0)
		AnimpostfxPlay("DrugsMichaelAliensFight", 5000, false)
	end
end)

local function StopSpectate()
	ToggleNUIFocus(true)
	if not spectating then
		return
	end

	local ped = PlayerPedId()

	NetworkSetInSpectatorMode(false, ped)

	FreezeEntityPosition(ped, false)
	SetEntityVisible(ped, true, false)
	SetEntityCollision(ped, true, true)
	SetPlayerInvincible(PlayerId(), false)
	NetworkSetEntityInvisibleToNetwork(ped, false)

	if lastCoords then
		SetEntityCoords(ped, lastCoords)
	end

	spectating = false

	SendNUIMessage({
		action = "stopSpectate",
		data = true,
	})
end

function Spectate(targetId, targetCoords)
	ToggleNUIFocus(false)

	if spectating then
		StopSpectate()
		Wait(500)
	end

	local myPed = PlayerPedId()
	lastCoords = GetEntityCoords(myPed)

	FreezeEntityPosition(myPed, true)
	SetEntityVisible(myPed, false, false)
	SetEntityCollision(myPed, false, false)
	SetPlayerInvincible(PlayerId(), true)
	NetworkSetEntityInvisibleToNetwork(myPed, true)

	SetEntityCoordsNoOffset(myPed, targetCoords.x, targetCoords.y, targetCoords.z + 15.0, false, false, false)

	Wait(500)
	local targetPlayer = GetPlayerFromServerId(targetId)

	if targetPlayer == -1 then
		print("Spectate failed: player not streamed")
		return
	end

	local targetPed = GetPlayerPed(targetPlayer)

	if not DoesEntityExist(targetPed) then
		print("Spectate failed: ped missing")
		return
	end

	spectating = true
	NetworkSetInSpectatorMode(true, targetPed)

	CreateThread(function()
		while spectating do
			Wait(0)

			DisableFrontendThisFrame()

			if IsDisabledControlJustPressed(0, 322) and GetGameTimer() >= escCooldownUntil then
				escCooldownUntil = GetGameTimer() + 5000

				ESX.TriggerServerCallback("esx-adminmenu:server:spectate:stop", function(res)
					if not res or res.err then
						print("[esx-adminmenu]", res and res.err)
						return
					end

					StopSpectate()
				end)
			end
		end
	end)
end
