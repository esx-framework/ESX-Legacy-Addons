-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local Vehicles, myCar = {}, {}
local lsMenuIsShowed, HintDisplayed, isInLSMarker = false, false, false
local gameBuild = GetGameBuildNumber()
local tuningCart, tuningCartTotal, pendingCartPurchase = {}, 0, false
local cartPreviewProps, lastPaidVehicleProps
local nuiIsOpen, currentNuiMenu, currentNuiColor = false, 'main', nil
local CloseWorkshop
local SendNuiState

function IsLSCustomNuiOpen()
    return nuiIsOpen
end

local function FormatMoney(amount)
    return ("%s%s"):format(Config.Currency or "$", ESX.Math.GroupDigits(ESX.Math.Round(amount or 0)))
end

local function GetVehiclePrice(vehicle)
    local vehiclePrice = 50000

    for i = 1, #Vehicles, 1 do
        if GetEntityModel(vehicle) == joaat(Vehicles[i].model) then
            vehiclePrice = tonumber(Vehicles[i].price) or vehiclePrice
            break
        end
    end

    return vehiclePrice
end

local function IsPerformanceMod(modType)
    return modType == 11 or modType == 12 or modType == 13 or modType == 15 or modType == 16
end

local function CalculateMenuPrice(menuKey, menuConfig, current, vehiclePrice)
    if not menuConfig or not menuConfig.modType or not current then return 0 end

    if current.modType == "modFrontWheels" or current.modType == "modBackWheels" then
        return math.floor(vehiclePrice * (tonumber(current.price) or Config.DefaultWheelsPriceMultiplier) / 100)
    end

    if IsPerformanceMod(menuConfig.modType) then
        local pricePercent = menuConfig.price and menuConfig.price[(tonumber(current.modNum) or -1) + 1]
        return math.floor(vehiclePrice * (tonumber(pricePercent) or 0) / 100)
    end

    if menuConfig.modType == 17 then
        return math.floor(vehiclePrice * (tonumber(menuConfig.price and menuConfig.price[1]) or 0) / 100)
    end

    return math.floor(vehiclePrice * (tonumber(menuConfig.price) or 0) / 100)
end

local function FindWheelMenu(current)
    if not current or not current.wheelType then return nil, nil end

    local nativeModType = current.modType == 'modBackWheels' and 24 or 23
    for key, menu in pairs(Config.Menus) do
        if menu.modType == nativeModType and menu.wheelType == current.wheelType then
            return key, menu
        end
    end

    return nil, nil
end

local function IsDefaultOrInstalled(label)
    if type(label) ~= 'string' then return false end

    local cleanLabel = label:gsub('<.->', ''):gsub('^%s*(.-)%s*$', '%1')

    return cleanLabel == TranslateCap('by_default') or cleanLabel == TranslateCap('no_turbo') or cleanLabel:find(TranslateCap('installed'), 1, true) ~= nil
end

local function CleanMenuLabel(label)
    if type(label) ~= 'string' then return '' end

    return label
        :gsub('<.->', '')
        :gsub('&nbsp;', ' ')
        :gsub('^%s*(.-)%s*$', '%1')
end

local function GetCartKey(item)
    if item.modType == "modFrontWheels" or item.modType == "modBackWheels" then
        return ("%s:%s"):format(item.modType, tostring(item.wheelType or ""))
    end

    return tostring(item.modType or item.menuKey)
end

local function RecalculateCartTotal()
    tuningCartTotal = 0

    for _, item in pairs(tuningCart) do
        tuningCartTotal = tuningCartTotal + (tonumber(item.price) or 0)
    end
end

local function ClearCart()
    tuningCart = {}
    tuningCartTotal = 0
end

local function GetCartList()
    local cart = {}

    for _, item in pairs(tuningCart) do
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

local function AddCartItem(item)
    tuningCart[GetCartKey(item)] = item
    RecalculateCartTotal()
end

local function CartHasMod(cart, modType)
    for i = 1, #cart do
        if cart[i].modType == modType then
            return true
        end
    end

    return false
end

local function NormalizeVehiclePropsForPaidCart(vehicleProps, cart)
    if type(vehicleProps) ~= 'table' or type(cart) ~= 'table' or type(myCar) ~= 'table' then return vehicleProps end

    if CartHasMod(cart, 'tyreSmokeColor') then
        vehicleProps.modSmokeEnabled = true
    else
        vehicleProps.modSmokeEnabled = myCar.modSmokeEnabled == true
        vehicleProps.tyreSmokeColor = myCar.tyreSmokeColor
    end

    if CartHasMod(cart, 'neonColor') then
        vehicleProps.neonEnabled = { true, true, true, true }
    else
        vehicleProps.neonEnabled = myCar.neonEnabled
        vehicleProps.neonColor = myCar.neonColor
    end

    if CartHasMod(cart, 'xenonColor') or CartHasMod(cart, 'modXenon') then
        vehicleProps.modXenon = true
    else
        vehicleProps.modXenon = myCar.modXenon == true
    end

    if not CartHasMod(cart, 'xenonColor') then
        vehicleProps.xenonColor = myCar.xenonColor
    end

    return vehicleProps
end

local function ResetWorkshopCamera()
    if not Config.Workshop or not Config.Workshop.EnableCamera then return end
    if not WorkshopCamera then return end
    WorkshopCamera.Stop()
end

local function RestoreVehicleProps(vehicle, props)
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

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function()
    xLib.callback('esx_lscustom:getVehiclesPrices', false, function(vehicles)
        Vehicles = vehicles
    end)
end)

