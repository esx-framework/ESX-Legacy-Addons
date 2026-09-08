CreateThread(function()
	RegisterWeaponShopMarkers()
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		if IsUIOpen() then
			CloseShop()
		end
	end
end)
