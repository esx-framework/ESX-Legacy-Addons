local oxmysql = exports.oxmysql

local AccountsIndex, Accounts, SharedAccounts, GlobalSharedAccount = {}, {}, {}, {}

local function log(_type, message)
	local type_

	if _type == "error" then
		type_ = "^8Error^7"
	elseif _type == "warn" then
		type_ = "^8Warning^7"
	elseif _type == "info" then
		type_ = "^2Info^7"
	end

	print(("esx_society [%s] %s"):format(type_, message))
end

local function CreateAddonAccount(name, owner, money)
	local self = {}

	self.name  = name
	self.owner = owner
	self.money = money

	function self.addMoney(m)
		self.money = self.money + m
		local save = self.save()

		if not save then
			return false
		end

		TriggerEvent('esx_addonaccount:addMoney', self.name, m)
		return true, self.money
	end

	function self.removeMoney(m)
		self.money = self.money - m

		local save = self.save()
		
		if not save then
			return false
		end

		TriggerEvent('esx_addonaccount:removeMoney', self.name, m)
		return true, self.money
	end

	function self.setMoney(m)
		self.money = m

		local save = self.save()

		if not save then
			return false
		end

		TriggerEvent('esx_addonaccount:setMoney', self.name, m)
		return true, self.money
	end

	function self.save()
		local money, name, owner = self.money, self.name, self.owner
		local retData

		if owner == nil then
			retData = oxmysql:query_async('UPDATE addon_account_data SET money = ? WHERE account_name = ?', { money, name })
		else
			retData = oxmysql:query_async('UPDATE addon_account_data SET money = ? WHERE account_name = ? AND owner = ?', { money, name, owner })
		end

		if not retData or retData.affectedRows < 1 then
			log("error", ("Failed To Update Account: [^9%s^7]"):format(name))
			return false
		end

		TriggerClientEvent('esx_addonaccount:setMoney', -1, name, money)

		return true
	end

	return self
end

local function AddMoney(name, amount)
	if not name then
		log("error", "AddMoney() Society Name Cannot Be Null")
		return
	end

	if not amount or not tonumber(amount) then
		log("error", "AddMoney() Amount Must Be A Number")
		return
	end

	if not SharedAccounts[name] then
		log("error", ("AddMoney() Society: [^9%s^7] Does Not Exist!"):format(name))
		return
	end

	local retData = SharedAccounts[name].addMoney(amount)
	GlobalSharedAccount[name] = { money = SharedAccounts[name].money }

	GlobalState.SharedAccounts = GlobalSharedAccount

	return retData
end

local function RemoveMoney(name, amount)
	if not name then
		log("error", "RemoveMoney() Society Name Cannot Be Null")
		return
	end

	if not amount or not tonumber(amount) then
		log("error", "RemoveMoney() Amount Must Be A Number")
		return
	end

	if not SharedAccounts[name] then
		log("error", ("RemoveMoney() Society: [^9%s^7] Does Not Exist!"):format(name))
		return
	end

	local retData = SharedAccounts[name].removeMoney(amount)
	GlobalSharedAccount[name] = { money = SharedAccounts[name].money }

	GlobalState.SharedAccounts = GlobalSharedAccount

	return retData
end

local function SetMoney(name, amount)
	if not name then
		log("error", "SetMoney() Society Name Cannot Be Null")
		return
	end

	if not amount or not tonumber(amount) then
		log("error", "SetMoney() Amount Must Be A Number")
		return
	end

	if not SharedAccounts[name] then
		log("error", ("SetMoney() Society: [^9%s^7] Does Not Exist!"):format(name))
		return
	end

	local retData = SharedAccounts[name].setMoney(amount)
	GlobalSharedAccount[name] = { money = SharedAccounts[name].money }

	GlobalState.SharedAccounts = GlobalSharedAccount

	return retData
end

