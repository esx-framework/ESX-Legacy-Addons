-- SPDX-License-Identifier: GPL-3.0-only

local RESOURCE <const> = GetCurrentResourceName()
local isOpen = false
local isOpening = false
local nativePauseOpen = false

local function debugPrint(message)
    if Config.Debug then
        print(("[%s] %s"):format(RESOURCE, message))
    end
end

local function getTheme()
    local theme = xLib.colors.getESXTheme()

    theme.brandColor = xLib.colors.brand
    theme.darkestColor = xLib.colors.darkest
    theme.darkColor = xLib.colors.dark
    theme.midColor = xLib.colors.mid
    theme.lightColor = xLib.colors.light
    theme.lightestColor = xLib.colors.lightest

    return theme
end

local function getClockData()
    return {
        hour = GetClockHours(),
        minute = GetClockMinutes(),
        day = GetClockDayOfMonth(),
        month = GetClockMonth() + 1,
        year = GetClockYear()
    }
end

local function getLocationData()
    return {
        city = Config.Brand.city
    }
end

local function closeMenu()
    if not isOpen and not isOpening then
        return
    end

    isOpen = false
    isOpening = false
    xLib.nui.close({ type = "close" })
    TriggerScreenblurFadeOut(Config.ScreenBlurMs + 0.0)
end

local function buildConfigForNui()
    return {
        brand = Config.Brand,
        links = Config.Links
    }
end

local function openMenu()
    if isOpen or isOpening or nativePauseOpen or IsPauseMenuActive() or not ESX.PlayerLoaded then
        return
    end

    isOpening = true

    ESX.TriggerServerCallback("esx_pausemenu:getData", function(playerData)
        if not playerData or nativePauseOpen then
            isOpening = false
            return
        end

        SetPauseMenuActive(false)
        TriggerScreenblurFadeIn(Config.ScreenBlurMs + 0.0)

        isOpen = true
        isOpening = false

        xLib.nui.open({
            type = "open",
            data = {
                player = playerData,
                location = getLocationData(),
                clock = getClockData(),
                theme = getTheme(),
                config = buildConfigForNui()
            }
        }, true, true, false)
    end)
end

local function openNativePause(openMap)
    closeMenu()
    nativePauseOpen = true

    CreateThread(function()
        Wait(120)
        ActivateFrontendMenu(GetHashKey("FE_MENU_VERSION_MP_PAUSE"), true, -1)

        local timeout = GetGameTimer() + 3000
        while (not IsPauseMenuActive() or IsPauseMenuRestarting()) and GetGameTimer() < timeout do
            Wait(0)
        end

        if openMap and IsPauseMenuActive() then
            PauseMenuceptionGoDeeper(0)
        end

        while IsPauseMenuActive() do
            Wait(250)
        end

        nativePauseOpen = false
    end)
end

xLib.nui.register("close", function()
    closeMenu()
    return xLib.nui.ok()
end)

xLib.nui.register("resume", function()
    closeMenu()
    return xLib.nui.ok()
end)

xLib.nui.register("openMap", function()
    openNativePause(true)
    return xLib.nui.ok()
end)

xLib.nui.register("openSettings", function()
    openNativePause(false)
    return xLib.nui.ok()
end)

xLib.nui.register("openPeople", function()
    closeMenu()

    if GetResourceState("esx_scoreboard") == "started" and Config.PeopleCommand ~= "" then
        ExecuteCommand(Config.PeopleCommand)
        return xLib.nui.ok()
    end

    return xLib.nui.fail("esx_scoreboard is not running")
end)

xLib.nui.register("leaveServer", function()
    TriggerServerEvent("esx_pausemenu:leaveServer")
    return xLib.nui.ok()
end)

RegisterCommand("esx_pausemenu", function()
    if isOpen then
        closeMenu()
    else
        openMenu()
    end
end, false)

CreateThread(function()
    while true do
        if ESX.PlayerLoaded and not nativePauseOpen then
            Wait(0)

            DisableControlAction(0, Config.Controls.pause, true)
            DisableControlAction(0, Config.Controls.pauseAlt, true)

            if isOpen then
                HideHudAndRadarThisFrame()
                DisableControlAction(0, 1, true)
                DisableControlAction(0, 2, true)
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 142, true)
            elseif not isOpening and (
                IsDisabledControlJustReleased(0, Config.Controls.pause) or
                IsDisabledControlJustReleased(0, Config.Controls.pauseAlt)
            ) then
                openMenu()
            end
        else
            Wait(250)
        end
    end
end)

CreateThread(function()
    while true do
        if isOpen then
            xLib.nui.send({ type = "clock", data = getClockData() })
            Wait(1000)
        else
            Wait(500)
        end
    end
end)

AddEventHandler("esx:onPlayerLogout", function()
    closeMenu()
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= RESOURCE then
        return
    end

    xLib.nui.focus(false, false, false)
    TriggerScreenblurFadeOut(0.0)
end)

debugPrint("loaded")
