-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

---Handles license purchase requests from clients
xLib.callback.registerCompat('esx_weaponshop:buyLicense', function(source, cb)
	ProcessLicensePurchase(source, cb)
end)

---Handles weapon purchase requests from clients
xLib.callback.registerCompat('esx_weaponshop:buyWeapon', function(source, cb, weaponName, zone)
	ProcessWeaponPurchase(source, weaponName, zone, cb)
end)

---Handles weapon upgrade purchase requests from clients
xLib.callback.registerCompat('esx_weaponshop:buyUpgrade', function(source, cb, data, zone)
	ProcessWeaponUpgradePurchase(source, data, zone, cb)
end)
