-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

---Handles purchase requests from clients
local function RegisterConfiguredShopItems()
	if GetShopInventoryBackend() ~= 'esx' then
		return
	end

	if not ESX.IsFunctionReference(ESX.AddItems) then
		DebugPrint('[esx_shops] ESX.AddItems is not available; make sure shop items exist in the items table')
		return
	end

	local seen = {}
	local items = {}

	for _, zoneData in pairs(Config.Zones or {}) do
		local shopItems = zoneData.Items or {}

		for i = 1, #shopItems do
			local item = shopItems[i]
			local name = item.name

			if type(name) == 'string' and name ~= '' and not seen[name] then
				seen[name] = true
				items[#items + 1] = {
					name = name,
					label = item.label or name,
					weight = item.weight or Config.DefaultItemWeight or 1,
					rare = item.rare == true,
					canRemove = item.canRemove ~= false,
				}
			end
		end
	end

	if #items > 0 then
		ESX.AddItems(items)
	end
end

RegisterConfiguredShopItems()

xLib.callback.registerCompat('esx_shops:purchaseItems', function(source, cb, purchaseData, zone)
	ProcessPurchase(source, purchaseData, zone, cb)
end)

xLib.callback.registerCompat('esx_shops:quotePurchase', function(source, cb, data, zone)
    local player = ValidatePlayer(source)

    if not player or type(data) ~= 'table' or not ValidateZone(zone, source) then
        return cb(false)
    end

    if not ValidatePlayerDistance(source, zone) then
        return cb(false)
    end

    local valid, total = ValidateAndCalculateItems(data.items, zone, source)

    if not valid then
        return cb(false)
    end

    cb(CalculateTax(player, total))
end)

xLib.callback.registerCompat(
    'esx_shops:purchaseItemsGateway',
    function(source, cb, data, zone, account)
        if type(data) ~= 'table' or (account ~= 'money' and account ~= 'bank') then
            return cb(false, _U('invalid_payment'))
        end

        data.paymentMethod = account
        ProcessPurchase(source, data, zone, cb)
    end
)
