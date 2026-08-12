---Validates player exists
---@param source number Player source
---@return table|nil xPlayer ESX player object or nil
function ValidatePlayer(source)
	if not Verify(source, {'number', 'string'}) then
		DebugPrint(_U('invalid_player', 'unknown'))
		return nil
	end

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
	if not Verify(zone, 'string') then
		DebugPrint(_U('invalid_zone', source or 'unknown', tostring(zone)))
		return false
	end
	if not Config.Zones[zone] then
		DebugPrint(_U('invalid_zone', source or 'unknown', zone))
		return false
	end
	return true
end

---Validates payment method
---@param method string Payment method
---@param source number Player source for logging
---@return boolean valid
function ValidatePaymentMethod(method, source)
	if not Verify(method, 'string') or (method ~= 'cash' and method ~= 'bank') then
		DebugPrint(_U('invalid_payment_method', source or 'unknown', tostring(method)))
		return false
	end
	return true
end

---Checks if player is within interaction distance of any shop in the zone
---@param source number Player source
---@param zone string Zone name
---@return boolean isNearby
function ValidatePlayerDistance(source, zone)
	if not Verify(source, {'number', 'string'}) or not Verify(zone, 'string') then
		return false
	end

	local zoneData = Config.Zones[zone]
	if not zoneData then return false end

	local ped = GetPlayerPed(source)
	if not ped or ped == 0 then return false end

	local playerCoords = GetEntityCoords(ped)
	local posCount = #zoneData.Pos
	local maxDist = 5.0

	for i = 1, posCount do
		local pos = zoneData.Pos[i]
		local dist = #(playerCoords - pos)
		if dist < maxDist then
			return true
		end
	end

	DebugPrint(('[^3WARNING^7] Player ^5%s^7 too far from shop ^5%s^7'):format(source, zone))
	return false
end

---Checks if player has enough money for the actual total (after tax)
---@param xPlayer table ESX player object
---@param paymentMethod string Payment method ('cash' or 'bank')
---@param total number Actual amount to deduct (after tax calculation)
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

---Refunds money to player
---@param xPlayer table ESX player object
---@param paymentMethod string Payment method ('cash' or 'bank')
---@param amount number Amount to refund
function RefundMoney(xPlayer, paymentMethod, amount)
	if paymentMethod == 'cash' then
		xPlayer.addMoney(amount, 'Shop Refund')
	elseif paymentMethod == 'bank' then
		xPlayer.addAccountMoney('bank', amount, 'Shop Refund')
	end
end