local function GetAccount(name, owner)
	if not name then
		log("error", "GetAccount() Missing Parameter: [^9name^7]")
		return
	end

	if not owner then
		log("error", "GetAccount() Missing Parameter: [^9owner^7]")
		return
	end

	for i=1, #Accounts[name], 1 do
		if Accounts[name][i].owner == owner then
			return Accounts[name][i]
		end
	end
end

local function GetSharedAccount(name)
	if not name then
		log("error", "GetSharedAccount() Missing Parameter: [^9name^7]")
		return
	end

	if not SharedAccounts[name] then
		log("error", ("GetSharedAccount() Account: [^9%s^7] Does Not Exist."):format(name))
		return
	end

	return SharedAccounts[name]
end

local function AddSharedAccount(society, amount)
    -- society.name = job_name/society_name
    -- society.label = label for the job/account
    -- amount = if the shared account should start with x amount
    if type(society) ~= 'table' or not society?.name or not society?.label then 
		log("error", "AddSharedAccount() Cannot Add Shared Account, Society Parameter Must Be Of Type Table With Fields .name and .label")
		return 
	end

	local socName = society.name
	local socLabel = society.label

	-- If Account Already Exists
    if SharedAccounts[socName] ~= nil then 
		return SharedAccounts[socName] 
	end

    local account = oxmysql:insert_async('INSERT INTO `addon_account` (name, label, shared) VALUES (?, ?, ?)', { socName, socLabel, 1 })

    if not account then 
		log("error", ("AddSharedAccount() Failed To Insert New Account: [^9%s^7]"):format(socName))
		return 
	end

    local account_data = oxmysql:insert_async('INSERT INTO `addon_account_data` (account_name, money) VALUES (?, ?)', { socName, (amount or 0) })

    if not account_data then 
		log("error", ("AddSharedAccount() Failed To Insert Into Account Data, Account: [^9%s^7]"):format(socName))
		return 
	end
	
    SharedAccounts[socName] = CreateAddonAccount(socName, nil, (amount or 0))
	GlobalSharedAccount[socName] = { money = amount }

	GlobalState.SharedAccounts = GlobalSharedAccount

    return SharedAccounts[socName]
end

local function RemoveSharedAccount(society)
	if not society then
		log("error", "RemoveSharedAccount() Cannot Remove A Null Society")
		return
	end

	local function Delete(_socName)
		if not _socName then
			log("error", "RemoveSharedAccount() Failed To Delete Shared Account. If Using Table Need Field .name, If String Use Society Name!")
			return
		end

		if not SharedAccounts[_socName] then
			log("error", ("RemoveSharedAccount() Society: [^9%s^7] Does Not Exist."):format(_socName))
			return
		end

		local query = oxmysql:query_async('DELETE FROM `addon_account` WHERE `name` = ?', { _socName })

		if not query or query.affectedRows < 1 then
			log("error", ("RemoveSharedAccount() Failed To Delete Shared Account: [^9%s^7]"):format(_socName))
			return
		end

		log("info", ("RemoveSharedAccount() Shared Account: [^9%s^7] Has Been Deleted."):format(_socName))

		local query2 = oxmysql:query_async('DELETE FROM `addon_account_data` WHERE `account_name` = ?', { _socName })

		if query2 and query2.affectedRows >= 1 then
			log("info", ("RemoveSharedAccount() Shared Account Data: [^9%s^7] Has Been Deleted."):format(_socName))
		end

		GlobalSharedAccount[_socName] = nil

		GlobalState.SharedAccounts = GlobalSharedAccount

		return true
	end

	if type(society) == "table" then
		local socName = society.name

		return Delete(socName)
	elseif type(society) == "string" then
		return Delete(society)
	end
end

