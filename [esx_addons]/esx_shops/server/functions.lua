---Validates player exists
---@param source number Player source
---@return table|nil xPlayer ESX player object or nil
function ValidatePlayer(source)
	local xPlayer = ESX.Player(source)
	if not xPlayer then
		DebugPrint(_U('invalid_player', source))
	end
	return xPlayer
end

---Validates zone exists
---@param zone string Zone name
---@param source number Player source for logging
---@return boolean valid
function ValidateZone(zone, source)
	if not Config.Zones[zone] then
		DebugPrint(_U('invalid_zone', source, zone))
		return false
	end
	return true
end

---Validates payment method
---@param method string Payment method
---@param source number Player source for logging
---@return boolean valid
function ValidatePaymentMethod(method, source)
	if method ~= 'cash' and method ~= 'bank' then
		DebugPrint(_U('invalid_payment_method', source, method))
		return false
	end
	return true
end

---Checks if player has enough money
---@param xPlayer table ESX player object
---@param paymentMethod string Payment method ('cash' or 'bank')
---@param total number Total amount needed
---@return boolean hasEnough
---@return number missingAmount
function CheckPlayerMoney(xPlayer, paymentMethod, total)
	local currentMoney = 0

	if paymentMethod == 'cash' then
		currentMoney = xPlayer.getMoney()
	elseif paymentMethod == 'bank' then
		local bankAccount = xPlayer.getAccount('bank')
		currentMoney = bankAccount and bankAccount.money or 0
	end

	local hasEnough = currentMoney >= total
	local missingAmount = hasEnough and 0 or (total - currentMoney)

	return hasEnough, missingAmount
end

---Deducts money from player
---@param xPlayer table ESX player object
---@param paymentMethod string Payment method ('cash' or 'bank')
---@param amount number Amount to deduct
function DeductMoney(xPlayer, paymentMethod, amount)
	if paymentMethod == 'cash' then
		xPlayer.removeMoney(amount, 'Shop Purchase')
	elseif paymentMethod == 'bank' then
		xPlayer.removeAccountMoney('bank', amount, 'Shop Purchase')
	end
end
