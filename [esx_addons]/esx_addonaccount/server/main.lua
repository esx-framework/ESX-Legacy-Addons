local Accounts, SharedAccounts = {}, {}

local FETCH_ACCOUNTS_QUERY = [[
	SELECT * FROM addon_account
	LEFT JOIN addon_account_data ON addon_account.name = addon_account_data.account_name
	UNION
	SELECT * FROM addon_account
	RIGHT JOIN addon_account_data ON addon_account.name = addon_account_data.account_name
]]
local function initializeAccounts()
	local accounts = MySQL.query.await(FETCH_ACCOUNTS_QUERY)
	local newAccounts = {}

	for _, accountRow in ipairs(accounts) do
		local accountName = accountRow.name
		if accountRow.shared == 0 then
			if not Accounts[accountName] then
				Accounts[accountName] = {}
			end

			local newIndex = #Accounts[accountName] + 1
			Accounts[accountName][newIndex] = CreateAddonAccount(accountName, accountRow.owner, accountRow.money)
		else
			if accountRow.money then
				SharedAccounts[accountName] = CreateAddonAccount(accountName, nil, accountRow.money)
			else
				newAccounts[#newAccounts + 1] = { accountName, 0 }
			end
		end
	end

	GlobalState.SharedAccounts = SharedAccounts

	if next(newAccounts) then
		MySQL.prepare.await('INSERT INTO addon_account_data (account_name, money) VALUES (?, ?)', newAccounts)

		for _, newAccount in ipairs(newAccounts) do
			local accountName = newAccount[1]
			SharedAccounts[accountName] = CreateAddonAccount(accountName, nil, 0)
		end

		GlobalState.SharedAccounts = SharedAccounts
	end
end

---@param name string
---@param owner string
---@return AddonAccount?
local function getAccount(name, owner)
	for _, account in ipairs(Accounts[name]) do
		if account.owner == owner then
			return account
		end
	end
end

---@param name string
---@return AddonAccount
local function getSharedAccount(name)
	return SharedAccounts[name]
end

---@param society { name: string, label: string }
---@param amount? number
---@return AddonAccount?
local function addSharedAccount(society, amount)
	local societyName, societyLabel = society?.name, society?.label
	if not societyName or not societyLabel then return end

	local existingSharedAccount = SharedAccounts[societyName]
	if existingSharedAccount then return existingSharedAccount end

	local account = MySQL.insert.await('INSERT INTO `addon_account` (name, label, shared) VALUES (?, ?, ?)', { societyName, societyLabel, 1 })
	if not account then return end

	amount = amount or 0
	local accountData = MySQL.insert.await('INSERT INTO `addon_account_data` (account_name, money) VALUES (?, ?)', {
		societyName, amount
	})
	if not accountData then return end

	SharedAccounts[societyName] = CreateAddonAccount(societyName, nil, amount)

	GlobalState.SharedAccounts = SharedAccounts

	return SharedAccounts[societyName]
end

AddEventHandler('onResourceStart', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then return end

	initializeAccounts()
end)

---@param name string
---@param owner string
---@param cb function
AddEventHandler('esx_addonaccount:getAccount', function(name, owner, cb)
	cb(getAccount(name, owner))
end)

---@param name string
---@param cb function
AddEventHandler('esx_addonaccount:getSharedAccount', function(name, cb)
	cb(getSharedAccount(name))
end)

AddEventHandler('esx:playerLoaded', function(_, xPlayer)
	local addonAccounts = {}

	local identifier = xPlayer.getIdentifier()
	for _, accountName in pairs(Accounts) do
		local account = getAccount(accountName, identifier)

		if not account then
			MySQL.insert.await('INSERT INTO addon_account_data (account_name, money, owner) VALUES (?, ?, ?)',
				{ accountName, 0, identifier })

			account = CreateAddonAccount(accountName, identifier, 0)

			local newIndex = #Accounts[accountName] + 1
			Accounts[accountName][newIndex] = account
		end

		addonAccounts[#addonAccounts + 1] = account
	end

	xPlayer.set('addonAccounts', addonAccounts)
end)

RegisterNetEvent('esx_addonaccount:refreshAccounts', initializeAccounts)

exports('GetSharedAccount', getSharedAccount)
exports('AddSharedAccount', addSharedAccount)
exports('GetAccount', getAccount)
