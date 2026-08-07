local nearbyShops = {}
local lastPlayerPos = nil
local hasAlreadyEnteredMarker = false
local lastZone = nil

local ENTER_DISTANCE = 2.0
local EXIT_DISTANCE = 2.5

ShopMarkers = {
	nearbyShops = nearbyShops,
	hasAlreadyEnteredMarker = hasAlreadyEnteredMarker,
	lastZone = lastZone
}

function UpdateNearbyShops()
	local playerCoords = GetEntityCoords(ESX.PlayerData.ped)
	local shouldUpdate = false

	if not lastPlayerPos then
		shouldUpdate = true
	else
		local movement = #(playerCoords - lastPlayerPos)
		if movement > Config.MovementThreshold then
			shouldUpdate = true
		end
	end

	if not shouldUpdate then return end

	local nearby = {}

	for zoneName, zoneData in pairs(Config.Zones) do
		local posCount = #zoneData.Pos

		for i = 1, posCount do
			local pos = zoneData.Pos[i]
			local distance = #(playerCoords - pos)

			if distance < Config.DrawDistance then
				if not nearby[zoneName] then
					nearby[zoneName] = {}
				end
				nearby[zoneName][#nearby[zoneName] + 1] = {
					pos = pos,
					distance = distance,
					index = i
				}
			end
		end
	end

	nearbyShops = nearby
	lastPlayerPos = playerCoords
	ShopMarkers.nearbyShops = nearbyShops
end

function DrawMarkersAndCheckProximity()
	local sleep = Config.SleepFar
	local playerCoords = GetEntityCoords(ESX.PlayerData.ped)
	local isInMarker = false
	local currentZone = nil
	local closestDistance = 9999.0

	for zoneName, locations in pairs(nearbyShops) do
		local zoneData = Config.Zones[zoneName]
		if zoneData then
			for _, shopData in ipairs(locations) do
				local pos = shopData.pos
				local distance = shopData.distance

				if distance < closestDistance then
					closestDistance = distance
				end

				if zoneData.ShowMarker and distance < 50.0 then
					DrawMarker(
						Config.MarkerType,
						pos.x, pos.y, pos.z,
						0.0, 0.0, 0.0,
						0.0, 0.0, 0.0,
						Config.MarkerSize.x, Config.MarkerSize.y, Config.MarkerSize.z,
						Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, Config.MarkerColor.a,
						false, true, 2, false, nil, nil, false
					)
				end

				if hasAlreadyEnteredMarker then
					if distance < EXIT_DISTANCE then
						isInMarker = true
						currentZone = zoneName
						lastZone = zoneName
					end
				else
					if distance < ENTER_DISTANCE then
						isInMarker = true
						currentZone = zoneName
						lastZone = zoneName
					end
				end
			end
		end
	end

	if closestDistance < 50.0 then
		sleep = Config.SleepNear
	elseif closestDistance < 100.0 then
		sleep = Config.SleepMedium
	end

	return sleep, isInMarker, currentZone
end

function GetLastZone()
	return lastZone
end

function SetEnteredMarker(state)
	hasAlreadyEnteredMarker = state
	ShopMarkers.hasAlreadyEnteredMarker = state
end

function GetMarkerState()
	return hasAlreadyEnteredMarker
end