RegisterNetEvent('esx_lscustom:installMod')
AddEventHandler('esx_lscustom:installMod', function()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    local NetId = NetworkGetNetworkIdFromEntity(vehicle)
    myCar = xLib.game.getVehicleProperties(vehicle)
    TriggerServerEvent('esx_lscustom:refreshOwnedVehicle', myCar, NetId)
end)

RegisterNetEvent('esx_lscustom:restoreMods', function(netId, props)
    local xVehicle = NetworkGetEntityFromNetworkId(netId)
    if props ~= nil then
        if DoesEntityExist(xVehicle) then
            xLib.game.setVehicleProperties(xVehicle, props)
        end
    end
end)

RegisterNetEvent('esx_lscustom:cancelInstallMod')
AddEventHandler('esx_lscustom:cancelInstallMod', function()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if (GetPedInVehicleSeat(vehicle, -1) ~= PlayerPedId()) then
        vehicle = GetPlayersLastVehicle(PlayerPedId())
    end
    if not vehicle or vehicle == 0 or not next(myCar) then return end

    RestoreVehicleProps(vehicle, myCar)
end)

RegisterNetEvent('esx_lscustom:cartPurchaseResult')
AddEventHandler('esx_lscustom:cartPurchaseResult', function(result)
    pendingCartPurchase = false

    if not result or not result.success then
        lastPaidVehicleProps = nil
        ESX.ShowNotification(result and result.message or TranslateCap('not_enough_money'))
        if nuiIsOpen then
            SendNUIMessage({
                action = 'purchaseResult',
                success = false,
                message = result and result.message or TranslateCap('not_enough_money')
            })
            SendNuiState()
        elseif lsMenuIsShowed then
            GetAction({ value = 'main' })
        end
        return
    end

    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle and vehicle ~= 0 then
        local vehicleProps = lastPaidVehicleProps or xLib.game.getVehicleProperties(vehicle)
        RestoreVehicleProps(vehicle, vehicleProps)
        TriggerServerEvent('esx_lscustom:refreshOwnedVehicle', vehicleProps, NetworkGetNetworkIdFromEntity(vehicle))
        SetTimeout(500, function()
            TriggerServerEvent('esx_lscustom:stopModing', vehicleProps.plate)
        end)
    end

    lastPaidVehicleProps = nil

    ESX.ShowNotification(result.message or TranslateCap('purchased'))
    CloseWorkshop(true)
end)

AddEventHandler('onClientResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		if lsMenuIsShowed then
            if CloseWorkshop then
                CloseWorkshop(false)
            else
                ResetWorkshopCamera()
                TriggerEvent('esx_lscustom:cancelInstallMod')
            end
		end
	end
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		if lsMenuIsShowed then
            if CloseWorkshop then
                CloseWorkshop(false)
            else
                ResetWorkshopCamera()
                TriggerEvent('esx_lscustom:cancelInstallMod')
            end
		end
	end
end)

function CloseWorkshop(save)
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)

    ESX.UI.Menu.CloseAll()
    nuiIsOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    ResetWorkshopCamera()

    if vehicle and vehicle ~= 0 then
        SetVehicleDoorsShut(vehicle, false)
        FreezeEntityPosition(vehicle, false)
    end

    if not save then
        TriggerEvent('esx_lscustom:cancelInstallMod')
        if myCar.plate then
            TriggerServerEvent('esx_lscustom:stopModing', myCar.plate)
        end
    end

    lsMenuIsShowed = false
    pendingCartPurchase = false
    myCar = {}
    cartPreviewProps = nil
    lastPaidVehicleProps = nil
    currentNuiColor = nil
    ClearCart()
end

local function GetCartPayload()
    local cart = {}

    for _, item in pairs(tuningCart) do
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

local function AddNuiElement(elements, item, menuKey, menuConfig, vehiclePrice, currentMods)
    local label = CleanMenuLabel(item.label)
    local installed = IsDefaultOrInstalled(item.label)
    local price = 0

    if item.modType and menuConfig then
        price = installed and 0 or CalculateMenuPrice(menuKey, menuConfig, item, vehiclePrice)
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

