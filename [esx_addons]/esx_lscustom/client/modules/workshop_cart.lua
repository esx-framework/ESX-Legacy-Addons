-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

WorkshopCart = {
    items = {},
    total = 0
}

local function getCartKey(item)
    return tostring(item.modType or item.menuKey)
end

local function recalculateTotal()
    WorkshopCart.total = 0

    for _, item in pairs(WorkshopCart.items) do
        WorkshopCart.total = WorkshopCart.total + (tonumber(item.price) or 0)
    end
end

function WorkshopCart.Clear()
    WorkshopCart.items = {}
    WorkshopCart.total = 0
end

function WorkshopCart.Add(item)
    WorkshopCart.items[getCartKey(item)] = item
    recalculateTotal()
end

function WorkshopCart.GetTotal()
    return WorkshopCart.total
end

function WorkshopCart.GetList()
    local cart = {}

    for _, item in pairs(WorkshopCart.items) do
        cart[#cart + 1] = {
            menuKey = item.menuKey,
            modType = item.modType,
            modNum = item.modNum,
            wheelType = item.wheelType,
            price = item.price
        }
    end

    table.sort(cart, function(a, b)
        return tostring(a.menuKey) < tostring(b.menuKey)
    end)

    return cart
end

function WorkshopCart.GetPayload()
    local cart = {}

    for _, item in pairs(WorkshopCart.items) do
        cart[#cart + 1] = {
            label = item.label,
            price = item.price,
            menuKey = item.menuKey,
            modType = item.modType,
            modNum = item.modNum,
            wheelType = item.wheelType
        }
    end

    table.sort(cart, function(a, b)
        return tostring(a.label) < tostring(b.label)
    end)

    return cart
end
