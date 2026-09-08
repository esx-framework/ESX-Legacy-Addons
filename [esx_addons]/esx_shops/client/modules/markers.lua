local markerZones = {}
local lastZone = nil

local ENTER_DISTANCE = 2.0
local EXIT_DISTANCE = 2.5

local function createMarkerOptions()
	if Config.MarkerType == -1 then
		return false
	end

	return {
		type = Config.MarkerType,
		size = Config.MarkerSize,
		color = Config.MarkerColor,
		a = Config.MarkerColor.a
	}
end

function RegisterShopMarkers()
	if not Config.Zones then
		DebugPrint('[^1ERROR^7] Config.Zones is nil - cannot create markers')
		return
	end

	for zoneName, zoneData in pairs(Config.Zones) do
		local posCount = type(zoneData.Pos) == 'table' and #zoneData.Pos or 0

		for i = 1, posCount do
			markerZones[#markerZones + 1] = xLib.markerZone.create({
				coords = zoneData.Pos[i],
				drawDistance = Config.DrawDistance,
				interactDistance = ENTER_DISTANCE,
				exitDistance = EXIT_DISTANCE,
				marker = zoneData.ShowMarker and createMarkerOptions() or false,
				onEnter = function()
					lastZone = zoneName
					OnMarkerEnter(zoneName)

					local msg = GetCurrentActionMsg()
					if msg then
						ESX.TextUI(msg)
					end
				end,
				onExit = function()
					ESX.HideUI()
					OnMarkerExit(zoneName)
				end
			})
		end
	end
end

---@return string|nil
function GetLastZone()
	return lastZone
end

function RemoveShopMarkers()
	for i = 1, #markerZones do
		if markerZones[i] and markerZones[i].remove then
			markerZones[i].remove()
		end
	end

	markerZones = {}
	lastZone = nil
end
