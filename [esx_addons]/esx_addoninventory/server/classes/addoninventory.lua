---@alias AddonInventoryItem { name: string, count: number, label: string }

---@class AddonInventory
---@field name string
---@field owner? string
---@field items table<string, AddonInventoryItem>
---@field addItem fun(itemName: string, count: number)
---@field removeItem fun(itemName: string, count: number)
---@field setItem fun(itemName: string, count: number)
---@field getItem fun(itemName: string): AddonInventoryItem
---@field saveItem function

---@param name string
---@param owner? string
---@param items table<string, AddonInventoryItem>
---@return AddonInventory
function CreateAddonInventory(name, owner, items)
	---@diagnostic disable-next-line: missing-fields
	local self = {} --[[@type AddonInventory]]

	self.name  = name
	self.owner = owner
	self.items = {}

	for _, item in ipairs(items) do
		local itemName = item.name
		self.items[itemName] = {
			name = itemName,
			count = item.count,
			label = ESX.GetItemLabel(itemName),
		}
	end

	function self.addItem(itemName, count)
		local item = self.getItem(itemName)
		item.count += count
	end

	function self.removeItem(itemName, count)
		if count <= 0 then return end

		local item = self.getItem(itemName)
		item.count = math.max(0, item.count - count)
	end

	function self.setItem(itemName, count)
		local item = self.getItem(itemName)
		item.count = count
	end

	function self.getItem(itemName)
		local existingItem = self.items[itemName]
		if existingItem then return existingItem end

		self.items[itemName] = {
			name  = itemName,
			count = 0,
			label = ESX.GetItemLabel(itemName)
		}

		return self.items[itemName]
	end

	function self.saveItem(itemName, count)
	end

	return self
end
