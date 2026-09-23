-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

WorkshopPricing = {}

local function isPerformanceMod(modType)
    return modType == 11 or modType == 12 or modType == 13 or modType == 15 or modType == 16
end

local function isTurboMod(modType)
    return modType == 17 or modType == 18
end

local function getExpectedCartModType(menuKey, menu)
    if menu.modType == 23 then
        return 'modFrontWheels'
    elseif menu.modType == 24 then
        return 'modBackWheels'
    elseif type(menu.modType) == 'string' then
        return menu.modType
    elseif type(menu.modType) == 'number' then
        return menuKey
    end
end

function WorkshopPricing.NormalizeCartItem(item)
    if type(item) ~= 'table' then return nil, 'cartItem' end

    local menuKey = xLib.validation.string(item.menuKey, {maxLength = 64})
    local modType = xLib.validation.string(item.modType, {maxLength = 64})
    local menu = menuKey and Config.Menus[menuKey]

    if not menu or menu.modType == nil or not modType then
        return nil, 'menuKey'
    end

    local expectedModType = getExpectedCartModType(menuKey, menu)
    if modType ~= expectedModType then
        return nil, 'modType'
    end

    if modType == 'modFrontWheels' or modType == 'modBackWheels' then
        local modNum = xLib.validation.integer(item.modNum, -1, 255)
        local wheelType = xLib.validation.integer(item.wheelType, -1, 20)

        if not modNum or not wheelType then
            return nil, 'wheelType'
        end

        if modNum == -1 then
            if wheelType ~= -1 then return nil, 'wheelType' end
        elseif wheelType ~= menu.wheelType then
            return nil, 'wheelType'
        end
    end

    return {
        menuKey = menuKey,
        modType = modType,
        menu = menu
    }
end

function WorkshopPricing.CalculateCartItem(item, vehiclePrice)
    local normalized = WorkshopPricing.NormalizeCartItem(item)
    if not normalized then return nil end

    local modType = normalized.modType
    local menu = normalized.menu

    if modType == 'modFrontWheels' or modType == 'modBackWheels' then
        return math.floor(vehiclePrice * (tonumber(menu.price) or Config.DefaultWheelsPriceMultiplier) / 100)
    end

if isPerformanceMod(menu.modType) then
        local modNum = xLib.validation.integer(item.modNum, -1, 10)

        if not modNum then return nil end
        if modNum == -1 then return 0 end

        local pricePercent = menu.price and menu.price[modNum + 1]

        if not pricePercent then return nil end
        return math.floor(vehiclePrice * pricePercent / 100)
    end

    if isTurboMod(menu.modType) then
        if item.modNum ~= true and item.modNum ~= false then return nil end
        return math.floor(vehiclePrice * (tonumber(menu.price and menu.price[1]) or 0) / 100)
    end

    if menu.modType == 22 then
        if item.modNum ~= true and item.modNum ~= false then return nil end
        return math.floor(vehiclePrice * (tonumber(menu.price) or 0) / 100)
    end

    if type(menu.modType) == 'number' then
        if not xLib.validation.integer(item.modNum, -1, 255) then return nil end
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
