-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local nearbyZone = nil
local textShown = false
local markerZones = {}

---Gets the nearby interactable weaponshop zone
---@return string|nil
function GetNearbyZone()
	return nearbyZone
end

function RegisterWeaponShopMarkers()
	if Config.Type == -1 or not Config.Zones then
		return
	end

	local drawDistance = tonumber(Config.DrawDistance) or 10.0
	local interactionDistance = tonumber(Config.InteractionDistance) or 2.0

	for zoneName, zoneData in pairs(Config.Zones) do
		local locations = zoneData.Locations
		local posCount = type(locations) == 'table' and #locations or 0

		for i = 1, posCount do
			markerZones[#markerZones + 1] = xLib.markerZone.create({
				coords = locations[i],
				drawDistance = drawDistance,
				interactDistance = interactionDistance,
				marker = {
					type = Config.Type,
					size = Config.Size,
					color = {
						r = Config.Color.r,
						g = Config.Color.g,
						b = Config.Color.b,
						a = 100
					}
				},
				onEnter = function()
					nearbyZone = zoneName

					if not IsUIOpen() and not textShown then
						ESX.TextUI(TranslateCap('shop_menu_prompt', Config.InteractionKeyLabel or 'E'))
						textShown = true
					end
				end,
				onExit = function()
					if nearbyZone == zoneName then
						nearbyZone = nil
					end

					if textShown then
						textShown = false
						ESX.HideUI()
					end

					if IsUIOpen() then
						CloseShop()
					end
				end
			})
		end
	end
end

function RemoveWeaponShopMarkers()
	for i = 1, #markerZones do
		if markerZones[i] and markerZones[i].remove then
			markerZones[i].remove()
		end
	end

	markerZones = {}
	nearbyZone = nil
	textShown = false
end
