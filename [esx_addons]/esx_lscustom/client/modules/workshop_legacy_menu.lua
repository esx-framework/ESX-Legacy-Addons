-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local function deps()
    return LSCustomLegacyDeps or error('[esx_lscustom] legacy menu dependencies are not ready', 2)
end

function OpenLSMenu(elems, menuName, menuTitle, parent)
    local D = deps()

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), menuName, {
        title = menuTitle,
        align = 'top-left',
        elements = elems
    }, function(data, menu)
        local isRimMod, found = false, false
        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)

        if data.current.value == 'cartCheckout' or data.current.value == 'cartClear' or data.current.value == 'vehicleStats' or data.current.value == 'cameraMenu' then
            menu.close()
            D.HandleWorkshopAction(data.current, parent)
            return
        end

        if data.current.modType == 'modFrontWheels' or data.current.modType == 'modBackWheels' then
            isRimMod = true
        end

        if isRimMod then
            local wheelMenuKey, wheelMenu = D.FindWheelMenu(data.current)
            if not wheelMenu then
                ESX.ShowNotification(TranslateCap('wheel_unavailable'))
                return
            end

            if D.IsDefaultOrInstalled(data.current.label) then
                ESX.ShowNotification(TranslateCap('already_own', data.current.label))
            else
                local price = D.CalculateMenuPrice(wheelMenuKey, wheelMenu, data.current, D.GetVehiclePrice(vehicle))
                D.AddCartItem({
                    label = D.CleanMenuLabel(data.current.label),
                    menuKey = wheelMenuKey,
                    modType = data.current.modType,
                    modNum = data.current.modNum,
                    wheelType = data.current.wheelType,
                    price = price
                })
                D.SetCartPreviewProps(xLib.game.getVehicleProperties(vehicle))
                ESX.ShowNotification(TranslateCap('added_to_cart', D.FormatMoney(price), D.FormatMoney(D.GetCartTotal())))
            end

            menu.close()
            GetAction({ value = parent or 'main' })
            return
        end

        for k, v in pairs(Config.Menus) do
            if k == data.current.modType then
                if D.IsDefaultOrInstalled(data.current.label) then
                    ESX.ShowNotification(TranslateCap('already_own', data.current.label))
                else
                    local price = D.CalculateMenuPrice(k, v, data.current, D.GetVehiclePrice(vehicle))
                    D.AddCartItem({
                        label = D.CleanMenuLabel(data.current.label),
                        menuKey = k,
                        modType = data.current.modType,
                        modNum = data.current.modNum,
                        wheelType = data.current.wheelType,
                        price = price
                    })
                    D.SetCartPreviewProps(xLib.game.getVehicleProperties(vehicle))
                    ESX.ShowNotification(TranslateCap('added_to_cart', D.FormatMoney(price), D.FormatMoney(D.GetCartTotal())))
                end

                menu.close()
                GetAction({ value = parent or 'main' })
                found = true
                break
            end
        end

        if not found then
            GetAction(data.current)
        end
    end, function(_, menu)
        menu.close()

        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        if vehicle and vehicle ~= 0 then
            SetVehicleDoorsShut(vehicle, false)
        end

        if parent == nil then
            D.CloseWorkshop(false)
        else
            D.RestoreVehicleProps(vehicle, D.GetCartPreviewProps())
            GetAction({ value = parent })
        end
    end, function(data)
        D.UpdateMods(data.current)
    end)
end