local function BuildNuiMenu(data)
    data = data or { value = 'main' }

    local elements, menuName, menuTitle, parent = {}, '', 'LS CUSTOMS', nil
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    local currentMods = vehicle ~= 0 and xLib.game.getVehicleProperties(vehicle) or {}
    local vehiclePrice = vehicle ~= 0 and GetVehiclePrice(vehicle) or 50000

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
                    AddNuiElement(elements, { label = TranslateCap('by_default'), modType = k, modNum = false }, k, v, vehiclePrice, currentMods)
                elseif v.modType == 'neonColor' or v.modType == 'tyreSmokeColor' then
                    AddNuiElement(elements, { label = TranslateCap('by_default'), modType = k, modNum = { 0, 0, 0 } }, k, v, vehiclePrice, currentMods)
                elseif v.modType == 'color1' or v.modType == 'color2' or v.modType == 'pearlescentColor' or v.modType == 'wheelColor' then
                    AddNuiElement(elements, { label = TranslateCap('by_default'), modType = k, modNum = myCar[v.modType] }, k, v, vehiclePrice, currentMods)
                elseif v.modType == 17 then
                    AddNuiElement(elements, { label = TranslateCap('no_turbo'), modType = k, modNum = false }, k, v, vehiclePrice, currentMods)
                elseif v.modType == 23 then
                    AddNuiElement(elements, { label = TranslateCap('by_default'), modType = 'modFrontWheels', modNum = -1, wheelType = -1, price = Config.DefaultWheelsPriceMultiplier }, k, v, vehiclePrice, currentMods)
                elseif v.modType == 24 then
                    AddNuiElement(elements, { label = TranslateCap('by_default'), modType = 'modBackWheels', modNum = -1, wheelType = -1, price = Config.DefaultWheelsPriceMultiplier }, k, v, vehiclePrice, currentMods)
                else
                    AddNuiElement(elements, { label = TranslateCap('by_default'), modType = k, modNum = -1 }, k, v, vehiclePrice, currentMods)
                end

                if v.modType == 14 then
                    for j = 0, 51 do
                        local label = j == currentMods.modHorns and (GetHornName(j) .. ' - ' .. TranslateCap('installed')) or GetHornName(j)
                        AddNuiElement(elements, { label = label, modType = k, modNum = j }, k, v, vehiclePrice, currentMods)
                    end
                elseif v.modType == 'plateIndex' then
                    local maxJ = gameBuild >= 3095 and 12 or 5
                    for j = 0, maxJ do
                        local label = j == currentMods.plateIndex and (GetPlatesName(j) .. ' - ' .. TranslateCap('installed')) or GetPlatesName(j)
                        AddNuiElement(elements, { label = label, modType = k, modNum = j }, k, v, vehiclePrice, currentMods)
                    end
                elseif v.modType == 22 then
                    local label = currentMods.modXenon and (TranslateCap('neon') .. ' - ' .. TranslateCap('installed')) or TranslateCap('neon')
                    AddNuiElement(elements, { label = label, modType = k, modNum = true }, k, v, vehiclePrice, currentMods)
                elseif v.modType == 'xenonColor' then
                    local xenonColors = GetXenonColors()
                    for i = 1, #xenonColors do
                        AddNuiElement(elements, { label = xenonColors[i].label, modType = k, modNum = xenonColors[i].index }, k, v, vehiclePrice, currentMods)
                    end
                elseif v.modType == 'neonColor' or v.modType == 'tyreSmokeColor' then
                    local neons = GetNeons()
                    for i = 1, #neons do
                        AddNuiElement(elements, { label = neons[i].label, modType = k, modNum = { neons[i].r, neons[i].g, neons[i].b } }, k, v, vehiclePrice, currentMods)
                    end
                elseif v.modType == 'color1' or v.modType == 'color2' or v.modType == 'pearlescentColor' or v.modType == 'wheelColor' then
                    local colors = GetColors(data.color)
                    for j = 1, #colors do
                        AddNuiElement(elements, { label = colors[j].label, modType = k, modNum = colors[j].index }, k, v, vehiclePrice, currentMods)
                    end
                elseif v.modType == 'windowTint' then
                    for j = 1, 5 do
                        local label = j == currentMods.windowTint and (GetWindowName(j) .. ' - ' .. TranslateCap('installed')) or GetWindowName(j)
                        AddNuiElement(elements, { label = label, modType = k, modNum = j }, k, v, vehiclePrice, currentMods)
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
                                AddNuiElement(elements, { label = label, modType = modType, modNum = j, wheelType = v.wheelType, price = v.price }, k, v, vehiclePrice, currentMods)
                            end
                        end
                    end
                elseif IsPerformanceMod(v.modType) then
                    if vehicle and vehicle ~= 0 then
                        SetVehicleModKit(vehicle, 0)
                        local modCount = GetNumVehicleMods(vehicle, v.modType)
                        for j = 0, modCount - 1 do
                            local label = j == currentMods[k] and (TranslateCap('level', j + 1) .. ' - ' .. TranslateCap('installed')) or TranslateCap('level', j + 1)
                            AddNuiElement(elements, { label = label, modType = k, modNum = j }, k, v, vehiclePrice, currentMods)
                        end
                    end
                elseif v.modType == 17 then
                    local label = currentMods[k] and ('Turbo - ' .. TranslateCap('installed')) or 'Turbo'
                    AddNuiElement(elements, { label = label, modType = k, modNum = true }, k, v, vehiclePrice, currentMods)
                else
                    if vehicle and vehicle ~= 0 then
                        local modCount = GetNumVehicleMods(vehicle, v.modType)
                        for j = 0, modCount do
                            local modName = GetModTextLabel(vehicle, v.modType, j)
                            if modName then
                                local name = GetLabelText(modName)
                                local label = j == currentMods[k] and (name .. ' - ' .. TranslateCap('installed')) or name
                                AddNuiElement(elements, { label = label, modType = k, modNum = j }, k, v, vehiclePrice, currentMods)
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
                            label = CleanMenuLabel(w),
                            value = l,
                            action = action,
                            disabled = action == 'checkout' and tuningCartTotal <= 0
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
        title = CleanMenuLabel(menuTitle),
        parent = parent,
        elements = elements
    }
end

local function BuildNuiStats()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    local base = CalcHandlingStats(vehicle)
    local live = CalcModdedStats(vehicle, base)

    return {
        speed = { value = live.speed, delta = live.speed - base.speed },
        accel = { value = live.accel, delta = live.accel - base.accel },
        brake = { value = live.brake, delta = live.brake - base.brake },
        handling = { value = live.handling, delta = live.handling - base.handling }
    }
end

function SendNuiState(menu)
    if not nuiIsOpen then return end

    SendNUIMessage({
        action = 'state',
        menu = menu or BuildNuiMenu({ value = currentNuiMenu, color = currentNuiColor }),
        cart = GetCartPayload(),
        total = tuningCartTotal,
        currency = Config.Currency or '$',
        locale = WorkshopLocale.GetNuiPayload(),
        stats = BuildNuiStats()
    })
end

