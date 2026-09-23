-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

---Opens the nearby weaponshop, including license gating when enabled
local function OpenNearbyShop()
	local zoneName = GetNearbyZone()
	if not zoneName then
		return
	end

	local zone = Config.Zones[zoneName]
	if not zone then
		return
	end

	if Config.LicenseEnable and zone.Legal then
		xLib.callback('esx_license:checkLicense', false, function(hasWeaponLicense)
			if hasWeaponLicense then
				OpenShop(zoneName)
			else
				OpenBuyLicenseMenu(zoneName)
			end
		end, ESX.serverId, 'weapon')
	else
		OpenShop(zoneName)
	end
end

-- Register ESX interaction
xLib.interactions.register('open_weaponshop', function()
	OpenNearbyShop()
end, function()
	return GetNearbyZone() ~= nil and not IsUIOpen()
end)
