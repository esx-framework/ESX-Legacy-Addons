-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

WorkshopNuiMenu = {}

local function addElement(elements, item, menuKey, menuConfig, vehiclePrice, currentMods, D)
    local label = D.CleanMenuLabel(item.label)
    local installed = D.IsDefaultOrInstalled(item.label)
    local price = 0

    if item.modType and menuConfig then
        price = installed and 0 or D.CalculateMenuPrice(menuKey, menuConfig, item, vehiclePrice)
    end

    elements[#elements + 1] = {
        label = label,
        value = item.value,
        action = item.modType and 'mod' or 'menu',
        menuKey = menuKey,
        modType = item.modType,
        modNum = item.modNum,
        wheelType = item.wheelType,
        color = item.color,
        price = price,
        installed = installed,
        disabled = item.value == 'noop',
        selected = item.modType and currentMods and currentMods[item.modType] == item.modNum
    }
end

function WorkshopNuiMenu.Build(data, D)
    data = data or { value = 'main' }

    local elements, menuName, menuTitle, parent = {}, '', 'LS CUSTOMS', nil
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    local currentMods = vehicle ~= 0 and xLib.game.getVehicleProperties(vehicle) or {}
    local vehiclePrice = vehicle ~= 0 and D.GetVehiclePrice(vehicle) or 50000
    local myCar = D.GetMyCar()

    if vehicle and vehicle ~= 0 then
        if data.value == 'modSpeakers' or data.value == 'modTrunk' or data.value == 'modHydrolic' or data.value ==
            'modEngineBlock' or data.value == 'modAirFilter' or data.value == 'modStruts' or data.value == 'modTank' then
            SetVehicleDoorOpen(vehicle, 4, false)
            SetVehicleDoorOpen(vehicle, 5, false)
        elseif data.value == 'modDoorSpeaker' then
            SetVehicleDoorOpen(vehicle, 0, false)
            SetVehicleDoorOpen(vehicle, 1, false)
            SetVehicleDoorOpen(vehicle, 2, false)
            SetVehicleDoorOpen(vehicle, 3, false)
        else
            SetVehicleDoorsShut(vehicle, false)
        end
    end

    for k, v in pairs(Config.Menus) do
        if data.value == k then
            menuName = k
            menuTitle = v.label
            parent = v.parent

            if v.modType then
                if v.modType == 22 or v.modType == 'xenonColor' then
                    addElement(elements, { label = TranslateCap('by_default'), modType = k, modNum = false }, k, v, vehiclePrice, currentMods, D)
                elseif v.modType == 'neonColor' or v.modType == 'tyreSmokeColor' then
                    addElement(elements, { label = TranslateCap('by_default'), modType = k, modNum = { 0, 0, 0 } }, k, v, vehiclePrice, currentMods, D)
                elseif v.modType == 'color1' or v.modType == 'color2' or v.modType == 'pearlescentColor' or v.modType == 'wheelColor' then
                    addElement(elements, { label = TranslateCap('by_default'), modType = k, modNum = myCar[v.modType] }, k, v, vehiclePrice, currentMods, D)
                elseif D.IsTurboMod(v.modType) then
                    addElement(elements, { label = TranslateCap('no_turbo'), modType = k, modNum = false }, k, v, vehiclePrice, currentMods, D)
                elseif v.modType == 23 then
                    addElement(elements, { label = TranslateCap('by_default'), modType = 'modFrontWheels', modNum = -1, wheelType = -1, price = Config.DefaultWheelsPriceMultiplier }, k, v, vehiclePrice, currentMods, D)
                elseif v.modType == 24 then
                    addElement(elements, { label = TranslateCap('by_default'), modType = 'modBackWheels', modNum = -1, wheelType = -1, price = Config.DefaultWheelsPriceMultiplier }, k, v, vehiclePrice, currentMods, D)
                else
                    addElement(elements, { label = TranslateCap('by_default'), modType = k, modNum = -1 }, k, v, vehiclePrice, currentMods, D)
                end

                if v.modType == 14 then
                    for j = 0, 51 do
                        local label = j == currentMods.modHorns and (GetHornName(j) .. ' - ' .. TranslateCap('installed')) or GetHornName(j)
                        addElement(elements, { label = label, modType = k, modNum = j }, k, v, vehiclePrice, currentMods, D)
                    end
                elseif v.modType == 'plateIndex' then
                    local maxJ = D.GetGameBuild() >= 3095 and 12 or 5
                    for j = 0, maxJ do
                        local label = j == currentMods.plateIndex and (GetPlatesName(j) .. ' - ' .. TranslateCap('installed')) or GetPlatesName(j)
                        addElement(elements, { label = label, modType = k, modNum = j }, k, v, vehiclePrice, currentMods, D)
                    end
                elseif v.modType == 22 then
                    local label = currentMods.modXenon and (v.label .. ' - ' .. TranslateCap('installed')) or v.label
                    addElement(elements, { label = label, modType = k, modNum = true }, k, v, vehiclePrice, currentMods, D)
                elseif v.modType == 'xenonColor' then
                    local xenonColors = GetXenonColors()
                    for i = 1, #xenonColors do
                        addElement(elements, { label = xenonColors[i].label, modType = k, modNum = xenonColors[i].index }, k, v, vehiclePrice, currentMods, D)
                    end
                elseif v.modType == 'neonColor' or v.modType == 'tyreSmokeColor' then
                    local neons = GetNeons()
                    for i = 1, #neons do
                        addElement(elements, { label = neons[i].label, modType = k, modNum = { neons[i].r, neons[i].g, neons[i].b } }, k, v, vehiclePrice, currentMods, D)
                    end
                elseif v.modType == 'color1' or v.modType == 'color2' or v.modType == 'pearlescentColor' or v.modType == 'wheelColor' then
                    local colors = GetColors(data.color)
                    for j = 1, #colors do
                        addElement(elements, { label = colors[j].label, modType = k, modNum = colors[j].index }, k, v, vehiclePrice, currentMods, D)
                    end
                elseif v.modType == 'windowTint' then
                    for j = 1, 5 do
                        local label = j == currentMods.windowTint and (GetWindowName(j) .. ' - ' .. TranslateCap('installed')) or GetWindowName(j)
                        addElement(elements, { label = label, modType = k, modNum = j }, k, v, vehiclePrice, currentMods, D)
                    end
                elseif v.modType == 23 or v.modType == 24 then
                    if vehicle and vehicle ~= 0 then
                        xLib.game.setVehicleProperties(vehicle, { wheels = v.wheelType })
                        local modType = v.modType == 24 and 'modBackWheels' or 'modFrontWheels'
                        local currentWheel = v.modType == 24 and currentMods.modBackWheels or currentMods.modFrontWheels
                        local modCount = GetNumVehicleMods(vehicle, v.modType)

                        for j = 0, modCount do
                            local modName = GetModTextLabel(vehicle, v.modType, j)
                            if modName then
                                local name = GetLabelText(modName)
                                local label = j == currentWheel and (name .. ' - ' .. TranslateCap('installed')) or name
                                addElement(elements, { label = label, modType = modType, modNum = j, wheelType = v.wheelType, price = v.price }, k, v, vehiclePrice, currentMods, D)
                            end
                        end
                    end
                elseif D.IsPerformanceMod(v.modType) then
                    if vehicle and vehicle ~= 0 then
                        SetVehicleModKit(vehicle, 0)
                        local modCount = GetNumVehicleMods(vehicle, v.modType)
                        for j = 0, modCount - 1 do
                            local label = j == currentMods[k] and (TranslateCap('level', j + 1) .. ' - ' .. TranslateCap('installed')) or TranslateCap('level', j + 1)
                            addElement(elements, { label = label, modType = k, modNum = j }, k, v, vehiclePrice, currentMods, D)
                        end
                    end
                elseif D.IsTurboMod(v.modType) then
                    local label = currentMods[k] and ('Turbo - ' .. TranslateCap('installed')) or 'Turbo'
                    addElement(elements, { label = label, modType = k, modNum = true }, k, v, vehiclePrice, currentMods, D)
                else
                    if vehicle and vehicle ~= 0 then
                        local modCount = GetNumVehicleMods(vehicle, v.modType)
                        for j = 0, modCount do
                            local modName = GetModTextLabel(vehicle, v.modType, j)
                            if modName then
                                local name = GetLabelText(modName)
                                local label = j == currentMods[k] and (name .. ' - ' .. TranslateCap('installed')) or name
                                addElement(elements, { label = label, modType = k, modNum = j }, k, v, vehiclePrice, currentMods, D)
                            end
                        end
                    end
                end
            elseif data.value == 'primaryRespray' or data.value == 'secondaryRespray' or data.value ==
                'pearlescentRespray' or data.value == 'modFrontWheelsColor' then
                for i = 1, #Config.Colors do
                    local value = data.value == 'primaryRespray' and 'color1' or data.value == 'secondaryRespray' and 'color2' or data.value == 'pearlescentRespray' and 'pearlescentColor' or 'wheelColor'
                    elements[#elements + 1] = {
                        label = Config.Colors[i].label,
                        value = value,
                        color = Config.Colors[i].value,
                        action = 'menu'
                    }
                end
            else
                for l, w in pairs(v) do
                    if l ~= 'label' and l ~= 'parent' then
                        local action = 'menu'
                        if l == 'cartCheckout' then action = 'checkout'
                        elseif l == 'cartClear' then action = 'clear'
                        elseif l == 'vehicleStats' then action = 'stats'
                        elseif l == 'cameraMenu' then action = 'camera' end

                        elements[#elements + 1] = {
                            label = D.CleanMenuLabel(w),
                            value = l,
                            action = action,
                            disabled = action == 'checkout' and D.GetCartTotal() <= 0
                        }
                    end
                end
            end

            break
        end
    end

    table.sort(elements, function(a, b)
        return tostring(a.label) < tostring(b.label)
    end)

    return {
        id = menuName,
        title = D.CleanMenuLabel(menuTitle),
        parent = parent,
        elements = elements
    }
end
