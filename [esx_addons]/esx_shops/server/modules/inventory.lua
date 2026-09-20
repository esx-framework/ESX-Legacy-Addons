-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

---@param source number Player source
---@param items table[] Validated items to add
---@return boolean canCarry
function ValidateInventorySpace(source, items)
	local itemCount = #items

	if GetShopInventoryBackend() == 'ox_inventory' then
		local simulatedItems = {}
		for i = 1, itemCount do
			local item = items[i]
			local carryAmount = item.quantity
			if simulatedItems[item.name] then
				carryAmount = carryAmount + simulatedItems[item.name]
			end
			if not exports.ox_inventory:CanCarryItem(source, item.name, carryAmount) then
				return false
			end
			simulatedItems[item.name] = carryAmount
		end
		return true
	else
		local xPlayer = ESX.Player(source)
		if not xPlayer then
			return false
		end

		local currentWeight = xPlayer.getWeight and xPlayer.getWeight() or xPlayer.weight or 0
		local maxWeight = xPlayer.getMaxWeight and xPlayer.getMaxWeight() or xPlayer.maxWeight or 0
		local addedWeight = 0

		for i = 1, itemCount do
			local item = items[i]
			local itemData = ESX.Items and ESX.Items[item.name]
			if not itemData then
				return false
			end

			addedWeight = addedWeight + ((itemData.weight or Config.DefaultItemWeight or 1) * item.quantity)
		end

		return (currentWeight + addedWeight) <= maxWeight
	end
end

---@param source number Player source
---@param items table[] Items to add
---@return boolean canCarry
function ValidateInventorySpaceFinal(source, items)
	return ValidateInventorySpace(source, items)
end

---@param source number Player source
---@param items table[] Items to add
---@return boolean success Whether all items were added successfully
function AddItemsToInventory(source, items)
	local itemCount = #items

	if GetShopInventoryBackend() == 'ox_inventory' then
		for i = 1, itemCount do
			local item = items[i]
			local success = exports.ox_inventory:AddItem(source, item.name, item.quantity)
			if not success then
				DebugPrint(_U('item_add_failed', item.name, source))
				return false
			end
		end
	else
		local xPlayer = ESX.Player(source)
		if not xPlayer then
			return false
		end

		for i = 1, itemCount do
			local item = items[i]
			local success = xPlayer.addInventoryItem(item.name, item.quantity)
			if success == false then
				DebugPrint(_U('item_add_failed', item.name, source))
				return false
			end
		end
	end

	return true
end
