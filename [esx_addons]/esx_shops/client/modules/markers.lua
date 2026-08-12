local nearbyShops = {}
local lastPlayerPos = nil
local hasAlreadyEnteredMarker = false
local lastZone = nil

-- Distance thresholds
local ENTER_DISTANCE = 2.0
local EXIT_DISTANCE = 2.5

-- Exports for other modules
ShopMarkers = {
	nearbyShops = nearbyShops,
	hasAlreadyEnteredMarker = hasAlreadyEnteredMarker,
	lastZone = lastZone
}

---Updates the nearby shops cache based on player position
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

---Recalculates live distance for a position (used when precision matters)
---@param pos vector3
---@return number liveDistance
function GetLiveDistance(pos)
	local playerCoords = GetEntityCoords(ESX.PlayerData.ped)
	return #(playerCoords - pos)
end

---Draws markers and handles proximity detection with hysteresis
---Uses cached distances for markers, but recalculates live distance for interaction checks
---@return number sleepTime
---@return boolean isInMarker
---@return string|nil currentZone
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
				local cachedDistance = shopData.distance

				if cachedDistance < closestDistance then
					closestDistance = cachedDistance
				end

				if zoneData.ShowMarker and cachedDistance < 50.0 then
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

				-- For interaction checks, use LIVE distance to prevent stale cache issues
				local liveDistance = GetLiveDistance(pos)

				if hasAlreadyEnteredMarker then
					if liveDistance < EXIT_DISTANCE then
						isInMarker = true
						currentZone = zoneName
						lastZone = zoneName
					end
				else
					if liveDistance < ENTER_DISTANCE then
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

---Gets the last zone the player was in
---@return string|nil
function GetLastZone()
	return lastZone
end

---Sets the entered marker state
---@param state boolean
function SetEnteredMarker(state)
	hasAlreadyEnteredMarker = state
	ShopMarkers.hasAlreadyEnteredMarker = state
end

---Gets the entered marker state
---@return boolean
function GetMarkerState()
	return hasAlreadyEnteredMarker
end
