-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

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

---Normalizes money values to positive finite integers
---@param amount any
---@return number|nil amount
function NormalizeMoneyAmount(amount)
	local value = tonumber(amount)

	if not value or value ~= value or value == math.huge or value == -math.huge or value <= 0 then
		return nil
	end

	local integerValue = math.floor(value)
	if integerValue ~= value or integerValue <= 0 then
		return nil
	end

	return integerValue
end

local function GetCashBalance(xPlayer)
	if not xPlayer or type(xPlayer.getMoney) ~= 'function' then
		return nil
	end

	local ok, money = pcall(function()
		return xPlayer.getMoney()
	end)

	return ok and tonumber(money) or nil
end

local function GetAccountBalance(xPlayer, accountName)
	if not xPlayer or type(xPlayer.getAccount) ~= 'function' then
		return nil
	end

	local ok, account = pcall(function()
		return xPlayer.getAccount(accountName)
	end)

	return ok and account and tonumber(account.money) or nil
end

local function GetPaymentBalance(xPlayer, isBlackMarket)
	if isBlackMarket then
		return GetAccountBalance(xPlayer, 'black_money')
	end

	return GetCashBalance(xPlayer)
end

---Checks if player has required funds for the purchase
---@param xPlayer table ESX player object
---@param isBlackMarket boolean
---@param price number
---@return boolean
function CanPayForWeapon(xPlayer, isBlackMarket, price)
	price = NormalizeMoneyAmount(price)
	if not price then
		return false
	end

	if isBlackMarket then
		local balance = GetPaymentBalance(xPlayer, true) or 0
		if balance < price then
			xPlayer.showNotification(TranslateCap('not_enough_black'))
			return false
		end

		return true
	end

	if (GetPaymentBalance(xPlayer, false) or 0) < price then
		xPlayer.showNotification(TranslateCap('not_enough'))
		return false
	end

	return true
end

---Deducts purchase amount from the corresponding account
---@param xPlayer table ESX player object
---@param isBlackMarket boolean
---@param price number
---@param reason string|nil
---@return boolean
function TakeWeaponPayment(xPlayer, isBlackMarket, price, reason)
	price = NormalizeMoneyAmount(price)
	if not price then
		return false
	end

	local beforeBalance = GetPaymentBalance(xPlayer, isBlackMarket)
	if not beforeBalance or beforeBalance < price then
		return false
	end

	if isBlackMarket then
		local removed = pcall(function()
			xPlayer.removeAccountMoney('black_money', price, reason or 'Black Weapons Deal')
		end)

		if not removed then
			return false
		end
	elseif type(xPlayer.removeMoney) == 'function' then
		local removed = pcall(function()
			xPlayer.removeMoney(price, reason or 'Weapons Deal')
		end)

		if not removed then
			return false
		end
	else
		return false
	end

	local afterBalance = GetPaymentBalance(xPlayer, isBlackMarket)
	return afterBalance ~= nil and afterBalance <= beforeBalance - price
end

---Refunds a failed weapon purchase
---@param xPlayer table ESX player object
---@param isBlackMarket boolean
---@param price number
---@param reason string|nil
function RefundWeaponPayment(xPlayer, isBlackMarket, price, reason)
	price = NormalizeMoneyAmount(price)
	if not price then
		return
	end

	if isBlackMarket then
		pcall(function()
			xPlayer.addAccountMoney('black_money', price, reason or 'Black Weapons Deal Refund')
		end)
	else
		pcall(function()
			xPlayer.addMoney(price, reason or 'Weapons Deal Refund')
		end)
	end
end
