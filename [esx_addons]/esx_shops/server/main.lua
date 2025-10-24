-- Rate limiting: Track last purchase time per player
local playerPurchaseCooldowns = {}
local PURCHASE_COOLDOWN_MS = 500 -- 500ms between purchases
local COOLDOWN_EXPIRY_MS = 10000 -- Auto-expire entries after 10 seconds

-- Security: Maximum quantity per item to prevent exploits
local MAX_QUANTITY_PER_ITEM = 999 -- No one will legitimately buy more than 999 of a single item

---Checks if player is rate limited and auto-expires old entries
---@param source number Player source
---@return boolean isLimited
---@return number remainingMs Remaining cooldown in ms
local function IsPlayerRateLimited(source)
	local currentTime = GetGameTimer()
	local lastPurchase = playerPurchaseCooldowns[source]

	if not lastPurchase then
		return false, 0
	end

	local timeSinceLastPurchase = currentTime - lastPurchase

	-- Auto-expire old entries on access (lazy cleanup)
	if timeSinceLastPurchase > COOLDOWN_EXPIRY_MS then
		playerPurchaseCooldowns[source] = nil
		return false, 0
	end

	-- Check if still in cooldown period
	if timeSinceLastPurchase < PURCHASE_COOLDOWN_MS then
		return true, PURCHASE_COOLDOWN_MS - timeSinceLastPurchase
	end

	return false, 0
end

---Updates player's last purchase time
---@param source number Player source
local function UpdatePurchaseTimestamp(source)
	playerPurchaseCooldowns[source] = GetGameTimer()
end

---Finds item in shop zone and returns its data
---@param itemName string Item spawn name
---@param zone string Shop zone name
---@return boolean exists Whether item exists in shop
---@return number|nil price Gross price if item exists
---@return string|nil label Item label if exists
local function GetItemFromShop(itemName, zone)
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

---Validates player exists
---@param source number Player source
---@return table|nil xPlayer ESX player object or nil
local function ValidatePlayer(source)
	local xPlayer = ESX.Player(source)
	if not xPlayer then
		print(('[^3WARNING^7] Invalid player ^5%s^7 attempted purchase'):format(source))
	end
	return xPlayer
end

---Validates zone exists
---@param zone string Zone name
---@param source number Player source for logging
---@return boolean valid
local function ValidateZone(zone, source)
	if not Config.Zones[zone] then
		print(('[^3WARNING^7] Player ^5%s^7 attempted purchase from invalid zone ^5%s^7'):format(source, zone))
		return false
	end
	return true
end

---Validates payment method
---@param method string Payment method
---@param source number Player source for logging
---@return boolean valid
local function ValidatePaymentMethod(method, source)
	if method ~= 'cash' and method ~= 'bank' then
		print(('[^3WARNING^7] Player ^5%s^7 attempted invalid payment method ^5%s^7'):format(source, method))
		return false
	end
	return true
end

---Validates items and calculates server-side total
---@param items table[] Purchase items
---@param zone string Shop zone
---@param source number Player source for logging
---@return boolean valid
---@return number serverTotal
---@return table[] validatedItems
local function ValidateAndCalculateItems(items, zone, source)
	local itemCount = #items
	local serverTotal = 0
	local validatedItems = {}

	-- Numeric loop for performance
	for i = 1, itemCount do
		local item = items[i]
		local quantity = item.quantity
		local clientPrice = item.price
		local itemName = item.name

		-- Validate quantity is positive and within limits
		if quantity <= 0 then
			print(('[^3ESX_SHOPS WARNING^7] Player ^5%s^7 attempted negative/zero quantity exploit'):format(source))
			return false, 0, {}
		end

		if quantity > MAX_QUANTITY_PER_ITEM then
			print(('[^3ESX_SHOPS WARNING^7] Player ^5%s^7 attempted to buy excessive quantity ^5%s^7 (max: ^5%s^7)'):format(
				source, quantity, MAX_QUANTITY_PER_ITEM
			))
			return false, 0, {}
		end

		-- Round quantity to prevent decimal exploits
		quantity = ESX.Math.Round(quantity)

		-- Validate item exists in shop
		local exists, serverPrice, label = GetItemFromShop(itemName, zone)
		if not exists then
			print(('[^3WARNING^7] Player ^5%s^7 attempted to buy non-existent item ^5%s^7'):format(source, itemName))
			return false, 0, {}
		end

		-- Validate price is positive (prevent config errors or exploits)
		if serverPrice <= 0 then
			print(('[^1ERROR^7] Invalid price ^5%s^7 for item ^5%s^7 in zone ^5%s^7 - check Config.lua'):format(
				serverPrice, itemName, zone
			))
			return false, 0, {}
		end

		-- Validate price matches (prevent client manipulation)
		if serverPrice ~= clientPrice then
			print(('[^3WARNING^7] Player ^5%s^7 attempted price manipulation for ^5%s^7 (server: ^5%s^7, client: ^5%s^7)'):format(
				source, itemName, serverPrice, clientPrice
			))
			return false, 0, {}
		end

		-- Calculate item total
		serverTotal = serverTotal + (serverPrice * quantity)

		-- Store validated item
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
local function ValidateTotal(serverTotal, clientTotal, source)
	-- Reduced tolerance from 0.01 to 0.001 to prevent exploitation
	-- Only allows for genuine floating point rounding errors
	if math.abs(serverTotal - clientTotal) > 0.001 then
		print(('[^3WARNING^7] Player ^5%s^7 attempted total manipulation (server: ^5%s^7, client: ^5%s^7)'):format(
			source, serverTotal, clientTotal
		))
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
local function CheckPlayerMoney(xPlayer, paymentMethod, total)
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

