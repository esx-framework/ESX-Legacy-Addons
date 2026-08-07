RegisterNetEvent('esx_shops:legacyPurchase', function(zone, items, paymentMethod)
	local source = source
	local purchaseData = {
		items = items,
		total = 0, -- Will be recalculated server-side
		paymentMethod = paymentMethod
	}

	for _, item in ipairs(items) do
		purchaseData.total = purchaseData.total + (item.price * item.quantity)
	end

	ProcessPurchase(source, purchaseData, zone, function(success, message)
		TriggerClientEvent('esx_shops:legacyPurchaseResponse', source, success, message)
	end)
end)

exports('IsItemInShop', function(itemName, zone)
	local exists = GetItemFromShop(itemName, zone)
	return exists
end)
