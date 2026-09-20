-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

WorkshopVehicle = {}

function WorkshopVehicle.IsPerformanceMod(modType)
    return modType == 11 or modType == 12 or modType == 13 or modType == 15 or modType == 16
end

function WorkshopVehicle.IsTurboMod(modType)
    return modType == 17 or modType == 18
end

function WorkshopVehicle.GetPrice(vehicle, vehicles)
    local vehiclePrice = 50000

    for i = 1, #(vehicles or {}), 1 do
        if GetEntityModel(vehicle) == joaat(vehicles[i].model) then
            vehiclePrice = tonumber(vehicles[i].price) or vehiclePrice
            break
        end
    end

    return vehiclePrice
end

function WorkshopVehicle.CalculateMenuPrice(_, menuConfig, current, vehiclePrice)
    if not menuConfig or not menuConfig.modType or not current then return 0 end

    if current.modType == 'modFrontWheels' or current.modType == 'modBackWheels' then
        return math.floor(vehiclePrice * (tonumber(current.price) or Config.DefaultWheelsPriceMultiplier) / 100)
    end

    if WorkshopVehicle.IsPerformanceMod(menuConfig.modType) then
        local pricePercent = menuConfig.price and menuConfig.price[(tonumber(current.modNum) or -1) + 1]
        return math.floor(vehiclePrice * (tonumber(pricePercent) or 0) / 100)
    end

    if WorkshopVehicle.IsTurboMod(menuConfig.modType) then
        return math.floor(vehiclePrice * (tonumber(menuConfig.price and menuConfig.price[1]) or 0) / 100)
    end

    return math.floor(vehiclePrice * (tonumber(menuConfig.price) or 0) / 100)
end

function WorkshopVehicle.FindWheelMenu(current)
    if not current or not current.wheelType then return nil, nil end

    local nativeModType = current.modType == 'modBackWheels' and 24 or 23
    for key, menu in pairs(Config.Menus) do
        if menu.modType == nativeModType and menu.wheelType == current.wheelType then
            return key, menu
        end
    end

    return nil, nil
end

local function cartHasMod(cart, modType)
    for i = 1, #cart do
        if cart[i].modType == modType then
            return true
        end
    end

    return false
end

function WorkshopVehicle.NormalizePropsForPaidCart(vehicleProps, cart, originalProps)
    if type(vehicleProps) ~= 'table' or type(cart) ~= 'table' or type(originalProps) ~= 'table' then return vehicleProps end

    if cartHasMod(cart, 'tyreSmokeColor') then
        vehicleProps.modSmokeEnabled = true
    else
        vehicleProps.modSmokeEnabled = originalProps.modSmokeEnabled == true
        vehicleProps.tyreSmokeColor = originalProps.tyreSmokeColor
    end

    if cartHasMod(cart, 'neonColor') then
        vehicleProps.neonEnabled = { true, true, true, true }
    else
        vehicleProps.neonEnabled = originalProps.neonEnabled
        vehicleProps.neonColor = originalProps.neonColor
    end

    if cartHasMod(cart, 'xenonColor') or cartHasMod(cart, 'modXenon') then
        vehicleProps.modXenon = true
    else
        vehicleProps.modXenon = originalProps.modXenon == true
    end

    if not cartHasMod(cart, 'xenonColor') then
        vehicleProps.xenonColor = originalProps.xenonColor
    end

    return vehicleProps
end

function WorkshopVehicle.RestoreProps(vehicle, props)
    if not vehicle or vehicle == 0 or type(props) ~= 'table' then return end

    xLib.game.setVehicleProperties(vehicle, props)
    if not props.modTurbo then
        ToggleVehicleMod(vehicle, 18, false)
    end
    if not props.modXenon then
        ToggleVehicleMod(vehicle, 22, false)
    end
    if props.modSmokeEnabled ~= true then
        ToggleVehicleMod(vehicle, 20, false)
    end
    if not props.windowTint then
        SetVehicleWindowTint(vehicle, 0)
    end
end
