---Validates inventory space for all items (supports ESX & ox_inventory)
---@param source number Player source
---@param items table[] Validated items to add
---@return boolean canCarry
function ValidateInventorySpace(source, items)
	local itemCount = #items

	if Config.Inventory == 'ox_inventory' then
		for i = 1, itemCount do
			local item = items[i]
			if not exports.ox_inventory:CanCarryItem(source, item.name, item.quantity) then
				return false
			end
		end
		return true
	else
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

---Adds items to player inventory (supports ESX & ox_inventory)
---@param source number Player source
---@param items table[] Items to add
---@return boolean success Whether all items were added successfully
function AddItemsToInventory(source, items)
	local itemCount = #items

	if Config.Inventory == 'ox_inventory' then
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
		for i = 1, itemCount do
			local item = items[i]
			xPlayer.addInventoryItem(item.name, item.quantity)
		end
	end

	return true
end