local function OpenVehicleStatsMenu(parent)
    if not Config.Workshop or not Config.Workshop.EnableStats then return end

    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    local base = CalcHandlingStats(vehicle)
    local live = CalcModdedStats(vehicle, base)
    local labels = {
        { key = 'speed', label = TranslateCap('stats_speed') },
        { key = 'accel', label = TranslateCap('stats_accel') },
        { key = 'brake', label = TranslateCap('stats_brake') },
        { key = 'handling', label = TranslateCap('stats_handling') }
    }
    local elements = {}

    for i = 1, #labels do
        local stat = labels[i]
        local delta = live[stat.key] - base[stat.key]
        local deltaText = delta > 0 and (' <span style="color:green;">+%s</span>'):format(delta) or ''

        elements[#elements + 1] = {
            label = ('%s: %s/100%s'):format(stat.label, live[stat.key], deltaText),
            value = 'noop'
        }
    end

    elements[#elements + 1] = {
        label = ('%s: %s'):format(TranslateCap('cart'), FormatMoney(tuningCartTotal)),
        value = 'noop'
    }

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'vehicleStats', {
        title = TranslateCap('vehicle_stats'),
        align = 'top-left',
        elements = elements
    }, function()
    end, function(_, menu)
        menu.close()
        GetAction({ value = parent or 'main' })
    end)
end

local function OpenCameraMenu(parent)
    if not Config.Workshop or not Config.Workshop.EnableCamera then return end

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'cameraMenu', {
        title = TranslateCap('camera'),
        align = 'top-left',
        elements = {
            { label = TranslateCap('camera_default'), value = 'default' },
            { label = TranslateCap('camera_front'), value = 'front' },
            { label = TranslateCap('camera_back'), value = 'back' },
            { label = TranslateCap('camera_left'), value = 'left' },
            { label = TranslateCap('camera_right'), value = 'right' },
            { label = TranslateCap('camera_top'), value = 'top' },
            { label = TranslateCap('camera_free'), value = 'free' },
            { label = TranslateCap('camera_rotate_left'), value = 'rotateLeft' },
            { label = TranslateCap('camera_rotate_right'), value = 'rotateRight' },
            { label = TranslateCap('camera_zoom_in'), value = 'zoomIn' },
            { label = TranslateCap('camera_zoom_out'), value = 'zoomOut' }
        }
    }, function(data)
        if data.current.value == 'rotateLeft' then
            WorkshopCamera.Rotate(-1)
        elseif data.current.value == 'rotateRight' then
            WorkshopCamera.Rotate(1)
        elseif data.current.value == 'zoomIn' then
            WorkshopCamera.Zoom(-1)
        elseif data.current.value == 'zoomOut' then
            WorkshopCamera.Zoom(1)
        elseif data.current.value == 'free' then
            WorkshopCamera.ToggleFree()
        else
            WorkshopCamera.SetView(data.current.value)
        end
    end, function(_, menu)
        menu.close()
        GetAction({ value = parent or 'main' })
    end)
end

local function CheckoutCart()
    if pendingCartPurchase then return end

    local cart = GetCartList()
    if #cart == 0 or tuningCartTotal <= 0 then
        ESX.ShowNotification(TranslateCap('cart_no_changes'))
        if nuiIsOpen then
            SendNUIMessage({ action = 'toast', message = TranslateCap('cart_no_changes') })
            SendNuiState()
        else
            GetAction({ value = 'main' })
        end
        return
    end

    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if not vehicle or vehicle == 0 then
        if nuiIsOpen then
            SendNUIMessage({ action = 'toast', message = TranslateCap('must_stay_in_vehicle') })
            SendNuiState()
        else
            GetAction({ value = 'main' })
        end
        return
    end

    RestoreVehicleProps(vehicle, cartPreviewProps)
    local vehicleProps = NormalizeVehiclePropsForPaidCart(xLib.game.getVehicleProperties(vehicle), cart)
    RestoreVehicleProps(vehicle, vehicleProps)
    lastPaidVehicleProps = vehicleProps
    pendingCartPurchase = true
    TriggerServerEvent('esx_lscustom:buyCart', {
        cart = cart,
        vehicleProps = vehicleProps
    }, NetworkGetNetworkIdFromEntity(vehicle))
end

local function HandleWorkshopAction(current, parent)
    if not current or not current.value then return false end

    if current.value == 'cartCheckout' then
        CheckoutCart()
        return true
    elseif current.value == 'cartClear' then
        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
        ClearCart()
        cartPreviewProps = myCar
        RestoreVehicleProps(vehicle, myCar)
        ESX.ShowNotification(TranslateCap('cart_cleared'))
        GetAction({ value = parent or 'main' })
        return true
    elseif current.value == 'vehicleStats' then
        OpenVehicleStatsMenu(parent)
        return true
    elseif current.value == 'cameraMenu' then
        OpenCameraMenu(parent)
        return true
    end

    return false
end

