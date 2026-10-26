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
local function paymentAccount(isBlackMarket, account)
    if isBlackMarket then
        return account == 'black_money' and account or nil
    end

    if account == 'money' or account == 'bank' then
        return account
    end
end

function CanPayForWeapon(xPlayer, isBlackMarket, price, account)
    local selected = paymentAccount(isBlackMarket, account)
    local amount = NormalizeMoneyAmount(price)
    local balance = selected and xPlayer.getAccount(selected)

    if not amount or not balance or balance.money < amount then
        xPlayer.showNotification(TranslateCap(isBlackMarket and 'not_enough_black' or 'not_enough'))
        return false
    end

	return true
end

function TakeWeaponPayment(xPlayer, isBlackMarket, price, reason, account)
    local selected = paymentAccount(isBlackMarket, account)
    local amount = NormalizeMoneyAmount(price)

    if not selected or not amount then
        return false
    end

    return xPlayer.chargeAccount(selected, amount, reason or 'Weapons Deal') == true
end

function RefundWeaponPayment(xPlayer, isBlackMarket, price, reason, account)
    local selected = paymentAccount(isBlackMarket, account)
    local amount = NormalizeMoneyAmount(price)

    if selected and amount then
        return PaymentGateway.Refund(xPlayer, selected, amount, reason or 'Weapons Deal Refund')
    end

    return false
end
