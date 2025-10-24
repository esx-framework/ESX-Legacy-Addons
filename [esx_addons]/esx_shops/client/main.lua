local DrawDistance = Config.DrawDistance
local MarkerType = Config.MarkerType
local MarkerSize = Config.MarkerSize
local MarkerColor = Config.MarkerColor

-- State management
local hasAlreadyEnteredMarker = false
local lastZone = nil
local currentAction = nil
local currentActionMsg = nil
local currentActionData = {}
local currentShop = nil
local uiOpen = false
local nuiReady = false

---Gets ESX theme colors from convars
---@return table Theme colors
local function GetESXThemeColors()
	return {
		primaryColor = GetConvar('esx:ui:primaryColor', '#AD0643'),
		secondaryColor = GetConvar('esx:ui:secondaryColor', '#1a1a1a'),
		backgroundColor = GetConvar('esx:ui:backgroundColor', '#0a0a0a'),
		accentColor = GetConvar('esx:ui:accentColor', '#ffffff'),
		logoUrl = GetConvar('esx:ui:logoUrl', '')
	}
end

-- NUI Ready Callback
RegisterNUICallback('ready', function(data, cb)
	cb({ theme = GetESXThemeColors() })
	nuiReady = true
end)

---Opens shop NUI
---@param zone string Shop zone name
local function OpenShop(zone)
	if uiOpen then
		print('[esx_shops] Shop already open')
		return
	end

	-- Wait for NUI to be ready
	if not nuiReady then
		print('[esx_shops] NUI not ready yet')
		ESX.ShowNotification('~r~Shop is still loading, please wait...')
		return
	end

	local zoneData = Config.Zones[zone]
	if not zoneData then return end

	local callbackReceived = false
	local defaultTaxRate = 0.19 -- Fallback tax rate

	-- Timeout handler: Open shop with default tax rate after 5 seconds
	SetTimeout(5000, function()
		if not callbackReceived then
			print('[^3WARNING^7] Tax rate callback timeout - using default rate')

			local shopData = {
				shopName = zone,
				items = zoneData.Items,
				categories = zoneData.Categories,
				taxRate = defaultTaxRate,
				taxMessage = nil
			}

			SetNuiFocus(true, true)
			SendNUIMessage({
				type = 'openShop',
				shopData = shopData
			})

			currentShop = zone
			uiOpen = true
		end
	end)

	-- Get player's dynamic tax rate based on job
	ESX.TriggerServerCallback('esx_shops:getTaxRate', function(taxRate, taxMessage)
		if callbackReceived then return end -- Prevent double-open if timeout fired
		callbackReceived = true

		local shopData = {
			shopName = zone,
			items = zoneData.Items,
			categories = zoneData.Categories,
			taxRate = taxRate,
			taxMessage = taxMessage
		}

		SetNuiFocus(true, true)
		SendNUIMessage({
			type = 'openShop',
			shopData = shopData
		})

		currentShop = zone
		uiOpen = true
	end)
end

---Closes shop NUI
local function CloseShop()
	SetNuiFocus(false, false)
	SendNUIMessage({
		type = 'closeShop'
	})

	currentShop = nil
	uiOpen = false
end

---Handles entering shop marker
---@param zone string Shop zone name
local function HasEnteredMarker(zone)
	currentAction = 'shop_menu'
	currentActionMsg = ('Press [~b~E~s~] to access the ~g~%s~s~.'):format(zone)
	currentActionData = {zone = zone}
end

---Handles exiting shop marker
---@param zone string Shop zone name
local function HasExitedMarker(zone)
	currentAction = nil
	if uiOpen then
		CloseShop()
	end
end

-- NUI Callbacks
RegisterNUICallback('purchaseItems', function(data, cb)
	if not currentShop then
		cb({
			ok = false,
			error = {
				code = 'CLIENT',
				message = 'No shop selected'
			}
		})
		return
	end

	-- Wait for validation result
	ESX.TriggerServerCallback('esx_shops:purchaseItems', function(success, message)
		if success then
			cb({
				ok = true,
				data = {message = message}
			})
		else
			cb({
				ok = false,
				error = {
					code = 'SERVER',
					message = message
				}
			})
		end
	end, data, currentShop)
end)

RegisterNUICallback('closeUI', function(data, cb)
	CloseShop()
	cb('ok')
end)

