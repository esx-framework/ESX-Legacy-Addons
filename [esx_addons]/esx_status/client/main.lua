
-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local OriginalStatus, Status, isPaused = {}, {}, false
local statusLoaded = false
local statusLoopRunning = false

function GetStatusData(minimal)
    local status = {}

    for i = 1, #Status do
        local entry = {
            name = Status[i].name,
            val = Status[i].val,
            percent = (Status[i].val / Config.StatusMax) * 100
        }

        if not minimal then
            entry.color = Status[i].color
            entry.visible = Status[i].visible(Status[i])
        end

        status[#status + 1] = entry
    end

    return status
end

AddEventHandler('esx_status:registerStatus', function(name, default, color, visible, tickCallback)
    for i = 1, #Status do
        if Status[i].name == name then
            return
        end
    end

    local status = CreateStatus(name, default, color, visible, tickCallback)

    for i = 1, #OriginalStatus do
        if OriginalStatus[i].name == name then
            status.set(OriginalStatus[i].val)
            break
        end
    end

    Status[#Status + 1] = status
end)

AddEventHandler('esx_status:unregisterStatus', function(name)
    for i, status in ipairs(Status) do
        if status.name == name then
            table.remove(Status, i)
            break
        end
    end
end)

RegisterNetEvent('esx:onPlayerLogout', function()
    Status = {}
    OriginalStatus = {}
    statusLoaded = false
    statusLoopRunning = false

    if Config.Display then
        SendNUIMessage({
            update = true,
            status = {}
        })
    end
end)

local function applyOriginalStatus()
    for i = 1, #Status do
        for j = 1, #OriginalStatus do
            if Status[i].name == OriginalStatus[j].name then
                Status[i].set(OriginalStatus[j].val)
                break
            end
        end
    end
end

local function startStatusLoop()
    if statusLoopRunning then
        return
    end

    statusLoopRunning = true

    if Config.Display then
        TriggerEvent('esx_status:setDisplay', 0.5)
    end

    CreateThread(function()
        local data = {}

        while ESX.PlayerLoaded do
            for i = 1, #Status do
                Status[i].onTick()

                data[#data + 1] = {
                    name = Status[i].name,
                    val = Status[i].val,
                    percent = (Status[i].val / Config.StatusMax) * 100
                }
            end

            if Config.Display then
                for i = 1, #data do
                    local status = Status[i]

                    if status then
                        data[i].color = status.color
                        data[i].visible = status.visible(status)
                    end
                end

                SendNUIMessage({
                    update = true,
                    status = data
                })
            end

            TriggerEvent('esx_status:onTick', data)
            table.wipe(data)

            Wait(Config.TickTime)
        end

        statusLoopRunning = false
        statusLoaded = false
    end)
end

local function loadPlayerStatus(status)
    while not ESX.PlayerLoaded do
        Wait(100)
    end

    -- Keep server values if they have arrived.
    if type(status) == 'table' and next(status) ~= nil then
        OriginalStatus = status
    elseif not OriginalStatus then
        OriginalStatus = {}
    end

    if not statusLoaded then
        statusLoaded = true

        -- Registers hunger, thirst, drunk and other statuses.
        TriggerEvent('esx_status:loaded')

        -- Apply saved values after registration.
        applyOriginalStatus()
    else
        -- A late server response updates already registered statuses.
        applyOriginalStatus()
    end

    startStatusLoop()
end

RegisterNetEvent('esx_status:load', function(status)
    loadPlayerStatus(status)
end)

-- Fallback initialization if the server event is delayed or missing.
CreateThread(function()
    while not ESX.PlayerLoaded do
        Wait(500)
    end

    Wait(5000)

    if not statusLoaded then
        print('[esx_status] Fallback initialization started.')
        loadPlayerStatus({})
    end
end)

RegisterNetEvent('esx_status:set', function(name, val)
    for i = 1, #Status do
        if Status[i].name == name then
            Status[i].set(val)
            break
        end
    end

    if Config.Display then
        SendNUIMessage({
            update = true,
            status = GetStatusData()
        })
    end
end)

RegisterNetEvent('esx_status:add', function(name, val)
    for i = 1, #Status do
        if Status[i].name == name then
            Status[i].add(val)
            break
        end
    end

    if Config.Display then
        SendNUIMessage({
            update = true,
            status = GetStatusData()
        })
    end
end)

RegisterNetEvent('esx_status:remove', function(name, val)
    for i = 1, #Status do
        if Status[i].name == name then
            Status[i].remove(val)
            break
        end
    end

    if Config.Display then
        SendNUIMessage({
            update = true,
            status = GetStatusData()
        })
    end
end)

AddEventHandler('esx_status:getStatus', function(name, cb)
    for i = 1, #Status do
        if Status[i].name == name then
            cb(Status[i])
            return
        end
    end
end)

AddEventHandler('esx_status:getAllStatus', function(cb)
    cb(Status)
end)

AddEventHandler('esx_status:setDisplay', function(val)
    SendNUIMessage({
        setDisplay = true,
        display = val
    })
end)

-- Pause menu HUD handling.
if Config.Display then
    AddEventHandler('esx:pauseMenuActive', function(state)
        if state then
            isPaused = true
            TriggerEvent('esx_status:setDisplay', 0.0)
            return
        end

        isPaused = false
        TriggerEvent('esx_status:setDisplay', 0.5)
    end)

    AddEventHandler('esx:loadingScreenOff', function()
        if not isPaused then
            TriggerEvent('esx_status:setDisplay', 0.3)
        end
    end)
end

-- Send status values to the server.
CreateThread(function()
    while true do
        Wait(Config.UpdateInterval)

        if ESX.PlayerLoaded and statusLoaded then
            TriggerServerEvent('esx_status:update', GetStatusData(true))
        end
    end
end)
