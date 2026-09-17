-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

AnimationUI = {}

local uiOpen = false
local currentCategory = nil
local activeItem = nil
local playing = false

-- Type-to-icon mapping, mirrors html/js/icons.js
local typeIcons = {
    anim = 'Play',
    scenario = 'PlaySquare',
    attitude = 'PersonStanding'
}

---Gets ESX theme colors from convars
---@return table
function AnimationUI.GetESXThemeColors()
    local defaults = {
        secondaryColor = '#252525',
        backgroundColor = '#161616',
        accentColor = '#383838'
    }
    if type(xLib) == 'table' and type(xLib.colors) == 'table' and type(xLib.colors.getESXTheme) == 'function' then
        return xLib.colors.getESXTheme(defaults)
    end
    return defaults
end

---Builds the list of categories from Config.Animations for the NUI
---@return table[]
function AnimationUI.BuildCategories()
    local categories = {}
    for i = 1, #Config.Animations do
        local cat = Config.Animations[i]
        local items = {}
        for j = 1, #cat.items do
            local item = cat.items[j]
            items[#items + 1] = {
                name = item.label,
                label = item.label,
                type = item.type,
                lib = item.data and item.data.lib,
                anim = item.data and item.data.anim,
                icon = typeIcons[item.type] or 'Play'
            }
        end
        categories[#categories + 1] = {
            name = cat.name,
            label = cat.label,
            items = items
        }
    end
    return categories
end

---Builds the localized UI strings payload for the NUI
---@return table
function AnimationUI.GetNuiLocalePayload()
    return {
        language = Config.Locale or 'en',
        title = TranslateCap('ui_title'),
        categoryPlaceholder = TranslateCap('ui_category_placeholder'),
        search = TranslateCap('ui_search'),
        searchPlaceholder = TranslateCap('ui_search_placeholder'),
        noResults = TranslateCap('ui_no_results'),
        close = TranslateCap('ui_close'),
        stop = TranslateCap('ui_stop'),
  idle = TranslateCap('ui_idle'),
  subtitle = TranslateCap('ui_subtitle'),
        playing = TranslateCap('ui_playing'),
        requestFailed = TranslateCap('ui_request_failed'),
        typeAnim = TranslateCap('ui_type_anim'),
        typeScenario = TranslateCap('ui_type_scenario'),
        typeAttitude = TranslateCap('ui_type_attitude'),
        noAnimations = TranslateCap('ui_no_animations')
    }
end

---Checks if the NUI is open
---@return boolean
function AnimationUI.IsOpen()
    return uiOpen
end

---Opens the animations NUI
function AnimationUI.Open()
    if uiOpen then
        return
    end

    uiOpen = true
    currentCategory = nil
    activeItem = nil
    playing = false

    ESX.HideUI()
    xLib.nui.focus(true, true)

    SendNUIMessage({
        action = 'open',
        categories = AnimationUI.BuildCategories(),
        locale = AnimationUI.GetNuiLocalePayload(),
        theme = AnimationUI.GetESXThemeColors()
    })
end

---Closes the animations NUI
function AnimationUI.Close()
    if not uiOpen then
        return
    end

    uiOpen = false
    currentCategory = nil
    activeItem = nil
    playing = false

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

---Stops the currently playing animation and notifies the NUI (for keybinding use)
function AnimationUI.Stop()
    if not playing then
        return
    end

    playing = false
    activeItem = nil
    ClearPedTasks(ESX.PlayerData.ped)

    if uiOpen then
        SendNUIMessage({
            action = 'state',
            playing = false,
            activeItem = nil
        })
    end
end

-- NUI Ready callback — returns theme colors from convars
xLib.nui.register('ready', function()
    return { theme = AnimationUI.GetESXThemeColors() }
end)

-- NUI Close callback
xLib.nui.register('close', function()
    AnimationUI.Close()
    return xLib.nui.ok()
end)

-- NUI Play callback — triggers the selected animation
xLib.nui.register('play', function(data)
    if type(data) ~= 'table' or not data.type then
        return xLib.nui.fail('Invalid animation data')
    end

    local animType = data.type
    local lib = data.lib
    local anim = data.anim

    if animType == 'scenario' then
        TaskStartScenarioInPlace(ESX.PlayerData.ped, anim, 0, false)
    elseif animType == 'attitude' then
        xLib.streaming.requestAnimSet(lib, function()
            SetPedMovementClipset(ESX.PlayerData.ped, anim, 1.0)
        end)
    elseif animType == 'anim' then
        xLib.streaming.requestAnimDict(lib, function()
            TaskPlayAnim(ESX.PlayerData.ped, lib, anim, 8.0, -8.0, -1, 0, 0.0, false, false, false)
            RemoveAnimDict(lib)
        end)
    else
        return xLib.nui.fail('Unknown animation type: ' .. tostring(animType))
    end

    activeItem = data
    playing = true

    return xLib.nui.ok()
end)

-- NUI Stop callback
xLib.nui.register('stop', function()
    playing = false
    activeItem = nil
    ClearPedTasks(ESX.PlayerData.ped)
    return xLib.nui.ok()
end)

-- NUI Category callback
xLib.nui.register('category', function(data)
    if type(data) ~= 'table' or not data.name then
        return xLib.nui.fail('No category specified')
    end

    currentCategory = data.name

    if playing then
        playing = false
        activeItem = nil
        ClearPedTasks(ESX.PlayerData.ped)
    end

    return xLib.nui.ok()
end)

-- Close on resource stop
AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() and uiOpen then
        AnimationUI.Close()
    end
end)

-- Disable menu controls while open
CreateThread(function()
    while true do
        local sleep = 1000

        if uiOpen then
            sleep = 0
            DisableControlAction(2, 288, true)  -- F3
            DisableControlAction(2, 289, true)  -- F4
            DisableControlAction(2, 170, true)  -- F2 / Menu
            DisableControlAction(2, 167, true)  -- F6
            DisableControlAction(2, 168, true)  -- F7
            DisableControlAction(2, 23, true)   -- Enter / Sprint
            DisableControlAction(0, 75, true)   -- Exit vehicle
            DisableControlAction(27, 75, true)  -- Exit vehicle 2
        end

        Wait(sleep)
    end
end)
