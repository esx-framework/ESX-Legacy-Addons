-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local Vehicles, myCar = {}, {}
local lsMenuIsShowed, HintDisplayed, isInLSMarker = false, false, false
local gameBuild = GetGameBuildNumber()
local pendingCartPurchase = false
local cartPreviewProps, lastPaidVehicleProps
local nuiIsOpen, currentNuiMenu, currentNuiColor = false, 'main', nil
local CloseWorkshop
local SendNuiState
local DefaultNuiMenu = 'cosmetics'

function IsLSCustomNuiOpen()
    return nuiIsOpen
end

local function FormatMoney(amount)
    return ("%s%s"):format(Config.Currency or "$", ESX.Math.GroupDigits(ESX.Math.Round(amount or 0)))
end

local function GetVehiclePrice(vehicle)
    return WorkshopVehicle.GetPrice(vehicle, Vehicles)
end

local function IsPerformanceMod(modType)
    return WorkshopVehicle.IsPerformanceMod(modType)
end

local function IsTurboMod(modType)
    return WorkshopVehicle.IsTurboMod(modType)
end

local function CalculateMenuPrice(menuKey, menuConfig, current, vehiclePrice)
    return WorkshopVehicle.CalculateMenuPrice(menuKey, menuConfig, current, vehiclePrice)
end

local function FindWheelMenu(current)
    return WorkshopVehicle.FindWheelMenu(current)
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

local function GetCartTotal()
    return WorkshopCart.GetTotal()
end

local function ClearCart()
    WorkshopCart.Clear()
end

local function GetCartList()
    return WorkshopCart.GetList()
end

local function AddCartItem(item)
    WorkshopCart.Add(item)
end

local function NormalizeVehiclePropsForPaidCart(vehicleProps, cart)
    return WorkshopVehicle.NormalizePropsForPaidCart(vehicleProps, cart, myCar)
end

local function EnsureWorkshopVehicleModsLoaded(vehicle)
    if not vehicle or vehicle == 0 then return end

    SetVehicleModKit(vehicle, 0)
    while not IsVehicleModLoadDone(vehicle) do
        Wait(0)
    end
end

local function ResetWorkshopCamera()
    if not Config.Workshop or not Config.Workshop.EnableCamera then return end
    if not WorkshopCamera then return end
    WorkshopCamera.Stop()
end

local function RestoreVehicleProps(vehicle, props)
    WorkshopVehicle.RestoreProps(vehicle, props)
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
    return WorkshopCart.GetPayload()
end

local function BuildNuiMenu(data)
    return WorkshopNuiMenu.Build(data, {
        CalculateMenuPrice = CalculateMenuPrice,
        CleanMenuLabel = CleanMenuLabel,
        GetCartTotal = GetCartTotal,
        GetGameBuild = function() return gameBuild end,
        GetMyCar = function() return myCar end,
        GetVehiclePrice = GetVehiclePrice,
        IsDefaultOrInstalled = IsDefaultOrInstalled,
        IsTurboMod = IsTurboMod,
        IsPerformanceMod = IsPerformanceMod
    })
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
        root = BuildNuiMenu({ value = 'main' }).elements,
        cart = GetCartPayload(),
        total = GetCartTotal(),
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
        label = ('%s: %s'):format(TranslateCap('cart'), FormatMoney(GetCartTotal())),
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
    if #cart == 0 or GetCartTotal() <= 0 then
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

    RestoreVehicleProps(vehicle, myCar)
    for i = 1, #cart do
        UpdateMods(cart[i])
    end

    local vehicleProps = NormalizeVehiclePropsForPaidCart(xLib.game.getVehicleProperties(vehicle), cart)
    RestoreVehicleProps(vehicle, vehicleProps)
    cartPreviewProps = vehicleProps
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
    currentNuiMenu = DefaultNuiMenu
    currentNuiColor = nil
    pendingCartPurchase = false

    FreezeEntityPosition(vehicle, true)
    EnsureWorkshopVehicleModsLoaded(vehicle)
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
        menu = BuildNuiMenu({ value = currentNuiMenu }),
        root = BuildNuiMenu({ value = 'main' }).elements,
        cart = GetCartPayload(),
        total = GetCartTotal(),
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

    currentNuiMenu = data and data.value or DefaultNuiMenu
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

LSCustomLegacyDeps = {
    AddCartItem = AddCartItem,
    CalculateMenuPrice = CalculateMenuPrice,
    CleanMenuLabel = CleanMenuLabel,
    CloseWorkshop = CloseWorkshop,
    FindWheelMenu = FindWheelMenu,
    FormatMoney = FormatMoney,
    GetCartPreviewProps = function() return cartPreviewProps end,
    GetCartTotal = function() return GetCartTotal() end,
    GetGameBuild = function() return gameBuild end,
    GetMyCar = function() return myCar end,
    GetVehiclePrice = GetVehiclePrice,
    HandleWorkshopAction = HandleWorkshopAction,
    IsDefaultOrInstalled = IsDefaultOrInstalled,
    IsTurboMod = IsTurboMod,
    RestoreVehicleProps = RestoreVehicleProps,
    SetCartPreviewProps = function(props) cartPreviewProps = props end,
    UpdateMods = UpdateMods
}

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

CreateThread(function()
    while true do
        local sleep = 1000

        if lsMenuIsShowed then
            sleep = 0
            DisableControlAction(2, 288, true)
            DisableControlAction(2, 289, true)
            DisableControlAction(2, 170, true)
            DisableControlAction(2, 167, true)
            DisableControlAction(2, 168, true)
            DisableControlAction(2, 23, true)
            DisableControlAction(0, 75, true)
            DisableControlAction(27, 75, true)
        end

        Wait(sleep)
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
                                    EnsureWorkshopVehicleModsLoaded(vehicle)
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
