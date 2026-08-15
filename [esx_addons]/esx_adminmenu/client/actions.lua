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
local vehicleLevels = { engine = 1, brake = 1, transmission = 1, suspension = 1, armor = 1 }
local vehicleColorIndex = 1
local neonColorIndex = 1
local runningLoops = {}

local MOD = {
	engine = 11,
	brakes = 12,
	transmission = 13,
	suspension = 15,
	armor = 16,
	turbo = 18,
	xenon = 22,
	wheelFront = 23,
	wheelRear = 24,
}

local CONTROL = {
	sprint = 21,
	slow = 36,
	moveLeftRight = 30,
	moveUpDown = 31,
	moveForward = 32,
	moveBackward = 33,
	moveLeft = 34,
	moveRight = 35,
	up = 22,
	down = 44,
	exitVehicle = 75,
}

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

local function trimString(value)
	return Helpers.trim(value)
end

local function requestModel(model, options)
	return Helpers.loadModel(model, options)
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

	local frontCount = GetNumVehicleMods(vehicle, MOD.wheelFront)
	if frontCount > 0 then
		local frontIndex = math.max(-1, math.min(wheelDesign, frontCount - 1))
		SetVehicleMod(vehicle, MOD.wheelFront, frontIndex, false)
	end

	local rearCount = GetNumVehicleMods(vehicle, MOD.wheelRear)
	if rearCount > 0 then
		local rearIndex = math.max(-1, math.min(wheelDesign, rearCount - 1))
		SetVehicleMod(vehicle, MOD.wheelRear, rearIndex, false)
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

	local engineLevel = applyVehicleModLevel(vehicle, MOD.engine, useMaxPerformance and 5 or data.engineLevel or vehicleLevels.engine)
	local brakeLevel = applyVehicleModLevel(vehicle, MOD.brakes, useMaxPerformance and 5 or data.brakeLevel or vehicleLevels.brake)
	local transmissionLevel = applyVehicleModLevel(vehicle, MOD.transmission, useMaxPerformance and 5 or data.transmissionLevel or vehicleLevels.transmission)
	local suspensionLevel = applyVehicleModLevel(vehicle, MOD.suspension, useMaxPerformance and 5 or data.suspensionLevel or vehicleLevels.suspension)
	local armorLevel = applyVehicleModLevel(vehicle, MOD.armor, useMaxPerformance and 5 or data.armorLevel or vehicleLevels.armor)

	vehicleLevels.engine = engineLevel
	vehicleLevels.brake = brakeLevel
	vehicleLevels.transmission = transmissionLevel
	vehicleLevels.suspension = suspensionLevel
	vehicleLevels.armor = armorLevel

	if useMaxPerformance then
		ToggleVehicleMod(vehicle, MOD.turbo, true)
	end

	if data.turbo ~= nil then
		ToggleVehicleMod(vehicle, MOD.turbo, data.turbo == true)
	end

	if data.xenon ~= nil then
		ToggleVehicleMod(vehicle, MOD.xenon, data.xenon == true)
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
		transmissionLevel = maxPerformance and 5 or vehicleLevels.transmission,
		suspensionLevel = maxPerformance and 5 or vehicleLevels.suspension,
		armorLevel = maxPerformance and 5 or vehicleLevels.armor,
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

-- Per-flag ped-state restore helpers. Reused by the normal toggle-off paths and
-- by the onResourceStop teardown so the local player is always cleaned up.
local function restoreVisibility(ped)
	ped = ped or PlayerPedId()
	SetEntityVisible(ped, true, false)
	NetworkSetEntityInvisibleToNetwork(ped, false)
end

local function restoreInvincibility(ped)
	ped = ped or PlayerPedId()
	SetPlayerInvincible(PlayerId(), false)
	SetEntityInvincible(ped, false)
end

local function restoreNoClip(entity)
	setNoClipEntityState(entity, false)
end

local function restoreInfiniteAmmo(ped)
	ped = ped or PlayerPedId()
	SetPedInfiniteAmmoClip(ped, false)
end

local function clearPlayerBlips()
	for serverId, blip in pairs(playerBlips) do
		if DoesBlipExist(blip) then
			RemoveBlip(blip)
		end
		playerBlips[serverId] = nil
	end
end

local function restoreSpectatePed()
	local ped = PlayerPedId()

	FreezeEntityPosition(ped, false)
	SetEntityCollision(ped, true, true)
	restoreVisibility(ped)
	SetPlayerInvincible(PlayerId(), false)

	if lastCoords then
		SetEntityCoords(ped, lastCoords)
	end
end

-- Shared toggle-loop runner: refuses to start a second loop of the same name,
-- ticks while isActiveFn() is true, then runs onStop once and clears the flag.
local function startToggleLoop(name, isActiveFn, interval, onTick, onStop)
	if runningLoops[name] then
		return
	end

	runningLoops[name] = true

	CreateThread(function()
		while isActiveFn() do
			onTick()
			Wait(interval)
		end

		if onStop then
			onStop()
		end

		runningLoops[name] = nil
	end)
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
	startToggleLoop("godmodeVehicle", function()
		return godmodeActive
	end, 500, function()
		applyGodmodeVehicle(GetVehiclePedIsIn(PlayerPedId(), false))
	end, function()
		applyGodmodeVehicle(0)
	end)
