-- Rate limiting state
local playerPurchaseCooldowns = {}

---Checks if player is rate limited and auto-expires old entries
---@param source number Player source
---@return boolean isLimited
---@return number remainingMs Remaining cooldown in ms
function IsPlayerRateLimited(source)
	local currentTime = GetGameTimer()
	local lastPurchase = playerPurchaseCooldowns[source]

	if not lastPurchase then
		return false, 0
	end

	local timeSinceLastPurchase = currentTime - lastPurchase

	-- Auto-expire old entries on access (lazy cleanup)
	if timeSinceLastPurchase > Config.CooldownExpiryMs then
		playerPurchaseCooldowns[source] = nil
		return false, 0
	end

	if timeSinceLastPurchase < Config.PurchaseCooldownMs then
		return true, Config.PurchaseCooldownMs - timeSinceLastPurchase
	end

	return false, 0
end

---Updates player's last purchase time
---@param source number Player source
function UpdatePurchaseTimestamp(source)
	playerPurchaseCooldowns[source] = GetGameTimer()
end

---Finds item in shop zone and returns its data
---@param itemName string Item spawn name
---@param zone string Shop zone name
---@return boolean exists Whether item exists in shop
---@return number|nil price Gross price if item exists
---@return string|nil label Item label if exists
function GetItemFromShop(itemName, zone)
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
	local itemCount = #items
	local serverTotal = 0
	local validatedItems = {}

	for i = 1, itemCount do
		local item = items[i]
		local quantity = item.quantity
		local clientPrice = item.price
		local itemName = item.name

		-- Validate quantity
		if quantity <= 0 then
			DebugPrint(_U('negative_quantity', source))
			return false, 0, {}
		end

		if quantity > Config.MaxQuantityPerItem then
			DebugPrint(_U('excessive_quantity', source, quantity, Config.MaxQuantityPerItem))
			return false, 0, {}
		end

		quantity = ESX.Math.Round(quantity)

		-- Validate item exists
		local exists, serverPrice, label = GetItemFromShop(itemName, zone)
		if not exists then
			DebugPrint(_U('invalid_zone', source, itemName))
			return false, 0, {}
		end

		-- Validate price is positive
		if serverPrice <= 0 then
			DebugPrint(_U('invalid_price', serverPrice, itemName, zone))
			return false, 0, {}
		end

		-- Validate price matches (prevent client manipulation)
		if serverPrice ~= clientPrice then
			DebugPrint(_U('price_manipulation', source, itemName, serverPrice, clientPrice))
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
	if math.abs(serverTotal - clientTotal) > Config.PriceTolerance then
		DebugPrint(_U('total_manipulation', source, serverTotal, clientTotal))
		return false
	end
	return true
end
