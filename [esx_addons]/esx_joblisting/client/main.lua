-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local menuIsShowed = false
local isNear = false
local TextUIdrawing = false
local requestId = 0
local applying = false
local availableJobs = {}

local function closeMenu()
    requestId = requestId + 1
    menuIsShowed = false
    SetNuiFocus(false, false)
    SendNUIMessage({action = 'close'})
end

function ShowJobListingMenu()
    if menuIsShowed then
        return
    end

    menuIsShowed = true
    requestId = requestId + 1
    local currentRequest = requestId

    CreateThread(function()
        local ok, result = pcall(xLib.callback.await, 'esx_joblisting:open', false)

        if currentRequest ~= requestId then
            return
        end

        if not ok or not result or not result.ok then
            closeMenu()
            ESX.ShowNotification('Unable to open the Job Center. Please try again.', 'error')
            return
        end

        availableJobs = result.jobs
        ESX.HideUI()
        TextUIdrawing = false
        SetNuiFocus(true, true)
        SendNUIMessage({action = 'open', jobs = result.jobs, profile = result.profile})
    end)
end

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb({ok = true})
end)

local function submit(action, data, cb)
    if not menuIsShowed or applying then
        cb({ok = false})
        return
    end

    applying = true

    CreateThread(function()
        local ok, result = pcall(xLib.callback.await, 'esx_joblisting:' .. action, false, data.job)

        applying = false
        cb(
            ok and result or {
                ok = false,
                message = 'The server did not respond. Please try again.'
            }
        )

        if ok and result and result.ok then
            ESX.ShowNotification(TranslateCap('new_job', result.profile.job.label), 'success')
        end
    end)
end

RegisterNUICallback('apply', function(data, cb)
    submit('apply', data, cb)
end)

RegisterNUICallback('quit', function(data, cb)
    submit('quit', data, cb)
end)

RegisterNUICallback('waypoint', function(data, cb)
    if menuIsShowed then
        for i = 1, #availableJobs do
            local job = availableJobs[i]

            if job.name == data.job and job.location then
                SetNewWaypoint(job.location.x, job.location.y)
                cb({ok = true})
                return
            end
        end
    end

    cb({ok = false})
end)

RegisterNetEvent('esx_joblisting:profileUpdated', function(profile)
    if menuIsShowed then
        SendNUIMessage({action = 'profile', profile = profile})
    end
end)

exports('ShowTasks', function(tasks, grade)
    SendNUIMessage({action = 'tasks', visible = true, tasks = tasks, grade = grade})
end)

exports('HideTasks', function()
    SendNUIMessage({action = 'tasks', visible = false})
end)

exports('ShowTaskProgress', function(task)
    SendNUIMessage({action = 'taskProgress', task = task})
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    if menuIsShowed then
        SetNuiFocus(false, false)
    end

    if TextUIdrawing then
        ESX.HideUI()
    end
end)

RegisterNetEvent('esx:onPlayerLogout', function()
    if menuIsShowed then
        closeMenu()
    end

    SendNUIMessage({action = 'tasks', visible = false})
end)

local function drawTextUI()
    if not TextUIdrawing then
        ESX.TextUI(TranslateCap('access_job_center', xLib.interactions.getInteractKey()))
        TextUIdrawing = true
    end
end

local function hideTextUI()
    if TextUIdrawing then
        ESX.HideUI()
        TextUIdrawing = false
    end
end

-- Activate menu when player is inside marker, and draw markers
for i = 1, #Config.Zones do
    xLib.markerZone.create({
        coords = Config.Zones[i],
        drawDistance = Config.DrawDistance,
        interactDistance = Config.ZoneSize.x / 2,
        exitDistance = Config.DrawDistance,
        marker = {
            type = Config.MarkerType,
            size = Config.ZoneSize,
            color = Config.MarkerColor,
            bobUpAndDown = false,
            faceCamera = true
        },
        onEnter = function()
            isNear = true

            if not menuIsShowed then
                drawTextUI()
            end
        end,
        onInside = function()
            if isNear and not menuIsShowed then
                drawTextUI()
            end
        end,
        onExit = function()
            isNear = false
            hideTextUI()

            if menuIsShowed then
                closeMenu()
            end
        end
    })
end

-- Create blips
if Config.Blip.Enabled then
    CreateThread(function()
        for i = 1, #Config.Zones do
            xLib.blips.create({
                coords = Config.Zones[i],
                sprite = Config.Blip.Sprite,
                display = Config.Blip.Display,
                scale = Config.Blip.Scale,
                color = Config.Blip.Colour,
                shortRange = Config.Blip.ShortRange,
                label = TranslateCap('blip_text')
            })
        end
    end)
end

xLib.interactions.register('open_joblisting', function()
    ShowJobListingMenu()
end, function()
    return isNear and not menuIsShowed
end)