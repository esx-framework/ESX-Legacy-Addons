-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local purchaseLimiter = xLib.rateLimiter({
	capacity = Config.PurchaseRateLimitCapacity or 3,
	refill = Config.PurchaseRateLimitRefill or 1,
	interval = Config.PurchaseRateLimitIntervalMs or Config.PurchaseCooldownMs or 500,
	staleMs = Config.CooldownExpiryMs,
})

---Checks if player is rate limited and auto-expires old entries
---@param source number Player source
---@return boolean isLimited
---@return number remainingMs Remaining cooldown in ms
function IsPlayerRateLimited(source)
	if not Verify(source, {'number', 'string'}) then
		return false, 0
	end

	local allowed, retryAfter = purchaseLimiter:consume(source)
	return not allowed, retryAfter
end

---Kept for compatibility; the token bucket consumes at request entry.
---@param source number Player source
function UpdatePurchaseTimestamp(source)
end

---Finds item in shop zone and returns its data
---@param itemName string Item spawn name
---@param zone string Shop zone name
---@return boolean exists Whether item exists in shop
---@return number|nil price Gross price if item exists
---@return string|nil label Item label if exists
function GetItemFromShop(itemName, zone)
	if not Verify(itemName, 'string') or not Verify(zone, 'string') then
		return false
	end

	local zoneData = Config.Zones[zone]
	if not zoneData then return false end

	local items = zoneData.Items
	local itemCount = #items

	for i = 1, itemCount do
		local item = items[i]
		if item.name == itemName then
			return true, item.price, item.label
		end
	end

	return false
end

---Validates items and calculates server-side total
---@param items table[] Purchase items
---@param zone string Shop zone
---@param source number Player source for logging
---@return boolean valid
---@return number serverTotal
---@return table[] validatedItems
function ValidateAndCalculateItems(items, zone, source)
	if not Verify(items, 'table') or not Verify(zone, 'string') then
		return false, 0, {}
	end

	local itemCount = #items
	local maxCartLines = Config.MaxCartLines or 25

	if itemCount < 1 or itemCount > maxCartLines then
		DebugPrint(('[^3WARNING^7] Player ^5%s^7 sent invalid cart size ^5%s^7'):format(source, itemCount))
		return false, 0, {}
	end

	local serverTotal = 0
	local validatedItems = {}

	for i = 1, itemCount do
		local item = items[i]

		if not Verify(item, 'table') then
			DebugPrint(('[^3WARNING^7] Player ^5%s^7 sent invalid item data'):format(source))
			return false, 0, {}
		end

		local quantity = item.quantity
		local itemName = item.name

		if not Verify(quantity, 'number') or not Verify(itemName, 'string') then
			DebugPrint(('[^3WARNING^7] Player ^5%s^7 sent invalid item field types'):format(source))
			return false, 0, {}
		end

		if quantity < 1 or quantity ~= math.floor(quantity) then
			DebugPrint(_U('negative_quantity', source))
			return false, 0, {}
		end

		if quantity > Config.MaxQuantityPerItem then
			DebugPrint(_U('excessive_quantity', source, quantity, Config.MaxQuantityPerItem))
			return false, 0, {}
		end

		local exists, serverPrice, label = GetItemFromShop(itemName, zone)
		if not exists then
			DebugPrint(_U('invalid_zone', source, itemName))
			return false, 0, {}
		end

		if serverPrice <= 0 then
			DebugPrint(_U('invalid_price', serverPrice, itemName, zone))
			return false, 0, {}
		end

		serverTotal = serverTotal + (serverPrice * quantity)

		validatedItems[i] = {
			name = itemName,
			quantity = quantity,
			label = label,
			price = serverPrice
		}
	end

	return true, serverTotal, validatedItems
end

---Validates total matches server calculation
---@param serverTotal number Server-calculated total
---@param clientTotal number Client-sent total
---@param source number Player source for logging
---@return boolean valid
function ValidateTotal(serverTotal, clientTotal, source)
	if not Verify(serverTotal, 'number') or not Verify(clientTotal, 'number') then
		DebugPrint(('[^3WARNING^7] Player ^5%s^7 sent invalid total types'):format(source))
		return false
	end

	if math.abs(serverTotal - clientTotal) > Config.PriceTolerance then
		DebugPrint(_U('total_manipulation', source, serverTotal, clientTotal))
		return false
	end
	return true
end
