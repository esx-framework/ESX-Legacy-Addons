---Validates player exists
---@param source number Player source
---@return table|nil xPlayer ESX player object or nil
function ValidatePlayer(source)
	local xPlayer = ESX.Player(source)
	if not xPlayer then
		return nil
	end
	return xPlayer
end

---Checks if player has required funds for the purchase
---@param xPlayer table ESX player object
---@param isBlackMarket boolean
---@param price number
---@return boolean
function CanPayForWeapon(xPlayer, isBlackMarket, price)
	if isBlackMarket then
		if xPlayer.getAccount('black_money').money < price then
			xPlayer.showNotification(TranslateCap('not_enough_black'))
			return false
		end

		return true
	end

	if xPlayer.getMoney() < price then
		xPlayer.showNotification(TranslateCap('not_enough'))
		return false
	end

	return true
end

---Deducts purchase amount from the corresponding account
---@param xPlayer table ESX player object
---@param isBlackMarket boolean
---@param price number
function TakeWeaponPayment(xPlayer, isBlackMarket, price)
	if isBlackMarket then
		xPlayer.removeAccountMoney('black_money', price, 'Black Weapons Deal')
	else
		xPlayer.removeMoney(price, 'Weapons Deal')
	end
end