end

local function watchInvisibleVehicle()
	startToggleLoop("invisibleVehicle", function()
		return invisibleActive
	end, 500, function()
		applyInvisibleVehicle(GetVehiclePedIsIn(PlayerPedId(), false))
	end, function()
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
	local entity, ped = getControlledEntity()
	noClipEntity = entity
	setNoClipEntityState(entity, true)

	startToggleLoop("noclip", function()
		return noClipActive
	end, 0, function()
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

		if IsDisabledControlPressed(0, CONTROL.sprint) then
			speed = speed * 3.0
		elseif IsDisabledControlPressed(0, CONTROL.slow) then
			speed = speed * 0.35
		end

		DisableControlAction(0, CONTROL.moveLeftRight, true)
		DisableControlAction(0, CONTROL.moveUpDown, true)
		DisableControlAction(0, CONTROL.moveForward, true)
		DisableControlAction(0, CONTROL.moveBackward, true)
		DisableControlAction(0, CONTROL.moveLeft, true)
		DisableControlAction(0, CONTROL.moveRight, true)
		DisableControlAction(0, CONTROL.up, true)
		DisableControlAction(0, CONTROL.down, true)
		DisableControlAction(0, CONTROL.exitVehicle, true)

		if IsDisabledControlPressed(0, CONTROL.moveForward) then
			coords = coords + forward * speed
		end
		if IsDisabledControlPressed(0, CONTROL.moveBackward) then
			coords = coords - forward * speed
		end
		if IsDisabledControlPressed(0, CONTROL.moveLeft) then
			coords = coords - right * speed
		end
		if IsDisabledControlPressed(0, CONTROL.moveRight) then
			coords = coords + right * speed
		end
		if IsDisabledControlPressed(0, CONTROL.up) then
			coords = coords + vector3(0.0, 0.0, speed)
		end
		if IsDisabledControlPressed(0, CONTROL.down) then
			coords = coords - vector3(0.0, 0.0, speed)
		end

		SetEntityCoordsNoOffset(entity, coords.x, coords.y, coords.z, true, true, true)
		SetEntityHeading(entity, GetGameplayCamRot(0).z)
	end, function()
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
		startToggleLoop("infiniteAmmo", function()
			return infiniteAmmoActive
		end, 500, function()
			SetPedInfiniteAmmoClip(PlayerPedId(), true)
		end, function()
			restoreInfiniteAmmo()
		end)
	end

	return infiniteAmmoActive
end

function ClientActions.ToggleNames()
	namesActive = not namesActive

	if namesActive then
		startToggleLoop("names", function()
			return namesActive
		end, 0, function()
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
		end)
	end

	return namesActive
end

function ClientActions.ToggleBlips()
	blipsActive = not blipsActive

	if not blipsActive then
		clearPlayerBlips()

		return false
	end

	startToggleLoop("blips", function()
		return blipsActive
	end, 1500, function()
		local blipConfig = (Config.AdminMenu and Config.AdminMenu.Blip) or {}
		local activeServerIds = {}

		for _, player in ipairs(GetActivePlayers()) do
			if player ~= PlayerId() then
				local ped = GetPlayerPed(player)
				local serverId = GetPlayerServerId(player)
				activeServerIds[serverId] = true

				if ped ~= 0 and DoesEntityExist(ped) then
					if not playerBlips[serverId] or not DoesBlipExist(playerBlips[serverId]) then
						local blip = AddBlipForEntity(ped)
						SetBlipSprite(blip, blipConfig.sprite or 1)
						SetBlipScale(blip, blipConfig.scale or 0.85)
						SetBlipColour(blip, blipConfig.colour or 5)
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

	local modelHash, err = requestModel(model, { requireVehicle = true })
	if not modelHash then
		return false, err or "Invalid vehicle model."
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

local function makeCycle(key, applyFn)
	return function()
		local vehicle, err = getCurrentVehicle()
		if not vehicle then
			return false, err
		end

		vehicleLevels[key] = vehicleLevels[key] % 5 + 1
		applyFn(vehicle)

		return true, nil, { active = true, value = ("%s/5"):format(vehicleLevels[key]) }
	end
end

ClientActions.CycleVehicleEngine = makeCycle("engine", function(vehicle)
	applyVehiclePerformance(vehicle, vehicleLevels.engine, vehicleLevels.brake, false)
end)

ClientActions.CycleVehicleBrakes = makeCycle("brake", function(vehicle)
	applyVehiclePerformance(vehicle, vehicleLevels.engine, vehicleLevels.brake, false)
end)

ClientActions.CycleVehicleTransmission = makeCycle("transmission", function(vehicle)
	applyVehicleCustomizations(vehicle, { transmissionLevel = vehicleLevels.transmission })
end)

ClientActions.CycleVehicleSuspension = makeCycle("suspension", function(vehicle)
	applyVehicleCustomizations(vehicle, { suspensionLevel = vehicleLevels.suspension })
end)

ClientActions.CycleVehicleArmor = makeCycle("armor", function(vehicle)
	applyVehicleCustomizations(vehicle, { armorLevel = vehicleLevels.armor })
end)

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

	local scan = (Config.AdminMenu and Config.AdminMenu.WaypointScan) or {}
	local maxHeight = scan.max or 1000
	local step = scan.step or 25

	for height = 0, maxHeight, step do
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

local TROLL = {
	burn = function(ped, coords)
		StartEntityFire(ped)
	end,
	explode = function(ped, coords)
		AddExplosion(coords.x, coords.y, coords.z, 2, 1.0, true, false, 1.0)
	end,
	sky = function(ped, coords)
		local skyHeight = (Config.AdminMenu and Config.AdminMenu.Troll and Config.AdminMenu.Troll.skyHeight) or 120.0
		SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z + skyHeight, false, false, false)
	end,
	randomTeleport = function(ped, coords)
		local troll = (Config.AdminMenu and Config.AdminMenu.Troll) or {}
		local range = troll.randomRange or 500
		local height = troll.randomHeight or 40.0
		local xOffset = math.random(-range, range) + 0.0
		local yOffset = math.random(-range, range) + 0.0
		SetEntityCoordsNoOffset(ped, coords.x + xOffset, coords.y + yOffset, coords.z + height, false, false, false)
	end,
	nausea = function(ped, coords)
		local duration = (Config.AdminMenu and Config.AdminMenu.Troll and Config.AdminMenu.Troll.nauseaDuration) or 5000
		ShakeGameplayCam("DRUNK_SHAKE", 1.0)
		AnimpostfxPlay("DrugsMichaelAliensFight", duration, false)
	end,
}

RegisterNetEvent("esx-adminmenu:client:troll", function(action)
	local handler = TROLL[action]
	if not handler then
		return
	end

	local ped = PlayerPedId()
	local coords = GetEntityCoords(ped)

	handler(ped, coords)
end)

-- Reapply active self-toggles after the ped handle changes on respawn.
RegisterNetEvent("esx:onPlayerSpawn", function()
	local ped = PlayerPedId()

	if godmodeActive then
		SetEntityInvincible(ped, true)
	end

	if invisibleActive then
		SetEntityVisible(ped, false, false)
		NetworkSetEntityInvisibleToNetwork(ped, true)
	end

	if infiniteAmmoActive then
		SetPedInfiniteAmmoClip(ped, true)
	end
end)

local function StopSpectate()
	ToggleNUIFocus(true)
	if not spectating then
		return
	end

	local ped = PlayerPedId()

	NetworkSetInSpectatorMode(false, ped)

	restoreSpectatePed()

	spectating = false

	SendNUIMessage({
		action = "stopSpectate",
		data = true,
	})
end

function Spectate(targetId, targetCoords)
	ToggleNUIFocus(false)

	local spectateConfig = (Config.AdminMenu and Config.AdminMenu.Spectate) or {}
	local spectateHeight = spectateConfig.height or 15.0
	local escCooldown = spectateConfig.escCooldown or 5000
	local streamWait = spectateConfig.streamWait or 500

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

	SetEntityCoordsNoOffset(myPed, targetCoords.x, targetCoords.y, targetCoords.z + spectateHeight, false, false, false)

	Wait(streamWait)
	local targetPlayer = GetPlayerFromServerId(targetId)

	if targetPlayer == -1 then
		print("Spectate failed: player not streamed")
		restoreSpectatePed()
		return
	end

	local targetPed = GetPlayerPed(targetPlayer)

	if not DoesEntityExist(targetPed) then
		print("Spectate failed: ped missing")
		restoreSpectatePed()
		return
	end

	spectating = true
	NetworkSetInSpectatorMode(true, targetPed)

	CreateThread(function()
		while spectating do
			Wait(0)

			local currentTarget = GetPlayerFromServerId(targetId)
			if currentTarget == -1 or not DoesEntityExist(GetPlayerPed(currentTarget)) then
				StopSpectate()
				break
			end

			DisableFrontendThisFrame()

			if IsDisabledControlJustPressed(0, 322) and GetGameTimer() >= escCooldownUntil then
				escCooldownUntil = GetGameTimer() + escCooldown

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

AddEventHandler("onResourceStop", function(resource)
	if resource ~= GetCurrentResourceName() then
		return
	end

	local ped = PlayerPedId()

	if spectating then
		StopSpectate()
	end

	restoreVisibility(ped)
	restoreInvincibility(ped)
	restoreNoClip(ped)
	restoreInfiniteAmmo(ped)
	clearPlayerBlips()
	SetNuiFocus(false, false)
	SetNuiFocusKeepInput(false)
end)