function OpenLSMenu(elems, menuName, menuTitle, parent)
    ESX.UI.Menu.Open('default', GetCurrentResourceName(), menuName, {
        title = menuTitle,
        align = 'top-left',
        elements = elems
    }, function(data, menu)
        local isRimMod, found = false, false
        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)

        if data.current.value == 'cartCheckout' or data.current.value == 'cartClear' or data.current.value == 'vehicleStats' or data.current.value == 'cameraMenu' then
            menu.close()
            HandleWorkshopAction(data.current, parent)
            return
        end

        if data.current.modType == "modFrontWheels" then
            isRimMod = true
        end
	if data.current.modType == "modBackWheels" then
	    isRimMod = true
	end

        if isRimMod then
            local wheelMenuKey, wheelMenu = FindWheelMenu(data.current)
            if not wheelMenu then
                ESX.ShowNotification(TranslateCap('wheel_unavailable'))
                return
            end

            if IsDefaultOrInstalled(data.current.label) then
                ESX.ShowNotification(TranslateCap('already_own', data.current.label))
            else
                local price = CalculateMenuPrice(wheelMenuKey, wheelMenu, data.current, GetVehiclePrice(vehicle))
                AddCartItem({
                    label = CleanMenuLabel(data.current.label),
                    menuKey = wheelMenuKey,
                    modType = data.current.modType,
                    modNum = data.current.modNum,
                    wheelType = data.current.wheelType,
                    price = price
                })
                cartPreviewProps = xLib.game.getVehicleProperties(vehicle)
                ESX.ShowNotification(TranslateCap('added_to_cart', FormatMoney(price), FormatMoney(tuningCartTotal)))
            end

            menu.close()
            GetAction({ value = parent or 'main' })
            return
        end

        for k, v in pairs(Config.Menus) do

            if k == data.current.modType then

                if IsDefaultOrInstalled(data.current.label) then
                    ESX.ShowNotification(TranslateCap('already_own', data.current.label))
                else
                    local price = CalculateMenuPrice(k, v, data.current, GetVehiclePrice(vehicle))
                    AddCartItem({
                        label = CleanMenuLabel(data.current.label),
                        menuKey = k,
                        modType = data.current.modType,
                        modNum = data.current.modNum,
                        wheelType = data.current.wheelType,
                        price = price
                    })
                    cartPreviewProps = xLib.game.getVehicleProperties(vehicle)
                    ESX.ShowNotification(TranslateCap('added_to_cart', FormatMoney(price), FormatMoney(tuningCartTotal)))
                end

                menu.close()
                if parent then
                    GetAction({ value = parent })
                else
                    GetAction({ value = 'main' })
                end
                found = true
                break
            end

        end

        if not found then
            GetAction(data.current)
        end
    end, function(data, menu) -- on cancel
        menu.close()

        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        if vehicle and vehicle ~= 0 then
            SetVehicleDoorsShut(vehicle, false)
        end

        if parent == nil then
            CloseWorkshop(false)
        else
            RestoreVehicleProps(vehicle, cartPreviewProps)
            GetAction({ value = parent })
        end
    end, function(data, menu) -- on change
        UpdateMods(data.current)
    end)
end

function UpdateMods(data)
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)

    if data.modType then
        WorkshopCamera.Focus(data.modType)
        local props = {}

        if data.wheelType then
            props['wheels'] = data.wheelType

            if GetVehicleClass(vehicle) == 8 then -- Fix bug wheels for bikes.
                props['modBackWheels'] = data.modNum
            end

            xLib.game.setVehicleProperties(vehicle, props)
            props = {}
        elseif data.modType == 'neonColor' then
            if data.modNum[1] == 0 and data.modNum[2] == 0 and data.modNum[3] == 0 then
                props['neonEnabled'] = {false, false, false, false}
            else
                props['neonEnabled'] = {true, true, true, true}
            end
            xLib.game.setVehicleProperties(vehicle, props)
            props = {}
        elseif data.modType == 'tyreSmokeColor' then
            props['modSmokeEnabled'] = true
            xLib.game.setVehicleProperties(vehicle, props)
            props = {}
        elseif data.modType == 'xenonColor' then
            if data.modNum then
                props['modXenon'] = true
            else
                props['modXenon'] = false
            end
            xLib.game.setVehicleProperties(vehicle, props)
            props = {}
        end

        props[data.modType] = data.modNum
        xLib.game.setVehicleProperties(vehicle, props)
    end
end

local function AddCurrentNuiModToCart(item)
    if not item or not item.modType or IsDefaultOrInstalled(item.label) then
        SendNUIMessage({ action = 'toast', message = TranslateCap('already_own', item and item.label or '') })
        return
    end

    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if not vehicle or vehicle == 0 then return end

    local menuKey = item.menuKey
    local menuConfig = menuKey and Config.Menus[menuKey]
    if not menuConfig and (item.modType == 'modFrontWheels' or item.modType == 'modBackWheels') then
        menuKey, menuConfig = FindWheelMenu(item)
    end

    if not menuConfig then
        SendNUIMessage({ action = 'toast', message = TranslateCap('option_unavailable') })
        return
    end

    UpdateMods(item)
    local price = CalculateMenuPrice(menuKey, menuConfig, item, GetVehiclePrice(vehicle))
    AddCartItem({
        label = CleanMenuLabel(item.label),
        menuKey = menuKey,
        modType = item.modType,
        modNum = item.modNum,
        wheelType = item.wheelType,
        price = price
    })

    cartPreviewProps = xLib.game.getVehicleProperties(vehicle)
    SendNUIMessage({ action = 'toast', message = TranslateCap('added_short', FormatMoney(price)) })
    SendNuiState()
end

local function OpenLSCustomsInterface(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    lsMenuIsShowed = true
    nuiIsOpen = true
    currentNuiMenu = 'main'
    currentNuiColor = nil
    pendingCartPurchase = false

    FreezeEntityPosition(vehicle, true)
    myCar = xLib.game.getVehicleProperties(vehicle)
    cartPreviewProps = myCar
    ClearCart()
    WorkshopCamera.Start(vehicle)

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    TriggerServerEvent('esx_lscustom:startModing', myCar, netId)

    ESX.HideUI()
    HintDisplayed = false
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        title = 'LS CUSTOMS',
        subtitle = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)),
        features = {
            camera = Config.Workshop and Config.Workshop.EnableCamera == true,
            stats = Config.Workshop and Config.Workshop.EnableStats == true
        },
        menu = BuildNuiMenu({ value = 'main' }),
        cart = GetCartPayload(),
        total = tuningCartTotal,
        currency = Config.Currency or '$',
        locale = WorkshopLocale.GetNuiPayload(),
        stats = BuildNuiStats()
    })
