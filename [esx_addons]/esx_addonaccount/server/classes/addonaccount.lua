---@class AddonAccount
---@field name string
---@field owner? string
---@field money number
---@field addMoney fun(amount: number)
---@field removeMoney fun(amount: number)
---@field setMoney fun(amount: number)
---@field save function

---@param name string
---@param owner? string
---@param money number
---@return AddonAccount
function CreateAddonAccount(name, owner, money)
	---@diagnostic disable-next-line: missing-fields
	local self = {} --[[@type AddonAccount]]

	self.name = name
	self.owner = owner
	self.money = money

	function self.addMoney(amount)
		self.money += amount
		self.save()

		TriggerEvent('esx_addonaccount:addMoney', self.name, amount)
	end

	function self.removeMoney(amount)
		self.money -= amount
		self.save()

		TriggerEvent('esx_addonaccount:removeMoney', self.name, amount)
	end

	function self.setMoney(amount)
		self.money = amount
		self.save()

		TriggerEvent('esx_addonaccount:setMoney', self.name, amount)
	end

	function self.save()
		local query, params = 'UPDATE addon_account_data SET money = ? WHERE account_name = ?', { self.money, self.name }

		if self.owner then
			query = query .. ' AND owner = ?'
			table.insert(params, self.owner)
		end

		MySQL.update.await(query, params)
		TriggerClientEvent('esx_addonaccount:setMoney', -1, self.name, self.money)
	end

	return self
end
