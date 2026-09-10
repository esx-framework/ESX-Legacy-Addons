-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

WorkshopPricing = {}

local function isPerformanceMod(modType)
    return modType == 11 or modType == 12 or modType == 13 or modType == 15 or modType == 16
end

function WorkshopPricing.CalculateCartItem(item, vehiclePrice)
    if type(item) ~= 'table' then return nil end

    local menuKey = xLib.validation.string(item.menuKey, {maxLength = 64})
    local modType = xLib.validation.string(item.modType, {maxLength = 64})
    local menu = menuKey and Config.Menus[menuKey]

    if not menu or not menu.modType or not modType then
        return nil
    end

    if modType == 'modFrontWheels' or modType == 'modBackWheels' then
        if not xLib.validation.integer(item.modNum, -1, 255) then return nil end
        if not xLib.validation.integer(item.wheelType, -1, 20) then return nil end
        return math.floor(vehiclePrice * (tonumber(menu.price) or Config.DefaultWheelsPriceMultiplier) / 100)
    end

    if isPerformanceMod(menu.modType) then
        local modNum = xLib.validation.integer(item.modNum, 0, 10)
        local pricePercent = modNum and menu.price and menu.price[modNum + 1]

        if not pricePercent then return nil end
        return math.floor(vehiclePrice * pricePercent / 100)
    end

    if menu.modType == 17 then
        if item.modNum ~= true then return nil end
        return math.floor(vehiclePrice * (tonumber(menu.price and menu.price[1]) or 0) / 100)
    end

    if menu.modType == 22 then
        if item.modNum ~= true then return nil end
        return math.floor(vehiclePrice * (tonumber(menu.price) or 0) / 100)
    end

    if type(menu.modType) == 'number' then
        if not xLib.validation.integer(item.modNum, 0, 255) then return nil end
    elseif type(item.modNum) == 'table' then
        for i = 1, 3 do
            if not xLib.validation.integer(item.modNum[i], 0, 255) then return nil end
        end
    elseif item.modNum ~= false then
        if not xLib.validation.integer(item.modNum, -1, 255) then return nil end
    end

    return math.floor(vehiclePrice * (tonumber(menu.price) or 0) / 100)
end

function WorkshopPricing.CalculateCartTotal(cart, vehiclePrice)
    if type(cart) ~= 'table' or #cart == 0 or #cart > 40 then
        return nil
    end

    local total = 0

    for i = 1, #cart do
        local price = WorkshopPricing.CalculateCartItem(cart[i], vehiclePrice)
        if not price then return nil end
        total = total + price
    end

    return total
end