end

RegisterNUICallback('close', function(_, cb)
    CloseWorkshop(false)
    cb({ ok = true })
end)

RegisterNUICallback('openMenu', function(data, cb)
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    RestoreVehicleProps(vehicle, cartPreviewProps)

    currentNuiMenu = data and data.value or 'main'
    currentNuiColor = data and data.color or nil
    local menu = BuildNuiMenu({
        value = currentNuiMenu,
        color = currentNuiColor
    })

    SendNuiState(menu)
    cb({ ok = true })
end)

RegisterNUICallback('preview', function(data, cb)
    if not data or not data.modType then
        cb({ ok = false })
        return
    end

    UpdateMods(data)
    SendNUIMessage({ action = 'stats', stats = BuildNuiStats() })
    cb({ ok = true })
end)

RegisterNUICallback('addToCart', function(data, cb)
    AddCurrentNuiModToCart(data)
    cb({ ok = true })
end)

RegisterNUICallback('clearCart', function(_, cb)
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    ClearCart()
    cartPreviewProps = myCar
    RestoreVehicleProps(vehicle, myCar)
    SendNUIMessage({ action = 'toast', message = TranslateCap('cart_cleared') })
    SendNuiState()
    cb({ ok = true })
end)

RegisterNUICallback('checkout', function(_, cb)
    CheckoutCart()
    cb({ ok = true })
end)

RegisterNUICallback('camera', function(data, cb)
    local value = data and data.value

    if value == 'rotateLeft' then
        WorkshopCamera.Rotate(-1)
    elseif value == 'rotateRight' then
        WorkshopCamera.Rotate(1)
    elseif value == 'zoomIn' then
        WorkshopCamera.Zoom(-1)
    elseif value == 'zoomOut' then
        WorkshopCamera.Zoom(1)
    elseif value == 'free' then
        WorkshopCamera.ToggleFree()
    else
        WorkshopCamera.SetView(value or 'default')
    end

    cb({ ok = true })
end)

