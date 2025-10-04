---@diagnostic disable: undefined-global
local ESX = exports['es_extended']:getSharedObject()

local function buildItemIndex()
    local index = {}
    for _, item in ipairs(Config.Items or {}) do
        index[item.name] = item
    end
    return index
end

local itemIndex = buildItemIndex()

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    itemIndex = buildItemIndex()
end)

local function calculateCartTotal(cart)
    local total = 0
    for _, entry in ipairs(cart or {}) do
        local def = itemIndex[entry.name]
        if def then
            local qty = tonumber(entry.amount) or 0
            if qty > 0 then
                total = total + (def.price * qty)
            end
        end
    end
    return total
end

ESX.RegisterServerCallback('esx_shops:purchase', function(source, cb, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        cb(false, _U('player_not_found'))
        return
    end

    local method = data and data.method or 'cash'
    local cart = data and data.cart or {}
    if type(cart) ~= 'table' or #cart == 0 then
        cb(false, _U('cart_empty'))
        return
    end

    local maxQty = Config.ItemMaxQuantity or 100

    local total = 0
    local normalizedCart = {}
    for _, entry in ipairs(cart) do
        if type(entry) ~= 'table' then
            cb(false, _U('invalid_cart_entry'))
            return
        end
        local name = entry.name
        local amount = tonumber(entry.amount)
        if not name or not amount then
            cb(false, _U('invalid_item_data'))
            return
        end
        local def = itemIndex[name]
        if not def then
            cb(false, _U('unknown_item', name))
            return
        end
        if amount < 1 or amount > maxQty then
            cb(false, _U('invalid_quantity'))
            return
        end
        total = total + (def.price * amount)
        normalizedCart[#normalizedCart + 1] = { name = name, amount = amount }
    end

    if method == 'bank' then
        if xPlayer.getAccount('bank').money < total then
            cb(false, _U('not_enough_bank'))
            return
        end
        xPlayer.removeAccountMoney('bank', total)
    else
        if xPlayer.getMoney() < total then
            cb(false, _U('not_enough_cash'))
            return
        end
        xPlayer.removeMoney(total)
    end

    for _, entry in ipairs(normalizedCart) do
        xPlayer.addInventoryItem(entry.name, entry.amount)
    end

    cb(true, _U('purchase_success'))
end)
