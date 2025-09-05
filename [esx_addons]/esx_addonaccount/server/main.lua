Accounts, SharedAccounts = {}, {}

---@param name string
---@param owner string
---@return AddonAccount?
local function getAccount(name, owner)
    local existingAccount = Accounts[name][owner]
    if existingAccount then
        return existingAccount
    end

    local dbAccount = Database.fetchAccount(name, owner)
    if not dbAccount then return end

    if not Accounts[name] then
        Accounts[name] = {}
    end

    Accounts[name][owner] = CreateAddonAccount(name, owner, dbAccount.money)

    return Accounts[name][owner]
end

---@param name string
---@return AddonAccount?
local function getSharedAccount(name)
    local existingAccount = SharedAccounts[name]
    if existingAccount then
        return existingAccount
    end

    local dbAccount = Database.fetchSharedAccount(name)
    if not dbAccount then return end

    local money = dbAccount.money
    SharedAccounts[name] = CreateAddonAccount(name, nil, money or 0)

    if not money then
        MySQL.prepare.await('INSERT INTO addon_account_data (account_name, money) VALUES (?, ?)', { name, 0 })
    end

    GlobalState.SharedAccounts = SharedAccounts

    return SharedAccounts[name]
end

---@param society { name: string, label: string }
---@param amount? number
---@return AddonAccount?
local function addSharedAccount(society, amount)
    local societyName, societyLabel = society?.name, society?.label
    if not societyName or not societyLabel then return end

    local existingSharedAccount = getSharedAccount(societyName)
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

---@param name string
---@param owner string
---@param amount number
local function addAccountMoney(name, owner, amount)
    local account = getAccount(name, owner)
    if not account then return end

    account.addMoney(amount)
end

---@param name string
---@param owner string
---@param amount number
local function removeAccountMoney(name, owner, amount)
    local account = getAccount(name, owner)
    if not account then return end

    account.removeMoney(amount)
end

---@param name string
---@param owner string
---@param amount number
local function setAccountMoney(name, owner, amount)
    local account = getAccount(name, owner)
    if not account then return end

    account.setMoney(amount)
end

---@param name string
---@param amount number
local function addSharedAccountMoney(name, amount)
    local account = getSharedAccount(name)
    if not account then return end

    account.addMoney(amount)
end

---@param name string
---@param amount number
local function removeSharedAccountMoney(name, amount)
    local account = getSharedAccount(name)
    if not account then return end

    account.removeMoney(amount)
end

---@param name string
---@param amount number
local function setSharedAccountMoney(name, amount)
    local account = getSharedAccount(name)
    if not account then return end

    account.setMoney(amount)
end

AddEventHandler('esx:playerLoaded', function(_, xPlayer)
    local addonAccounts = {}

    local identifier = xPlayer.getIdentifier()
    for _, accountName in pairs(Accounts) do
        local account = getAccount(accountName, identifier)

        if not account then
            MySQL.insert.await('INSERT INTO addon_account_data (account_name, money, owner) VALUES (?, ?, ?)',
                { accountName, 0, identifier })

            account = CreateAddonAccount(accountName, identifier, 0)

            Accounts[accountName][identifier] = account
        end

        addonAccounts[#addonAccounts + 1] = account
    end

    xPlayer.set('addonAccounts', addonAccounts)
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

AddEventHandler('txAdmin:events:scheduledRestart', function(eventData)
    if eventData.secondsRemaining == 60 then
        CreateThread(function()
            Wait(50000)
            Database.saveAccounts()
        end)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        Database.saveAccounts()
    end
end)

AddEventHandler('txAdmin:events:serverShuttingDown', Database.saveAccounts)

exports('GetSharedAccount', getSharedAccount)
exports('GetAccount', getAccount)

exports('AddSharedAccount', addSharedAccount)

exports('AddAccountMoney', addAccountMoney)
exports('RemoveAccountMoney', removeAccountMoney)
exports('SetAccountMoney', setAccountMoney)

exports('AddSharedAccountMoney', addSharedAccountMoney)
exports('RemoveSharedAccountMoney', removeSharedAccountMoney)
exports('SetSharedAccountMoney', setSharedAccountMoney)
