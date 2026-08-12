---Processes a purchase request
---@param source number Player source
---@param purchaseData table Purchase data from client
---@param zone string Shop zone
---@param cb function Callback function(success, message)
function ProcessPurchase(source, purchaseData, zone, cb)
	-- Rate limiting check
	local isLimited, remainingMs = IsPlayerRateLimited(source)
	if isLimited then
		DebugPrint(_U('rate_limited_log', source, remainingMs))
		cb(false, _U('rate_limited'))
		return
	end

	-- Validate player
	local xPlayer = ValidatePlayer(source)
	if not xPlayer then
		cb(false, _U('invalid_player', source))
		return
	end

	-- Validate zone
	if not ValidateZone(zone, source) then
		cb(false, _U('invalid_shop'))
		return
	end

	-- CRITICAL: Validate player is actually near the shop
	if not ValidatePlayerDistance(source, zone) then
		cb(false, _U('invalid_shop'))
		return
	end

	-- Localize purchase data
	local items = purchaseData.items
	local clientTotal = purchaseData.total
	local paymentMethod = purchaseData.paymentMethod

	-- Validate payment method
	if not ValidatePaymentMethod(paymentMethod, source) then
		cb(false, _U('invalid_payment'))
		return
	end

	-- Validate items and calculate server total
	local itemsValid, serverTotal, validatedItems = ValidateAndCalculateItems(items, zone, source)
	if not itemsValid then
		cb(false, _U('invalid_items'))
		return
	end

	-- Validate total matches
	if not ValidateTotal(serverTotal, clientTotal, source) then
		cb(false, _U('price_mismatch'))
		return
	end

	-- PRE-VALIDATION: Check inventory space BEFORE money
	if not ValidateInventorySpace(source, validatedItems) then
		local message = _U('inventory_full')
		xPlayer.showNotification(message)
		cb(false, message)
		return
	end

	-- Calculate tax BEFORE checking money (so we check against actual amount)
	local actualTotal, actualTax = CalculateTax(xPlayer, serverTotal)

	-- Check player has enough money for the ACTUAL total (after tax)
	local hasEnough, missingAmount = CheckPlayerMoney(xPlayer, paymentMethod, actualTotal)
	if not hasEnough then
		local message = _U('not_enough_money', ESX.Math.GroupDigits(missingAmount))
		xPlayer.showNotification(message)
		cb(false, message)
		return
	end

	-- FINAL inventory check right before money deduction
	-- Prevents race conditions where inventory changed between checks
	if not ValidateInventorySpaceFinal(source, validatedItems) then
		local message = _U('inventory_full')
		xPlayer.showNotification(message)
		cb(false, message)
		return
	end

	-- Process purchase: money deducted BEFORE adding items for security
	DeductMoney(xPlayer, paymentMethod, actualTotal)

	-- Add items to inventory
	local itemsAdded = AddItemsToInventory(source, validatedItems)
	if not itemsAdded then
		-- CRITICAL: Items failed to add after money was deducted
		-- Attempt refund to prevent player losing money
		DebugPrint(_U('critical_transaction', source))
		RefundMoney(xPlayer, paymentMethod, actualTotal)
		DebugPrint(('[^2INFO^7] Refunded ^5$%s^7 to player ^5%s^7 due to item add failure'):format(
			ESX.Math.GroupDigits(actualTotal), source
		))
		cb(false, _U('transaction_error'))
		return
	end

	-- Deposit tax to society
	if actualTax > 0 then
		DepositTaxToSociety(actualTax)
	end

	-- Update rate limit
	UpdatePurchaseTimestamp(source)

	-- Success notification
	local message
	if IsJobTaxExempt(xPlayer) then
		message = _U('purchase_success_tax_exempt', ESX.Math.GroupDigits(actualTotal))
	else
		message = _U('purchase_success', ESX.Math.GroupDigits(actualTotal))
	end

	xPlayer.showNotification(message)
	cb(true, message)
end
