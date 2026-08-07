---Backward compatibility layer for esx_shops

-- GetShopItems (deprecated, use Config.Zones directly)
exports('GetShopItems', function(zone)
	local zoneData = Config.Zones[zone]
	if not zoneData then return {} end
	return zoneData.Items
end)

-- GetShopCategories (deprecated)
exports('GetShopCategories', function(zone)
	local zoneData = Config.Zones[zone]
	if not zoneData then return {} end
	return zoneData.Categories or {}
end)

-- Legacy event: esx_shops:openShop (for external triggers)
RegisterNetEvent('esx_shops:openShop', function(zone)
	if not zone then
		DebugPrint('[^3WARNING^7] esx_shops:openShop called without zone parameter')
		return
	end
	-- This event is handled on client via the interaction system
	-- External resources can trigger this to force-open a shop
end)
