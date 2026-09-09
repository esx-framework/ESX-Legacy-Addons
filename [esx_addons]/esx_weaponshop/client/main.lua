-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

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
