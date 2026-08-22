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
		ESX.TriggerServerCallback('esx_license:checkLicense', function(hasWeaponLicense)
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
ESX.RegisterInteraction('open_weaponshop', function()
	OpenNearbyShop()
end, function()
	return GetNearbyZone() ~= nil and not IsUIOpen()
end)