---Validates inventory space for all items (supports ESX & ox_inventory)
---@param source number Player source
---@param items table[] Validated items to add
---@return boolean canCarry
local function ValidateInventorySpace(source, items)
	local itemCount = #items

	if Config.Inventory == 'ox_inventory' then
		-- ox_inventory: check each item individually
		for i = 1, itemCount do
			local item = items[i]
			if not exports.ox_inventory:CanCarryItem(source, item.name, item.quantity) then
				return false
			end
		end
		return true
	else
		-- ESX: use xPlayer methods
		local xPlayer = ESX.Player(source)
		for i = 1, itemCount do
			local item = items[i]
			if not xPlayer.canCarryItem(item.name, item.quantity) then
				return false
			end
		end
		return true
	end
end

---Deducts money from player
---@param xPlayer table ESX player object
---@param paymentMethod string Payment method ('cash' or 'bank')
---@param amount number Amount to deduct
local function DeductMoney(xPlayer, paymentMethod, amount)
	if paymentMethod == 'cash' then
		xPlayer.removeMoney(amount, 'Shop Purchase')
	elseif paymentMethod == 'bank' then
		xPlayer.removeAccountMoney('bank', amount, 'Shop Purchase')
	end
end

---Adds items to player inventory (supports ESX & ox_inventory)
---@param source number Player source
---@param items table[] Items to add
---@return boolean success Whether all items were added successfully
local function AddItemsToInventory(source, items)
	local itemCount = #items

	if Config.Inventory == 'ox_inventory' then
		-- ox_inventory: use exports with error handling
		for i = 1, itemCount do
			local item = items[i]
			local success = exports.ox_inventory:AddItem(source, item.name, item.quantity)
			if not success then
				print(('[^1ERROR^7] Failed to add item ^5%s^7 to player ^5%s^7 inventory'):format(item.name, source))
				return false
			end
		end
	else
		-- ESX: use xPlayer methods
		local xPlayer = ESX.Player(source)
		for i = 1, itemCount do
			local item = items[i]
			xPlayer.addInventoryItem(item.name, item.quantity)
		end
	end

	return true
end

---Checks if player's job is tax exempt
---@param xPlayer table ESX player object
---@return boolean isExempt
local function IsJobTaxExempt(xPlayer)
	if not Config.EnableTaxExemptions then
		return false
	end

	local playerJob = xPlayer.getJob().name
	local exemptJobsCount = #Config.TaxExemptJobs

	-- Numeric loop for performance
	for i = 1, exemptJobsCount do
		if Config.TaxExemptJobs[i] == playerJob then
			return true
		end
	end

	return false
end

---Deposits tax amount to society account
---@param taxAmount number Tax amount to deposit
local function DepositTaxToSociety(taxAmount)
	if not Config.EnableTaxCollection then return end
	if taxAmount <= 0 then return end

	TriggerEvent('esx_addonaccount:getSharedAccount', Config.TaxSocietyAccount, function(account)
		if account then
			account.addMoney(taxAmount)
		else
			print(('[^3ESX_SHOPS WARNING^7] Tax society account ^5%s^7 not found - tax amount ^5$%s^7 was not collected'):format(
				Config.TaxSocietyAccount, ESX.Math.Round(taxAmount)
			))
		end
	end)
