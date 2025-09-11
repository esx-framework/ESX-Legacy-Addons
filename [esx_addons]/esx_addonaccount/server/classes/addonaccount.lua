---@class AddonAccount
---@field name string
---@field owner? string
---@field money number
---@field addMoney fun(amount: number): boolean
---@field removeMoney fun(amount: number): boolean
---@field setMoney fun(amount: number): boolean
---@field transferMoney fun(target: TransactionAccount, amount: number): boolean
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
		return true
	end

	function self.removeMoney(amount)
		if amount > self.money then return false end

		self.money -= amount

		TriggerEvent('esx_addonaccount:removeMoney', self.name, amount)
		TriggerClientEvent('esx_addonaccount:setMoney', -1, self.name, self.money)
		return true
	end

	function self.setMoney(amount)
		self.money = amount

		TriggerEvent('esx_addonaccount:setMoney', self.name, amount)
		TriggerClientEvent('esx_addonaccount:setMoney', -1, self.name, self.money)
		return true
	end

	function self.transferMoney(target, amount)
		local targetAccount = GetTransactionAccount(target)
		if not targetAccount then return false end

		if not self.removeMoney(amount) then
			return false
		end

		targetAccount.addMoney(amount)
		return true
	end

	function self.save()
	end

	return self
end
