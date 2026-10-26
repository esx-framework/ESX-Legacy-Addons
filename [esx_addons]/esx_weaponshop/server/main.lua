-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

ESXCatalog.awaitReady()

---Handles license purchase requests from clients
xLib.callback.registerCompat('esx_weaponshop:buyLicense', function(source, cb, account)
	ProcessLicensePurchase(source, cb, account)
end)

---Handles weapon purchase requests from clients
xLib.callback.registerCompat('esx_weaponshop:buyWeapon', function(source, cb, weaponName, zone, account)
	ProcessWeaponPurchase(source, weaponName, zone, cb, account)
end)

---Handles weapon upgrade purchase requests from clients
xLib.callback.registerCompat('esx_weaponshop:buyUpgrade', function(source, cb, data, zone, account)
	ProcessWeaponUpgradePurchase(source, data, zone, cb, account)
end)
