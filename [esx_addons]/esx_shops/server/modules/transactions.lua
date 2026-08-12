---@param source number Player source
---@param purchaseData table Purchase data from client
---@param zone string Shop zone
---@param cb function Callback function(success, message)
function ProcessPurchase(source, purchaseData, zone, cb)
	local isLimited, remainingMs = IsPlayerRateLimited(source)
	if isLimited then
		DebugPrint(_U('rate_limited_log', source, remainingMs))
		cb(false, _U('rate_limited'))
		return
	end

	local xPlayer = ValidatePlayer(source)
	if not xPlayer then
		cb(false, _U('invalid_player', source))
		return
	end

	if not ValidateZone(zone, source) then
		cb(false, _U('invalid_shop'))
		return
	end

	if not ValidatePlayerDistance(source, zone) then
		cb(false, _U('invalid_shop'))
		return
	end

	local items = purchaseData.items
	local clientTotal = purchaseData.total
	local paymentMethod = purchaseData.paymentMethod

	if not ValidatePaymentMethod(paymentMethod, source) then
		cb(false, _U('invalid_payment'))
		return
	end

	local itemsValid, serverTotal, validatedItems = ValidateAndCalculateItems(items, zone, source)
	if not itemsValid then
		cb(false, _U('invalid_items'))
		return
	end

	if not ValidateTotal(serverTotal, clientTotal, source) then
		cb(false, _U('price_mismatch'))
		return
	end

	if not ValidateInventorySpace(source, validatedItems) then
		local message = _U('inventory_full')
		xPlayer.showNotification(message)
		cb(false, message)
		return
	end

	local actualTotal, actualTax = CalculateTax(xPlayer, serverTotal)
	local hasEnough, missingAmount = CheckPlayerMoney(xPlayer, paymentMethod, actualTotal)
	if not hasEnough then
		local message = _U('not_enough_money', ESX.Math.GroupDigits(missingAmount))
		xPlayer.showNotification(message)
		cb(false, message)
		return
	end

	if not ValidateInventorySpaceFinal(source, validatedItems) then
		local message = _U('inventory_full')
		xPlayer.showNotification(message)
		cb(false, message)
		return
	end

	DeductMoney(xPlayer, paymentMethod, actualTotal)

	local itemsAdded = AddItemsToInventory(source, validatedItems)
	if not itemsAdded then
		DebugPrint(_U('critical_transaction', source))
		RefundMoney(xPlayer, paymentMethod, actualTotal)
		DebugPrint(('[^2INFO^7] Refunded ^5$%s^7 to player ^5%s^7 due to item add failure'):format(
			ESX.Math.GroupDigits(actualTotal), source
		))
		cb(false, _U('transaction_error'))
		return
	end

	if actualTax > 0 then
		DepositTaxToSociety(actualTax)
	end

	UpdatePurchaseTimestamp(source)

	local message
	if IsJobTaxExempt(xPlayer) then
		message = _U('purchase_success_tax_exempt', ESX.Math.GroupDigits(actualTotal))
	else
		message = _U('purchase_success', ESX.Math.GroupDigits(actualTotal))
	end

	xPlayer.showNotification(message)
	cb(true, message)
end
