-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

WorkshopValidation = {}

local function propsEqual(left, right)
    if tonumber(left) and tonumber(right) and tonumber(left) == tonumber(right) then
        return true
    end

    if type(left) ~= type(right) then return false end

    if type(left) ~= 'table' then
        return left == right
    end

    for key, value in pairs(left) do
        if key ~= 'n' and not propsEqual(value, right[key]) then return false end
    end

    for key in pairs(right) do
        if key ~= 'n' and left[key] == nil then return false end
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

function WorkshopValidation.GetWatchedVehicleProps()
    return WatchedVehicleProps
end

local function getPaidVehicleProps(cart)
    local paid = {}

    for i = 1, #cart do
        local item = cart[i]
        local normalized, invalidField = WorkshopPricing.NormalizeCartItem(item)
        if not normalized then return nil, invalidField end

        local modType = normalized.modType
        paid[modType] = true

        if modType == 'modFrontWheels' or modType == 'modBackWheels' then
            paid.wheels = true
        elseif modType == 'neonColor' then
            paid.neonEnabled = true
        elseif modType == 'tyreSmokeColor' then
            paid.modSmokeEnabled = true
        elseif modType == 'xenonColor' then
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

    local paidKeys, invalidField = getPaidVehicleProps(cart)
    if not paidKeys then return false, invalidField end

    for key in pairs(WatchedVehicleProps) do
        if not paidKeys[key] and not propsEqual(originalProps[key], paidProps[key]) then
            return false, key
        end
    end

    return true
end

function WorkshopValidation.CartValuesMatchVehicleProps(paidProps, cart, originalProps)
    for i = 1, #cart do
        local item = cart[i]
        local normalized, invalidField = WorkshopPricing.NormalizeCartItem(item)
        if not normalized then return false, invalidField end

        local modType = normalized.modType

        if modType == 'modFrontWheels' or modType == 'modBackWheels' then
            if item.modNum == -1 then
                if not propsEqual(paidProps[modType], -1) then
                    return false, modType
                end
            elseif not propsEqual(paidProps[modType], item.modNum) or not propsEqual(paidProps.wheels, item.wheelType) then
                return false, modType
            end
        elseif modType == 'neonColor' then
            if not propsEqual(paidProps.neonColor, item.modNum) then
                return false, modType
            end
            local allOff = item.modNum and item.modNum[1] == 0 and item.modNum[2] == 0 and item.modNum[3] == 0
            if allOff then
                if propsEqual(paidProps.neonEnabled, {true, true, true, true}) then
                    return false, 'neonEnabled'
                end
            elseif not propsEqual(paidProps.neonEnabled, {true, true, true, true}) then
                return false, 'neonEnabled'
            end
        elseif modType == 'tyreSmokeColor' then
            if not propsEqual(paidProps.tyreSmokeColor, item.modNum) then
                return false, modType
            end
            local allOff = item.modNum and item.modNum[1] == 0 and item.modNum[2] == 0 and item.modNum[3] == 0
            if paidProps.modSmokeEnabled == true then
                if allOff then return false, modType end
            elseif not allOff then
                return false, modType
            end
        elseif modType == 'plateIndex' then
            if item.modNum == -1 then
                if type(originalProps) ~= 'table' or not propsEqual(paidProps.plateIndex, originalProps.plateIndex) then
                    return false, modType
                end
            elseif not propsEqual(paidProps.plateIndex, item.modNum) then
                return false, modType
            end
        elseif modType == 'windowTint' then
            if item.modNum == -1 then
                if type(originalProps) ~= 'table' or not propsEqual(paidProps.windowTint, originalProps.windowTint) then
                    return false, modType
                end
            elseif not propsEqual(paidProps.windowTint, item.modNum) then
                return false, modType
            end
        elseif modType == 'xenonColor' then
            if item.modNum == false then
                if paidProps.modXenon ~= false then
                    return false, modType
                end
            elseif not propsEqual(paidProps.xenonColor, item.modNum) or paidProps.modXenon ~= true then
                return false, modType
            end
        elseif modType == 'modXenon' then
            if item.modNum == false then
                if paidProps.modXenon ~= false then
                    return false, modType
                end
            elseif paidProps.modXenon ~= true then
                return false, modType
            end
        elseif modType == 'modTurbo' then
            if paidProps.modTurbo ~= true then
                return false, modType
            end
        elseif not propsEqual(paidProps[modType], item.modNum) then
            return false, modType
        end
    end

    return true
end
