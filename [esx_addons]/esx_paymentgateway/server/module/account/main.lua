-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- The money side of a payment: reading balances and taking money from an ESX account in a way
--- that can be trusted. ESX refuses some removals and only says so through its return value (a
--- missing account, cover lost to rounding, a player who is logging out), and ox_inventory's
--- override takes from non-item accounts without checking cover. So every charge is checked
--- before, guarded while it runs and proven after.

local Account = {}

--- ESX 1.16 gives every player these, but does not list them on StaticPlayer yet.
---@class StaticPlayer
---@field beginAccountOperation fun(): boolean
---@field endAccountOperation fun()

---@param message string
local function warn(message)
    print(("[^3WARNING^7] esx_paymentgateway: %s"):format(message))
end

---@param player StaticPlayer
---@param account string ESX account name
---@return number|nil money Balance, nil when the account cannot be read
local function money(player, account)
    local ok, data = pcall(player.getAccount, account)
    if not ok or type(data) ~= "table" then return nil end
    return tonumber(data.money)
end

---@param player StaticPlayer
---@param method PaymentMethod
---@return number
local function balanceOf(player, method)
    local account = Config.Accounts[method]
    return account and math.max(0, money(player, account) or 0) or 0
end

---The player's balance for both methods. A method without an account shows 0, so the dialog
---always gets both, also on servers that pay only in cash or only by card.
---@param player StaticPlayer
---@return table<PaymentMethod, number>
function Account.balances(player)
    return {
        cash = balanceOf(player, "cash"),
        card = balanceOf(player, "card"),
    }
end

---Takes money from a player's account and proves it was taken.
---@param player StaticPlayer
---@param playerId integer Server id of the player, for warnings
---@param account string ESX account name
---@param amount integer
---@param reason string Shown in ESX's account logs
---@return boolean charged
---@return "insufficient"|"failed"|nil failure Why nothing was taken
function Account.charge(player, playerId, account, amount, reason)
    local before = money(player, account)
    if not before or before < amount then return false, "insufficient" end

    -- ESX refuses account changes while a player logs out; versions without the guard skip it.
    local guarded, began = pcall(player.beginAccountOperation)
    if guarded and began == false then return false, "failed" end

    local called, removed = pcall(player.removeAccountMoney, account, amount, reason)
    if guarded and began then pcall(player.endAccountOperation) end

    local after = money(player, account)
    local dropped = after and before - after

    if not called or removed == false then
        if not called then warn(("removeAccountMoney failed: %s"):format(removed)) end
        return false, "failed"
    end

    if removed == true then
        if dropped ~= amount then
            warn(("player %s, %s: ESX took %s but the balance moved by %s"):format(
                playerId, account, amount, dropped))
        end
        return true
    end

    -- Versions that return nothing: only the balance can tell whether the money was taken.
    if dropped == amount then return true end
    warn(("player %s, %s: tried to take %s, the balance moved by %s"):format(
        playerId, account, amount, dropped))
    return false, "failed"
end

return Account
