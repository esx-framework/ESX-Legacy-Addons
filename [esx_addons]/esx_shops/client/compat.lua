RegisterNetEvent('esx_shops:forceOpenShop', function(zone)
	if Config.Zones[zone] then
		OpenShop(zone)
	end
end)

exports('IsShopOpen', function()
	return IsUIOpen()
end)

exports('GetCurrentShop', function()
	return GetCurrentShop()
end)