function GetAction(data)
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

    local vehiclePrice = 50000

    for i = 1, #Vehicles, 1 do
        if GetEntityModel(vehicle) == joaat(Vehicles[i].model) then
            vehiclePrice = Vehicles[i].price
            break
        end
    end

    for k, v in pairs(Config.Menus) do

        if data.value == k then

            menuName = k
            menuTitle = v.label
            parent = v.parent

            if v.modType then

                if v.modType == 22 or v.modType == 'xenonColor' then
                    elements[#elements + 1] = {
                        label = " " .. TranslateCap('by_default'),
                        modType = k,
                        modNum = false
                   }
                elseif v.modType == 'neonColor' or v.modType == 'tyreSmokeColor' then -- disable neon
                    elements[#elements + 1] = {
                        label = " " .. TranslateCap('by_default'),
                        modType = k,
                        modNum = {0, 0, 0}
                   }
                elseif v.modType == 'color1' or v.modType == 'color2' or v.modType == 'pearlescentColor' or v.modType ==
                    'wheelColor' then
                    local num = myCar[v.modType]
                    elements[#elements + 1] = {
                        label = " " .. TranslateCap('by_default'),
                        modType = k,
                        modNum = num
                   }
                elseif v.modType == 17 then
                    elements[#elements + 1] = {
                        label = " " .. TranslateCap('no_turbo'),
                        modType = k,
                        modNum = false
                   }
                elseif v.modType == 23 then
                    elements[#elements + 1] = {
                        label = " " .. TranslateCap('by_default'),
                        modType = "modFrontWheels",
                        modNum = -1,
                        wheelType = -1,
                        price = Config.DefaultWheelsPriceMultiplier
                   }
		elseif v.modType == 24 then
                    elements[#elements + 1] = {
                        label = " " .. TranslateCap('by_default'),
                        modType = "modBackWheels",
                        modNum = -1,
                        wheelType = -1,
                        price = Config.DefaultWheelsPriceMultiplier
                   }
                else
                    elements[#elements + 1] = {
                        label = " " .. TranslateCap('by_default'),
                        modType = k,
                        modNum = -1
                   }
                end

                if v.modType == 14 then -- HORNS
                    for j = 0, 51, 1 do
                        local _label = ''
                        if j == currentMods.modHorns then
                            _label = GetHornName(j) .. ' - <span style="color:cornflowerblue;">' .. TranslateCap('installed') ..
                                         '</span>'
                        else
                            price = math.floor(vehiclePrice * v.price / 100)
                            _label = GetHornName(j) .. ' - <span style="color:green;">$' .. price .. ' </span>'
                        end
                        elements[#elements + 1] = {
                            label = _label,
                            modType = k,
                            modNum = j
                       }
                    end
                elseif v.modType == 'plateIndex' then -- PLATES
                    local maxJ = 5
                    if gameBuild >= 3095 then
                        maxJ = 12
                    end

                    for j = 0, maxJ, 1 do
                        local _label = ''
                        if j == currentMods.plateIndex then
                            _label = GetPlatesName(j) .. ' - <span style="color:cornflowerblue;">' ..
                                         TranslateCap('installed') .. '</span>'
                        else
                            local price = math.floor(vehiclePrice * v.price / 100)
                            _label = GetPlatesName(j) .. ' - <span style="color:green;">$' .. price .. ' </span>'
                        end
                        elements[#elements + 1] = {
                            label = _label,
                            modType = k,
                            modNum = j
                        }
		    end
                elseif v.modType == 22 then -- NEON
                    local _label = ''
                    if currentMods.modXenon then
                        _label = TranslateCap('neon') .. ' - <span style="color:cornflowerblue;">' .. TranslateCap('installed') .. '</span>'
                    else
                        price = math.floor(vehiclePrice * v.price / 100)
                        _label = TranslateCap('neon') .. ' - <span style="color:green;">$' .. price .. ' </span>'
                    end
                    elements[#elements + 1] = {
                        label = _label,
                        modType = k,
                        modNum = true
                   }
                elseif v.modType == 'xenonColor' then -- XENON COLOR
                    local xenonColors = GetXenonColors()
                    price = math.floor(vehiclePrice * v.price / 100)
                    for i = 1, #xenonColors, 1 do
                        elements[#elements + 1] = {
                            label = xenonColors[i].label .. ' - <span style="color:green;">$' .. price .. '</span>',
                            modType = k,
                            modNum = xenonColors[i].index
                       }
                    end
                elseif v.modType == 'neonColor' or v.modType == 'tyreSmokeColor' then -- NEON & SMOKE COLOR
                    local neons = GetNeons()
                    price = math.floor(vehiclePrice * v.price / 100)
                    for i = 1, #neons, 1 do
                        elements[#elements + 1] = {
                            label = '<span style="color:rgb(' .. neons[i].r .. ',' .. neons[i].g .. ',' .. neons[i].b ..
                                ');">' .. neons[i].label .. ' - <span style="color:green;">$' .. price .. '</span>',
                            modType = k,
                            modNum = {neons[i].r, neons[i].g, neons[i].b}
                       }
                    end
                elseif v.modType == 'color1' or v.modType == 'color2' or v.modType == 'pearlescentColor' or v.modType ==
                    'wheelColor' then -- RESPRAYS
                    local colors = GetColors(data.color)
                    for j = 1, #colors, 1 do
                        local _label = ''
                        price = math.floor(vehiclePrice * v.price / 100)
                        _label = colors[j].label .. ' - <span style="color:green;">$' .. price .. ' </span>'
                        elements[#elements + 1] = {
                            label = _label,
                            modType = k,
                            modNum = colors[j].index
                       }
                    end
                elseif v.modType == 'windowTint' then -- WINDOWS TINT
                    for j = 1, 5, 1 do
                        local _label = ''
                        if j == currentMods.windowTint then
                            _label = GetWindowName(j) .. ' - <span style="color:cornflowerblue;">' .. TranslateCap('installed') ..
                                         '</span>'
                        else
                            price = math.floor(vehiclePrice * v.price / 100)
                            _label = GetWindowName(j) .. ' - <span style="color:green;">$' .. price .. ' </span>'
                        end
                        elements[#elements + 1] = {
                            label = _label,
                            modType = k,
                            modNum = j
                       }
                    end
                elseif v.modType == 23 then -- WHEELS RIM & TYPE
                    local props = {}

                    props['wheels'] = v.wheelType
                    xLib.game.setVehicleProperties(vehicle, props)

                    local modCount = GetNumVehicleMods(vehicle, v.modType)
                    for j = 0, modCount, 1 do
                        local modName = GetModTextLabel(vehicle, v.modType, j)
                        if modName then
                            local _label = ''
                            if j == currentMods.modFrontWheels then
                                _label = GetLabelText(modName) .. ' - <span style="color:cornflowerblue;">' ..
                                             TranslateCap('installed') .. '</span>'
                            else
                                price = math.floor(vehiclePrice * v.price / 100)
                                _label = GetLabelText(modName) .. ' - <span style="color:green;">$' .. price ..
                                             ' </span>'
                            end
                            elements[#elements + 1] = {
                                label = _label,
                                modType = 'modFrontWheels',
                                modNum = j,
                                wheelType = v.wheelType,
                                price = v.price
                           }
                        end
                    end
		elseif v.modType == 24 then -- MOTORCYCLES BACK WHEELS
                    local props = {}

                    props['wheels'] = v.wheelType
                    xLib.game.setVehicleProperties(vehicle, props)

                    local modCount = GetNumVehicleMods(vehicle, v.modType)
                    for j = 0, modCount, 1 do
                        local modName = GetModTextLabel(vehicle, v.modType, j)
                        if modName then
                            local _label = ''
                            if j == currentMods.modBackWheels then
                                _label = GetLabelText(modName) .. ' - <span style="color:cornflowerblue;">' ..
                                             TranslateCap('installed') .. '</span>'
                            else
                                price = math.floor(vehiclePrice * v.price / 100)
                                _label = GetLabelText(modName) .. ' - <span style="color:green;">$' .. price ..
                                             ' </span>'
                            end
                            elements[#elements + 1] = {
                                label = _label,
                                modType = 'modBackWheels',
                                modNum = j,
                                wheelType = v.wheelType,
                                price = v.price
                           }
                        end
                    end
                elseif v.modType == 11 or v.modType == 12 or v.modType == 13 or v.modType == 15 or v.modType == 16 then
                    SetVehicleModKit(vehicle, 0)
                    local modCount = GetNumVehicleMods(vehicle, v.modType) -- UPGRADES
                    for j = 0, modCount, 1 do
                        local _label = ''
                        if j == currentMods[k] then
                            _label =
                                TranslateCap('level', j + 1) .. ' - <span style="color:cornflowerblue;">' .. TranslateCap('installed') ..
                                    '</span>'
                        else
                            price = math.floor(vehiclePrice * v.price[j + 1] / 100)
                            _label = TranslateCap('level', j + 1) .. ' - <span style="color:green;">$' .. price .. ' </span>'
                        end
                        elements[#elements + 1] = {
                            label = _label,
                            modType = k,
                            modNum = j
                       }
                        if j == modCount - 1 then
                            break
                        end
                    end
                elseif v.modType == 17 then -- TURBO
                    local _label = ''
                    if currentMods[k] then
                        _label = 'Turbo - <span style="color:cornflowerblue;">' .. TranslateCap('installed') .. '</span>'
                    else
                        _label =
                            'Turbo - <span style="color:green;">$' .. math.floor(vehiclePrice * v.price[1] / 100) ..
                                ' </span>'
                    end
                    elements[#elements + 1] = {
                        label = _label,
                        modType = k,
                        modNum = true
                   }
                else
                    local modCount = GetNumVehicleMods(vehicle, v.modType) -- BODYPARTS
                    for j = 0, modCount, 1 do
                        local modName = GetModTextLabel(vehicle, v.modType, j)
                        if modName then
                            local _label = ''
                            if j == currentMods[k] then
                                _label = GetLabelText(modName) .. ' - <span style="color:cornflowerblue;">' ..
                                             TranslateCap('installed') .. '</span>'
                            else
                                price = math.floor(vehiclePrice * v.price / 100)
                                _label = GetLabelText(modName) .. ' - <span style="color:green;">$' .. price ..
                                             ' </span>'
                            end
                            elements[#elements + 1] = {
                                label = _label,
                                modType = k,
                                modNum = j
                           }
                        end
                    end
                end
            else
                if data.value == 'primaryRespray' or data.value == 'secondaryRespray' or data.value ==
                    'pearlescentRespray' or data.value == 'modFrontWheelsColor' then
                    for i = 1, #Config.Colors, 1 do
                        if data.value == 'primaryRespray' then
                            elements[#elements + 1] = {
                                label = Config.Colors[i].label,
                                value = 'color1',
                                color = Config.Colors[i].value
                           }
                        elseif data.value == 'secondaryRespray' then
                            elements[#elements + 1] = {
                                label = Config.Colors[i].label,
                                value = 'color2',
                                color = Config.Colors[i].value
                           }
                        elseif data.value == 'pearlescentRespray' then
                            elements[#elements + 1] = {
                                label = Config.Colors[i].label,
                                value = 'pearlescentColor',
                                color = Config.Colors[i].value
                           }
                        elseif data.value == 'modFrontWheelsColor' then
                            elements[#elements + 1] = {
                                label = Config.Colors[i].label,
                                value = 'wheelColor',
                                color = Config.Colors[i].value
                           }
                        end
                    end
                else
                    for l, w in pairs(v) do
                        if l ~= 'label' and l ~= 'parent' then
                            local label = w
                            if l == 'cartCheckout' then
                                label = ('%s (%s)'):format(w, FormatMoney(tuningCartTotal))
                            end
                            elements[#elements + 1] = {
                                label = label,
                                value = l
                           }
                        end
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

