Database = {}

---@class DatabaseInventoryRow
---@field name string
---@field label string
---@field shared number

---@class DatabaseInventoryItemRow
---@field id number
---@field inventory_name string
---@field name string
---@field count number
---@field owner? string

---@param name string
---@param shared? boolean
---@return DatabaseInventoryRow?
function Database.fetchInventory(name, shared)
    return MySQL.single.await('SELECT * FROM addon_inventory WHERE name = ? AND shared = ?', { name, shared and 1 or 0 })
end

---@param name string
---@param owner? string
---@return DatabaseInventoryItemRow[]
function Database.fetchInventoryItems(name, owner)
    if owner then
        return MySQL.query.await('SELECT * FROM addon_inventory_items WHERE inventory_name = ? AND owner = ?', { name, owner })
    end

    return MySQL.query.await('SELECT * FROM addon_inventory_items WHERE inventory_name = ?', { name })
end

function Database.saveInventories()
    warn('Not implemented yet.')
end
