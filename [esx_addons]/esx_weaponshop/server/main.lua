---Handles license purchase requests from clients
ESX.RegisterServerCallback('esx_weaponshop:buyLicense', function(source, cb)
	ProcessLicensePurchase(source, cb)
end)

---Handles weapon purchase requests from clients
ESX.RegisterServerCallback('esx_weaponshop:buyWeapon', function(source, cb, weaponName, zone)
	ProcessWeaponPurchase(source, weaponName, zone, cb)
end)