-- Create blips for all shop locations
CreateThread(function()
	for zoneName, zoneData in pairs(Config.Zones) do
		if zoneData.ShowBlip then
			local posCount = #zoneData.Pos

			for i = 1, posCount do
				local pos = zoneData.Pos[i]
				local blip = AddBlipForCoord(pos.x, pos.y, pos.z)

				SetBlipSprite(blip, zoneData.Type)
				SetBlipScale(blip, zoneData.Size)
				SetBlipColour(blip, zoneData.Color)
				SetBlipAsShortRange(blip, true)

				BeginTextCommandSetBlipName('STRING')
				AddTextComponentSubstringPlayerName(zoneName)
				EndTextCommandSetBlipName(blip)
			end
		end
	end
end)

-- Nearby shops cache for performance optimization
local nearbyShops = {}
local lastPlayerPos = nil
local MOVEMENT_THRESHOLD = 5.0 -- Only recalculate if player moved 5+ meters

-- Background thread: Find nearby shops every 500ms (or when player moves significantly)
CreateThread(function()
	while true do
		local playerCoords = GetEntityCoords(ESX.PlayerData.ped)
		local shouldUpdate = false

		-- Check if player moved significantly since last update
		if not lastPlayerPos then
			shouldUpdate = true
		else
			local movement = #(playerCoords - lastPlayerPos)
			if movement > MOVEMENT_THRESHOLD then
				shouldUpdate = true
			end
		end

		if shouldUpdate then
			local nearby = {}

			-- Check all zones for proximity
			for zoneName, zoneData in pairs(Config.Zones) do
				local posCount = #zoneData.Pos

				for i = 1, posCount do
					local pos = zoneData.Pos[i]
					local distance = #(playerCoords - pos)

					-- Only track shops within draw distance
					if distance < DrawDistance then
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
		end

		Wait(500) -- Update every 500ms
	end
end)

-- Main marker drawing thread: Draw markers every frame for nearby shops only
CreateThread(function()
	while true do
		local sleep = 1500
		local playerCoords = GetEntityCoords(ESX.PlayerData.ped)
		local isInMarker = false
		local currentZone = nil
		local closestDistance = 9999.0

		-- Only process nearby shops
		for zoneName, locations in pairs(nearbyShops) do
			local zoneData = Config.Zones[zoneName]
			if not zoneData then goto continue end

			for _, shopData in ipairs(locations) do
				local pos = shopData.pos
				local distance = shopData.distance

				-- Track closest shop for sleep optimization
				if distance < closestDistance then
					closestDistance = distance
				end

				-- Draw marker if enabled and within 50 units (performance optimization)
				if zoneData.ShowMarker and distance < 50.0 then
					DrawMarker(
						MarkerType,
						pos.x, pos.y, pos.z,
						0.0, 0.0, 0.0,
						0.0, 0.0, 0.0,
						MarkerSize.x, MarkerSize.y, MarkerSize.z,
						MarkerColor.r, MarkerColor.g, MarkerColor.b, MarkerColor.a,
						false, true, 2, false, nil, nil, false
					)
				end

				-- Check interaction distance
				if distance < 2.0 then
					isInMarker = true
					currentZone = zoneName
					lastZone = zoneName
				end
			end

			::continue::
		end

		-- Dynamic sleep based on distance to closest shop (sleep = 0 for anything < 50m)
		if closestDistance < 50.0 then
			sleep = 0 -- Draw every frame when within 50m
		elseif closestDistance < 100.0 then
			sleep = 500 -- Slow down when 50-100m away
		else
			sleep = 1500 -- Very slow when far away
		end

		-- Handle marker enter/exit
		if isInMarker and not hasAlreadyEnteredMarker then
			hasAlreadyEnteredMarker = true
			HasEnteredMarker(currentZone)
			ESX.TextUI(currentActionMsg)
		end

		if not isInMarker and hasAlreadyEnteredMarker then
			hasAlreadyEnteredMarker = false
			ESX.HideUI()
			HasExitedMarker(lastZone)
		end

		Wait(sleep)
	end
end)

-- Register interaction (E key)
ESX.RegisterInteraction('shop_menu', function()
	if currentActionData and currentActionData.zone then
		OpenShop(currentActionData.zone)
	end
end, function()
	return currentAction and currentAction == 'shop_menu'
end)