-- Blips
CreateThread(function()
    for k, v in pairs(Config.Zones) do
        xLib.blips.create({
            coords = v.Pos,
            sprite = 72,
            scale = 0.8,
            shortRange = true,
            label = v.Name
        })
    end
end)

-- Activate menu when player is inside marker
CreateThread(function()
    while true do
        local Sleep = 1500
        local Near = false
        local playerPed = PlayerPedId()

        if IsPedInAnyVehicle(playerPed, false) then
            local coords = GetEntityCoords(playerPed)
            local currentZone, zone, lastZone

            if (ESX.PlayerData.job and ESX.PlayerData.job.name == 'mechanic') or not Config.IsMechanicJobOnly then
                for k, v in pairs(Config.Zones) do
                    if #(coords - v.Pos) < Config.DrawDistance then
                        Near = true
                        Sleep = 0
                        if not lsMenuIsShowed then
                            if not HintDisplayed then
                                HintDisplayed = true
                                ESX.TextUI(v.Hint)
                            end
                            if IsControlJustReleased(0, 38) then
                                local vehicle = GetVehiclePedIsIn(playerPed, false)

                                if Config.Workshop and Config.Workshop.UseNui then
                                    OpenLSCustomsInterface(vehicle)
                                else
                                    lsMenuIsShowed = true
                                    FreezeEntityPosition(vehicle, true)
                                    myCar = xLib.game.getVehicleProperties(vehicle)
                                    cartPreviewProps = myCar
                                    ClearCart()
                                    WorkshopCamera.Start(vehicle)

                                    local netId = NetworkGetNetworkIdFromEntity(vehicle)
                                    TriggerServerEvent('esx_lscustom:startModing', myCar, netId)

                                    ESX.UI.Menu.CloseAll()
                                    GetAction({
                                        value = 'main'
                                    })
                                end

                                -- Prevent Free Tunning Bug
                                CreateThread(function()
                                    while true do
                                        local Sleep = 1000
                                        if lsMenuIsShowed then
                                            Sleep = 0
                                            DisableControlAction(2, 288, true)
                                            DisableControlAction(2, 289, true)
                                            DisableControlAction(2, 170, true)
                                            DisableControlAction(2, 167, true)
                                            DisableControlAction(2, 168, true)
                                            DisableControlAction(2, 23, true)
                                            DisableControlAction(0, 75, true) -- Disable exit vehicle
                                            DisableControlAction(27, 75, true) -- Disable exit vehicle
                                        end
                                        Wait(Sleep)
                                    end
                                end)
                            end
                        end
                    end
                end
                if not Near and HintDisplayed then
                    HintDisplayed = false
                    ESX.HideUI()
                end
            end
        end
        Wait(Sleep)
    end
end)
