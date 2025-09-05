Database = {}

---@class DatabaseAccountRow
---@field name string
---@field label string
---@field shared number
---@field id number
---@field account_name? string
---@field money number
---@field owner? string

---@param name string
---@param owner string
---@return DatabaseAccountRow?
function Database.fetchAccount(name, owner)
    local accountData = MySQL.single.await([[
        SELECT * FROM addon_account aa
        FULL OUTER JOIN addon_account_data aad ON aa.name = aad.account_name
        WHERE aa.shared = 0 AND aa.name = ? AND aad.owner = ?
    ]], { name, owner })

    return accountData
end

---@param name string
---@return DatabaseAccountRow?
function Database.fetchSharedAccount(name)
    local accountData = MySQL.single.await([[
        SELECT * FROM addon_account aa
        FULL OUTER JOIN addon_account_data aad ON aa.name = aad.account_name
        WHERE aa.shared = 1 AND aa.name = ?
    ]], { name })

    return accountData
end

function Database.saveAccounts()
    local params, n = {}, 0
    for _, accountData in pairs(Accounts) do
        for owner, account in pairs(accountData) do
            n += 1
            params[n] = { account.money, account.name, owner }
        end
    end

    for _, account in pairs(SharedAccounts) do
        n += 1
        params[n] = { account.money, account.name }
    end

    MySQL.prepare.await([[
        UPDATE addon_account_data SET money = ? WHERE account_name = ? AND owner = ?;
    ]], params)
end
