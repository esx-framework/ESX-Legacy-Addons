---Handles weapon license purchase requests
---@param source number Player source
---@param cb function Callback function(success)
function ProcessLicensePurchase(source, cb)
	local xPlayer = ValidatePlayer(source)

	if not xPlayer then
		cb(false)
		return
	end

	if xPlayer.getMoney() < Config.LicensePrice then
		xPlayer.showNotification(TranslateCap('not_enough'))
		cb(false)
		return
	end

	xPlayer.removeMoney(Config.LicensePrice, 'Weapon License')

	TriggerEvent('esx_license:addLicense', source, 'weapon', function()
		cb(true)
	end)
end

---Handles weapon purchase requests from clients
---@param source number Player source
---@param weaponName string
---@param zone string Shop zone
---@param cb function Callback function(success)
function ProcessWeaponPurchase(source, weaponName, zone, cb)
	local xPlayer = ValidatePlayer(source)

	if not xPlayer then
		cb(false)
		return
	end

	if not ValidateZone(zone, source) then
		cb(false)
		return
	end

	local price = GetPrice(weaponName, zone)

	if price <= 0 then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to buy Invalid weapon - %s!'):format(
			source,
			weaponName
		))
		cb(false)
		return
	end

	local isBlackMarket = zone == 'BlackWeashop'

	if not CanReceiveWeapon(source, xPlayer, weaponName) then
		cb(false)
		return
	end

	if not CanPayForWeapon(xPlayer, isBlackMarket, price) then
		cb(false)
		return
	end

	TakeWeaponPayment(xPlayer, isBlackMarket, price)

	if not AddWeapon(source, xPlayer, weaponName) then
		cb(false)
		return
	end

	cb(true)
end