end

---Gets player's tax rate based on job exemptions
ESX.RegisterServerCallback('esx_shops:getTaxRate', function(source, cb)
	local xPlayer = ESX.Player(source)
	if not xPlayer then
		cb(Config.TaxRate, nil)
		return
	end

	if IsJobTaxExempt(xPlayer) then
		cb(0, 'Thanks for your service!')
	else
		cb(Config.TaxRate, nil)
	end
end)

---Handles purchase requests from clients
ESX.RegisterServerCallback('esx_shops:purchaseItems', function(source, cb, purchaseData, zone)
	-- Check rate limiting
	local isLimited, remainingMs = IsPlayerRateLimited(source)
	if isLimited then
		print(('[^3WARNING^7] Player ^5%s^7 is rate limited (cooldown: ^5%sms^7)'):format(source, remainingMs))
		cb(false, 'Please wait before making another purchase')
		return
	end

	-- Validate player
	local xPlayer = ValidatePlayer(source)
	if not xPlayer then
		cb(false, 'Invalid player')
		return
	end

	-- Validate zone
	if not ValidateZone(zone, source) then
		cb(false, 'Invalid shop')
		return
	end

	-- Localize purchase data
	local items = purchaseData.items
	local clientTotal = purchaseData.total
	local paymentMethod = purchaseData.paymentMethod

	-- Validate payment method
	if not ValidatePaymentMethod(paymentMethod, source) then
		cb(false, 'Invalid payment method')
		return
	end

	-- Validate items and calculate server total
	local itemsValid, serverTotal, validatedItems = ValidateAndCalculateItems(items, zone, source)
	if not itemsValid then
		cb(false, 'Invalid items')
		return
	end

	-- Validate total matches
	if not ValidateTotal(serverTotal, clientTotal, source) then
		cb(false, 'Price mismatch')
		return
	end

	-- PRE-VALIDATION: Check inventory space BEFORE checking money
	-- This ensures transaction will succeed if money check passes
	if not ValidateInventorySpace(source, validatedItems) then
		local message = 'Cannot carry items - inventory full!'
		xPlayer.showNotification(message)
		cb(false, message)
		return
	end

	-- Check player has enough money (validated AFTER inventory to ensure transaction can complete)
	local hasEnough, missingAmount = CheckPlayerMoney(xPlayer, paymentMethod, serverTotal)
	if not hasEnough then
		local message = ('Not enough money! Missing $%s'):format(ESX.Math.GroupDigits(missingAmount))
		xPlayer.showNotification(message)
		cb(false, message)
		return
	end

	-- All validation passed - calculate actual payment and tax
	local actualTax = 0
	local actualTotal = serverTotal

	-- Check if player is tax exempt
	if IsJobTaxExempt(xPlayer) then
		-- Tax exempt: only pay net amount
		actualTotal = serverTotal / (1 + Config.TaxRate)
	else
		-- Calculate tax from gross price
		actualTax = serverTotal - (serverTotal / (1 + Config.TaxRate))
	end

	-- Process purchase (money deducted BEFORE adding items for security)
	DeductMoney(xPlayer, paymentMethod, actualTotal)

	-- Add items to inventory (should never fail due to pre-validation)
	local itemsAdded = AddItemsToInventory(source, validatedItems)
	if not itemsAdded then
		-- This should NEVER happen due to pre-validation, but handle gracefully
		print(('[^1CRITICAL^7] Failed to add items after money deduction for player ^5%s^7'):format(source))
		-- Note: Money already deducted - server operator should investigate and refund manually
		cb(false, 'Transaction error - contact an administrator')
		return
	end

	-- Deposit tax to society (if enabled and applicable)
	if actualTax > 0 then
		DepositTaxToSociety(actualTax)
	end

	-- Update rate limit timestamp
	UpdatePurchaseTimestamp(source)

	-- Send success notification and response
	local message = ('Purchase successful! Total: $%s'):format(ESX.Math.GroupDigits(actualTotal))
	if IsJobTaxExempt(xPlayer) then
		message = message .. ' (Tax exempt)'
	end
	xPlayer.showNotification(message)
	cb(true, message)
end)
