-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local isNear, TextUIdrawing = false, false

---Backwards compatible wrapper for the joblisting menu
function ShowJobListingMenu()
	JobListingUI.Open()
end

-- Activate menu when player is inside marker, and draw markers
CreateThread(function()
	while true do
		local Sleep = 1000

		local coords = GetEntityCoords(ESX.PlayerData.ped)
		local isInMarker = false
		local isNearMarker = false

		for i = 1, #Config.Zones, 1 do
			local distance = #(coords - Config.Zones[i])

			if distance < Config.DrawDistance then
				Sleep = 0
				isInMarker = true

				DrawMarker(Config.MarkerType, Config.Zones[i].x, Config.Zones[i].y, Config.Zones[i].z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, Config.ZoneSize.x, Config.ZoneSize.y, Config.ZoneSize.z,
				Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, 100, false, true, 2, false, false, false, false)

				if distance < (Config.ZoneSize.x / 2) then
					isNearMarker = true
				end
			end
		end

		isNear = isNearMarker

		if isNear and not TextUIdrawing and not JobListingUI.IsOpen() then
			ESX.TextUI(TranslateCap('access_job_center', xLib.interactions.getInteractKey()))
			TextUIdrawing = true
		end

		if ((isInMarker and not isNear) or not isInMarker) and TextUIdrawing then
			ESX.HideUI()
			TextUIdrawing = false
		end

		if not isInMarker and JobListingUI.IsOpen() then
			JobListingUI.Close()
		end

		Wait(Sleep)
	end
end)

-- Create blips
if Config.Blip.Enabled then
	CreateThread(function()
		for i = 1, #Config.Zones, 1 do
			xLib.blips.create({
				coords = Config.Zones[i],
				sprite = Config.Blip.Sprite,
				display = Config.Blip.Display,
				scale = Config.Blip.Scale,
				color = Config.Blip.Colour,
				shortRange = Config.Blip.ShortRange,
				label = TranslateCap('blip_text')
			})
		end
	end)
end

xLib.interactions.register("open_joblisting", function()
	ShowJobListingMenu()
end, function()
	return isNear and not JobListingUI.IsOpen()
end)