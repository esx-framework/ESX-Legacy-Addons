-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local shopBlips = {}

---Creates blips for all shop locations
function CreateShopBlips()
	if not Config.Zones then
		DebugPrint('[^1ERROR^7] Config.Zones is nil - cannot create blips')
		return
	end

	for zoneName, zoneData in pairs(Config.Zones) do
		if zoneData.ShowBlip then
			local posCount = #zoneData.Pos

			for i = 1, posCount do
				local pos = zoneData.Pos[i]
				local blip = xLib.blips.create({
					coords = pos,
					sprite = zoneData.Type,
					scale = zoneData.Size,
					color = zoneData.Color,
					shortRange = true,
					label = zoneName
				})

				shopBlips[#shopBlips + 1] = blip
			end
		end
	end

	DebugPrint(('[^2INFO^7] Created ^5%s^7 shop blips'):format(#shopBlips))
end

---Removes all shop blips
function RemoveShopBlips()
	for i = 1, #shopBlips do
		xLib.blips.remove(shopBlips[i])
	end
	shopBlips = {}
end

-- Initialize blips after resource start (ensures Config is fully loaded)
AddEventHandler('onClientResourceStart', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		CreateShopBlips()
	end
end)
