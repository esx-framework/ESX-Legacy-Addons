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

		TriggerEvent('esx_addonaccount:addMoney', self.name, amount)
		TriggerClientEvent('esx_addonaccount:setMoney', -1, self.name, self.money)
	end

	function self.removeMoney(amount)
		self.money -= amount

		TriggerEvent('esx_addonaccount:removeMoney', self.name, amount)
		TriggerClientEvent('esx_addonaccount:setMoney', -1, self.name, self.money)
	end

	function self.setMoney(amount)
		self.money = amount

		TriggerEvent('esx_addonaccount:setMoney', self.name, amount)
		TriggerClientEvent('esx_addonaccount:setMoney', -1, self.name, self.money)
	end

	function self.save()
	end

	return self
end
