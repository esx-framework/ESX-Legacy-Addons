RegisterNetEvent('esx_shops:legacyPurchase', function(zone, items, paymentMethod)
	local source = source

	if not Verify(zone, 'string') or zone == '' then
		DebugPrint('[^3WARNING^7] legacyPurchase called with invalid zone type')
		TriggerClientEvent('esx_shops:legacyPurchaseResponse', source, false, 'Invalid shop')
		return
	end
	if not Verify(items, 'table') then
		DebugPrint('[^3WARNING^7] legacyPurchase called with invalid items type')
		TriggerClientEvent('esx_shops:legacyPurchaseResponse', source, false, 'Invalid items')
		return
	end
	if not Verify(paymentMethod, 'string') or (paymentMethod ~= 'cash' and paymentMethod ~= 'bank') then
		DebugPrint('[^3WARNING^7] legacyPurchase called with invalid payment method')
		TriggerClientEvent('esx_shops:legacyPurchaseResponse', source, false, 'Invalid payment method')
		return
	end

	local purchaseData = {
		items = items,
		total = 0,
		paymentMethod = paymentMethod
	}

	for _, item in ipairs(items) do
		if Verify(item, 'table') and item.price and item.quantity then
			purchaseData.total = purchaseData.total + (item.price * item.quantity)
		end
	end

	ProcessPurchase(source, purchaseData, zone, function(success, message)
		TriggerClientEvent('esx_shops:legacyPurchaseResponse', source, success, message)
	end)
end)

-- export for checking if item exists in shop
exports('IsItemInShop', function(itemName, zone)
	if not Verify(itemName, 'string') or not Verify(zone, 'string') then
		return false
	end
	local exists = GetItemFromShop(itemName, zone)
	return exists
end)
