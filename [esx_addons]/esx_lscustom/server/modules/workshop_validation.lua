-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

WorkshopValidation = {}

local function propsEqual(left, right)
    if type(left) ~= type(right) then return false end

    if type(left) ~= 'table' then
        return left == right
    end

    for key, value in pairs(left) do
        if not propsEqual(value, right[key]) then return false end
    end

    for key in pairs(right) do
        if left[key] == nil then return false end
    end

    return true
end

local function getWatchedVehicleProps()
    local watched = {
        wheels = true,
        modFrontWheels = true,
        modBackWheels = true,
        modSmokeEnabled = true,
        neonEnabled = true,
        modXenon = true
    }

    for key, menu in pairs(Config.Menus) do
        if menu.modType then
            if type(menu.modType) == 'string' then
                watched[menu.modType] = true
            else
                watched[key] = true
            end
        end
    end

    return watched
end

local WatchedVehicleProps = getWatchedVehicleProps()

local function getPaidVehicleProps(cart)
    local paid = {}

    for i = 1, #cart do
        local item = cart[i]
        paid[item.modType] = true

        if item.modType == 'modFrontWheels' or item.modType == 'modBackWheels' then
            paid.wheels = true
        elseif item.modType == 'neonColor' then
            paid.neonEnabled = true
        elseif item.modType == 'tyreSmokeColor' then
            paid.modSmokeEnabled = true
        elseif item.modType == 'xenonColor' then
            paid.modXenon = true
        end
    end

    return paid
end

function WorkshopValidation.WatchedVehiclePropsEqual(left, right)
    if type(left) ~= 'table' or type(right) ~= 'table' then return false end

    for key in pairs(WatchedVehicleProps) do
        if not propsEqual(left[key], right[key]) then
            return false, key
        end
    end

    return true
end

function WorkshopValidation.VehiclePropsMatchPaidCart(originalProps, paidProps, cart)
    if type(originalProps) ~= 'table' or type(paidProps) ~= 'table' or type(cart) ~= 'table' then
        return false
    end

    local paidKeys = getPaidVehicleProps(cart)

    for key in pairs(WatchedVehicleProps) do
        if not paidKeys[key] and not propsEqual(originalProps[key], paidProps[key]) then
            return false, key
        end
    end

    return true
end

function WorkshopValidation.CartValuesMatchVehicleProps(paidProps, cart)
    for i = 1, #cart do
        local item = cart[i]

        if item.modType == 'modFrontWheels' or item.modType == 'modBackWheels' then
            if not propsEqual(paidProps[item.modType], item.modNum) or not propsEqual(paidProps.wheels, item.wheelType) then
                return false, item.modType
            end
        elseif item.modType == 'neonColor' then
            if not propsEqual(paidProps.neonColor, item.modNum) then
                return false, item.modType
            end
            if not propsEqual(paidProps.neonEnabled, {true, true, true, true}) then
                return false, 'neonEnabled'
            end
        elseif item.modType == 'tyreSmokeColor' then
            if not propsEqual(paidProps.tyreSmokeColor, item.modNum) or paidProps.modSmokeEnabled ~= true then
                return false, item.modType
            end
        elseif item.modType == 'xenonColor' then
            if not propsEqual(paidProps.xenonColor, item.modNum) or paidProps.modXenon ~= true then
                return false, item.modType
            end
        elseif not propsEqual(paidProps[item.modType], item.modNum) then
            return false, item.modType
        end
    end

    return true
end