function GetAction(data)
    local D = deps()
    local elements = {}
    local menuName = ''
    local menuTitle = ''
    local parent = nil

    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    local currentMods = xLib.game.getVehicleProperties(vehicle)
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

    local vehiclePrice = D.GetVehiclePrice(vehicle)
    local myCar = D.GetMyCar()

    for k, v in pairs(Config.Menus) do
        if data.value == k then
            menuName = k
            menuTitle = v.label
            parent = v.parent

            if v.modType then
                if v.modType == 22 or v.modType == 'xenonColor' then
                    elements[#elements + 1] = {
                        label = ' ' .. TranslateCap('by_default'),
                        modType = k,
                        modNum = false
                    }
                elseif v.modType == 'neonColor' or v.modType == 'tyreSmokeColor' then
                    elements[#elements + 1] = {
                        label = ' ' .. TranslateCap('by_default'),
                        modType = k,
                        modNum = {0, 0, 0}
                    }
                elseif v.modType == 'color1' or v.modType == 'color2' or v.modType == 'pearlescentColor' or v.modType ==
                    'wheelColor' then
                    elements[#elements + 1] = {
                        label = ' ' .. TranslateCap('by_default'),
                        modType = k,
                        modNum = myCar[v.modType]
                    }
                elseif D.IsTurboMod(v.modType) then
                    elements[#elements + 1] = {
                        label = ' ' .. TranslateCap('no_turbo'),
                        modType = k,
                        modNum = false
                    }
                elseif v.modType == 23 then
                    elements[#elements + 1] = {
                        label = ' ' .. TranslateCap('by_default'),
                        modType = 'modFrontWheels',
                        modNum = -1,
                        wheelType = -1,
                        price = Config.DefaultWheelsPriceMultiplier
                    }
                elseif v.modType == 24 then
                    elements[#elements + 1] = {
                        label = ' ' .. TranslateCap('by_default'),
                        modType = 'modBackWheels',
                        modNum = -1,
                        wheelType = -1,
                        price = Config.DefaultWheelsPriceMultiplier
                    }
                else
                    elements[#elements + 1] = {
                        label = ' ' .. TranslateCap('by_default'),
                        modType = k,
                        modNum = -1
                    }
                end

                if v.modType == 14 then
                    for j = 0, 51, 1 do
                        local label = ''
                        if j == currentMods.modHorns then
                            label = GetHornName(j) .. ' - <span style="color:cornflowerblue;">' .. TranslateCap('installed') .. '</span>'
                        else
                            local price = math.floor(vehiclePrice * v.price / 100)
                            label = GetHornName(j) .. ' - <span style="color:green;">$' .. price .. ' </span>'
                        end
                        elements[#elements + 1] = { label = label, modType = k, modNum = j }
                    end
                elseif v.modType == 'plateIndex' then
                    local maxJ = D.GetGameBuild() >= 3095 and 12 or 5
                    for j = 0, maxJ, 1 do
                        local label = ''
                        if j == currentMods.plateIndex then
                            label = GetPlatesName(j) .. ' - <span style="color:cornflowerblue;">' .. TranslateCap('installed') .. '</span>'
                        else
                            local price = math.floor(vehiclePrice * v.price / 100)
                            label = GetPlatesName(j) .. ' - <span style="color:green;">$' .. price .. ' </span>'
                        end
                        elements[#elements + 1] = { label = label, modType = k, modNum = j }
                    end
                elseif v.modType == 22 then
                    local label = ''
                    if currentMods.modXenon then
                        label = v.label .. ' - <span style="color:cornflowerblue;">' .. TranslateCap('installed') .. '</span>'
                    else
                        local price = math.floor(vehiclePrice * v.price / 100)
                        label = v.label .. ' - <span style="color:green;">$' .. price .. ' </span>'
                    end
                    elements[#elements + 1] = { label = label, modType = k, modNum = true }
                elseif v.modType == 'xenonColor' then
                    local xenonColors = GetXenonColors()
                    local price = math.floor(vehiclePrice * v.price / 100)
                    for i = 1, #xenonColors, 1 do
                        elements[#elements + 1] = {
                            label = xenonColors[i].label .. ' - <span style="color:green;">$' .. price .. '</span>',
                            modType = k,
                            modNum = xenonColors[i].index
                        }
                    end
                elseif v.modType == 'neonColor' or v.modType == 'tyreSmokeColor' then
                    local neons = GetNeons()
                    local price = math.floor(vehiclePrice * v.price / 100)
                    for i = 1, #neons, 1 do
                        elements[#elements + 1] = {
                            label = '<span style="color:rgb(' .. neons[i].r .. ',' .. neons[i].g .. ',' .. neons[i].b ..
                                ');">' .. neons[i].label .. ' - <span style="color:green;">$' .. price .. '</span>',
                            modType = k,
                            modNum = {neons[i].r, neons[i].g, neons[i].b}
                        }
                    end
                elseif v.modType == 'color1' or v.modType == 'color2' or v.modType == 'pearlescentColor' or v.modType ==
                    'wheelColor' then
                    local colors = GetColors(data.color)
                    for j = 1, #colors, 1 do
                        local price = math.floor(vehiclePrice * v.price / 100)
                        elements[#elements + 1] = {
                            label = colors[j].label .. ' - <span style="color:green;">$' .. price .. ' </span>',
                            modType = k,
                            modNum = colors[j].index
                        }
                    end
                elseif v.modType == 'windowTint' then
                    for j = 1, 5, 1 do
                        local label = ''
                        if j == currentMods.windowTint then
                            label = GetWindowName(j) .. ' - <span style="color:cornflowerblue;">' .. TranslateCap('installed') .. '</span>'
                        else
                            local price = math.floor(vehiclePrice * v.price / 100)
                            label = GetWindowName(j) .. ' - <span style="color:green;">$' .. price .. ' </span>'
                        end
                        elements[#elements + 1] = { label = label, modType = k, modNum = j }
                    end
                elseif v.modType == 23 then
                    xLib.game.setVehicleProperties(vehicle, { wheels = v.wheelType })
                    local modCount = GetNumVehicleMods(vehicle, v.modType)
                    for j = 0, modCount, 1 do
                        local modName = GetModTextLabel(vehicle, v.modType, j)
                        if modName then
                            local label = ''
                            if j == currentMods.modFrontWheels then
                                label = GetLabelText(modName) .. ' - <span style="color:cornflowerblue;">' .. TranslateCap('installed') .. '</span>'
                            else
                                local price = math.floor(vehiclePrice * v.price / 100)
                                label = GetLabelText(modName) .. ' - <span style="color:green;">$' .. price .. ' </span>'
                            end
                            elements[#elements + 1] = {
                                label = label,
                                modType = 'modFrontWheels',
                                modNum = j,
                                wheelType = v.wheelType,
                                price = v.price
                            }
                        end
                    end
                elseif v.modType == 24 then
                    xLib.game.setVehicleProperties(vehicle, { wheels = v.wheelType })
                    local modCount = GetNumVehicleMods(vehicle, v.modType)
                    for j = 0, modCount, 1 do
                        local modName = GetModTextLabel(vehicle, v.modType, j)
                        if modName then
                            local label = ''
                            if j == currentMods.modBackWheels then
                                label = GetLabelText(modName) .. ' - <span style="color:cornflowerblue;">' .. TranslateCap('installed') .. '</span>'
                            else
                                local price = math.floor(vehiclePrice * v.price / 100)
                                label = GetLabelText(modName) .. ' - <span style="color:green;">$' .. price .. ' </span>'
                            end
                            elements[#elements + 1] = {
                                label = label,
                                modType = 'modBackWheels',
                                modNum = j,
                                wheelType = v.wheelType,
                                price = v.price
                            }
                        end
                    end
                elseif v.modType == 11 or v.modType == 12 or v.modType == 13 or v.modType == 15 or v.modType == 16 then
                    SetVehicleModKit(vehicle, 0)
                    local modCount = GetNumVehicleMods(vehicle, v.modType)
                    for j = 0, modCount, 1 do
                        local label = ''
                        if j == currentMods[k] then
                            label = TranslateCap('level', j + 1) .. ' - <span style="color:cornflowerblue;">' .. TranslateCap('installed') .. '</span>'
                        else
                            local price = math.floor(vehiclePrice * v.price[j + 1] / 100)
                            label = TranslateCap('level', j + 1) .. ' - <span style="color:green;">$' .. price .. ' </span>'
                        end
                        elements[#elements + 1] = { label = label, modType = k, modNum = j }
                        if j == modCount - 1 then break end
                    end
                elseif D.IsTurboMod(v.modType) then
                    local label = ''
                    if currentMods[k] then
                        label = 'Turbo - <span style="color:cornflowerblue;">' .. TranslateCap('installed') .. '</span>'
                    else
                        label = 'Turbo - <span style="color:green;">$' .. math.floor(vehiclePrice * v.price[1] / 100) .. ' </span>'
                    end
                    elements[#elements + 1] = { label = label, modType = k, modNum = true }
                else
                    local modCount = GetNumVehicleMods(vehicle, v.modType)
                    for j = 0, modCount, 1 do
                        local modName = GetModTextLabel(vehicle, v.modType, j)
                        if modName then
                            local label = ''
                            if j == currentMods[k] then
                                label = GetLabelText(modName) .. ' - <span style="color:cornflowerblue;">' .. TranslateCap('installed') .. '</span>'
                            else
                                local price = math.floor(vehiclePrice * v.price / 100)
                                label = GetLabelText(modName) .. ' - <span style="color:green;">$' .. price .. ' </span>'
                            end
                            elements[#elements + 1] = { label = label, modType = k, modNum = j }
                        end
                    end
                end
            elseif data.value == 'primaryRespray' or data.value == 'secondaryRespray' or data.value ==
                'pearlescentRespray' or data.value == 'modFrontWheelsColor' then
                for i = 1, #Config.Colors, 1 do
                    if data.value == 'primaryRespray' then
                        elements[#elements + 1] = { label = Config.Colors[i].label, value = 'color1', color = Config.Colors[i].value }
                    elseif data.value == 'secondaryRespray' then
                        elements[#elements + 1] = { label = Config.Colors[i].label, value = 'color2', color = Config.Colors[i].value }
                    elseif data.value == 'pearlescentRespray' then
                        elements[#elements + 1] = { label = Config.Colors[i].label, value = 'pearlescentColor', color = Config.Colors[i].value }
                    elseif data.value == 'modFrontWheelsColor' then
                        elements[#elements + 1] = { label = Config.Colors[i].label, value = 'wheelColor', color = Config.Colors[i].value }
                    end
                end
            else
                for l, w in pairs(v) do
                    if l ~= 'label' and l ~= 'parent' then
                        local label = w
                        if l == 'cartCheckout' then
                            label = ('%s (%s)'):format(w, D.FormatMoney(D.GetCartTotal()))
                        end
                        elements[#elements + 1] = { label = label, value = l }
                    end
                end
            end
            break
        end
    end

    table.sort(elements, function(a, b)
        return a.label < b.label
    end)

    OpenLSMenu(elements, menuName, menuTitle, parent)
end
