function GetItemFromShop(itemName, zone)
	local zoneItems = Config.Zones[zone].Items
	local item = nil

	for _, itemData in pairs(zoneItems) do
		if itemData.name == itemName then
			item = itemData
			break
		end
	end

	if not item then
		return false
	end

	return true,item.price, item.label
end

RegisterServerEvent('esx_shops:buyItem')
AddEventHandler('esx_shops:buyItem', function(itemName, amount, zone)
	local source = source
	local xPlayer = ESX.GetPlayerFromId(source)
	local Exists, price, label = GetItemFromShop(itemName, zone)
	amount = ESX.Math.Round(amount)

	if amount < 0 then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to exploit the shop!'):format(source))
		return
	end

    local method = data and data.method or 'cash'
    local cart = data and data.cart or {}
    if type(cart) ~= 'table' or #cart == 0 then
        cb(false, _U('cart_empty'))
        return
    end

    local maxQty = Config.ItemMaxQuantity or 100

    local total = 0
    local normalizedCart = {}
    for _, entry in ipairs(cart) do
        if type(entry) ~= 'table' then
            cb(false, _U('invalid_cart_entry'))
            return
        end
        local name = entry.name
        local amount = tonumber(entry.amount)
        if not name or not amount then
            cb(false, _U('invalid_item_data'))
            return
        end
        local def = itemIndex[name]
        if not def then
            cb(false, _U('unknown_item', name))
            return
        end
        if amount < 1 or amount > maxQty then
            cb(false, _U('invalid_quantity'))
            return
        end
        total = total + (def.price * amount)
        normalizedCart[#normalizedCart + 1] = { name = name, amount = amount }
    end

    if method == 'bank' then
        if xPlayer.getAccount('bank').money < total then
            cb(false, _U('not_enough_bank'))
            return
        end
        xPlayer.removeAccountMoney('bank', total)
    else
        if xPlayer.getMoney() < total then
            cb(false, _U('not_enough_cash'))
            return
        end
        xPlayer.removeMoney(total)
    end

    for _, entry in ipairs(normalizedCart) do
        xPlayer.addInventoryItem(entry.name, entry.amount)
    end

    cb(true, _U('purchase_success'))
end)
