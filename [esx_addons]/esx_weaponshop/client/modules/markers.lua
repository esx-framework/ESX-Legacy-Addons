local nearbyZone = nil
local textShown = false

---Gets the nearby interactable weaponshop zone
---@return string|nil
function GetNearbyZone()
	return nearbyZone
end

---Draws markers and handles proximity detection
---@return number sleepTime
function DrawMarkersAndCheckProximity()
	local sleep = 1500
	local currentShop = nil
	local coords = GetEntityCoords(ESX.PlayerData.ped)

	for zoneName, zoneData in pairs(Config.Zones) do
		local posCount = #zoneData.Locations

		for i = 1, posCount do
			local location = zoneData.Locations[i]

			if Config.Type ~= -1 and #(coords - location) < Config.DrawDistance then
				currentShop = location
				sleep = 0

				if #(coords - currentShop) < Config.InteractionDistance then
					if not textShown then
						ESX.TextUI(TranslateCap('shop_menu_prompt', ESX.GetInteractKey()))
						textShown = true
						nearbyZone = zoneName
					end
				end

				DrawMarker(
					Config.Type,
					location.x, location.y, location.z,
					0.0, 0.0, 0.0,
					0.0, 0.0, 0.0,
					Config.Size.x, Config.Size.y, Config.Size.z,
					Config.Color.r, Config.Color.g, Config.Color.b, 100,
					false, true, 2, false, nil, nil, false
				)
			end
		end
	end

	if (not currentShop or IsUIOpen()) and textShown then
		textShown = false
		nearbyZone = nil
		ESX.HideUI()
	end

	if not currentShop and IsUIOpen() then
		CloseShop()
		nearbyZone = nil
	end

	return sleep
end