-- On Start
AddEventHandler("onResourceStart", function(resourceName)
	if GetCurrentResourceName() ~= resourceName then
		return
	end

	local accounts = MySQL.query.await('SELECT * FROM addon_account LEFT JOIN addon_account_data ON addon_account.name = addon_account_data.account_name UNION SELECT * FROM addon_account RIGHT JOIN addon_account_data ON addon_account.name = addon_account_data.account_name')

	local newAccounts = {}

	for i = 1, #accounts do
		local account = accounts[i]
		if account.shared == 0 then
			if not Accounts[account.name] then
				AccountsIndex[#AccountsIndex + 1] = account.name
				Accounts[account.name] = {}
			end
			Accounts[account.name][#Accounts[account.name] + 1] = CreateAddonAccount(account.name, account.owner, account.money)
		else
			if account.money then
				SharedAccounts[account.name] = CreateAddonAccount(account.name, nil, account.money)
			else
				newAccounts[#newAccounts + 1] = {account.name, 0}
			end
		end

		if not account.owner then
			GlobalSharedAccount[account.name] = { money = account.money }
		end
	end

	GlobalState.SharedAccounts = GlobalSharedAccount

	if next(newAccounts) then
		MySQL.prepare('INSERT INTO addon_account_data (account_name, money) VALUES (?, ?)', newAccounts)
		for i = 1, #newAccounts do
			local newAccount = newAccounts[i]
			SharedAccounts[newAccount[1]] = CreateAddonAccount(newAccount[1], nil, 0)
		end
		-- GlobalState.SharedAccounts = SharedAccounts
	end
end)

AddEventHandler('esx_addonaccount:getAccount', function(name, owner, cb)
	-- log("warn", ("\"esx_addonaccount:getAccount\" Was Triggered By: [^9%s^7] And Is Deprecated"):format(GetInvokingResource()))
	cb(GetAccount(name, owner))
end)

AddEventHandler('esx_addonaccount:getSharedAccount', function(name, cb)
	-- log("warn", ("\"esx_addonaccount:getSharedAccount\" Was Triggered By: [^9%s^7] And Is Deprecated"):format(GetInvokingResource()))
	cb(GetSharedAccount(name))
end)

AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
	local addonAccounts = {}

	for i=1, #AccountsIndex, 1 do
		local name    = AccountsIndex[i]
		local account = GetAccount(name, xPlayer.identifier)

		if account == nil then
			MySQL.insert('INSERT INTO addon_account_data (account_name, money, owner) VALUES (?, ?, ?)', {name, 0, xPlayer.identifier})

			account = CreateAddonAccount(name, xPlayer.identifier, 0)
			Accounts[name][#Accounts[name] + 1] = account
		end

		addonAccounts[#addonAccounts + 1] = account
	end

	xPlayer.set('addonAccounts', addonAccounts)
end)

AddEventHandler("esx_addonaccount:refreshAccounts", function()			-- This Should Only Be A Server-Sided Event And Thus Must Not Be Triggered By Client!
	local result = MySQL.query.await('SELECT * FROM addon_account')

	for i = 1, #result, 1 do
		local name    = result[i].name
		local label   = result[i].label
		local shared  = result[i].shared

		local result2 = MySQL.query.await('SELECT * FROM addon_account_data WHERE account_name = ?', { name })

		if shared == 0 then
			table.insert(AccountsIndex, name)
			Accounts[name] = {}

			for j = 1, #result2, 1 do
				local addonAccount = CreateAddonAccount(name, result2[j].owner, result2[j].money)
				table.insert(Accounts[name], addonAccount)
			end
		else
			local money = nil

			if #result2 == 0 then
				MySQL.insert('INSERT INTO addon_account_data (account_name, money, owner) VALUES (?, ?, ?)',
					{ name, 0, NULL })
				money = 0
			else
				money = result2[1].money
			end

			local addonAccount   = CreateAddonAccount(name, nil, money)
			SharedAccounts[name] = addonAccount
		end
	end
end)

exports("AddMoney", AddMoney)
exports("RemoveMoney", RemoveMoney)
exports("SetMoney", SetMoney)
exports("GetAccount", GetAccount)
exports("GetSharedAccount", GetSharedAccount)
exports("AddSharedAccount", AddSharedAccount)
exports("RemoveSharedAccount", RemoveSharedAccount)