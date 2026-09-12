-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local dead, recovering, pending, distressPending = false, false, false, false
local generation, session, syncedAt, holdStarted, retryAt, distressRetryAt = 0, 0, 0, nil, 0, 0
local state = {}
local deathInfo = nil
local uiReady, restorePending, cursor = false, false, false
local requestId, distressId = 0, 0
local syncState, requestRespawn

local function errorMessage(result)
    local key = result and result.error
    if key ~= 'too_early' and key ~= 'insufficient_funds' and key ~= 'cooldown'
        and key ~= 'unavailable' and key ~= 'busy' and key ~= 'not_dead' then
        key = 'server_error'
    end
    return Translate(key)
end

local function send(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function setCursor(enabled)
    cursor = enabled and dead
    SetNuiFocus(cursor, cursor)
    SetNuiFocusKeepInput(cursor)
    send('cursor', cursor)
end

local function remaining()
    local elapsed = math.max(0, (GetGameTimer() - syncedAt) / 1000)
    return math.max(0, (state.earlyRemaining or 0) - elapsed), math.max(0, (state.remaining or 0) - elapsed),
        math.max(0, (state.distressRemaining or 0) - elapsed)
end

local function deathReason()
    if not Config.ShowDeathReason or not deathInfo or not deathInfo.killedByPlayer then return nil end
    if Config.ShowKillerName and deathInfo.killerServerId then
        local player = GetPlayerFromServerId(deathInfo.killerServerId)
        local name = player ~= -1 and GetPlayerName(player) or nil
        if name and name ~= '' then return Translate('killed_by', name) end
    end
    return Translate('killed_by_player')
end

local function refreshUI()
    if not uiReady or not dead then return end
    local early, total, distress = remaining()
    local coords = GetEntityCoords(PlayerPedId())
    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
    send('state', {
        locale = Config.Locale, earlyRemaining = math.ceil(early), remaining = math.ceil(total), total = state.total,
        distressRemaining = math.ceil(distress), distressSent = state.distressSent,
        fine = state.fine, pending = pending, distressPending = distressPending,
        location = GetStreetNameFromHashKey(streetHash), zone = zone,
        deathReason = deathReason(),
        playerId = GetPlayerServerId(PlayerId()), brand = Config.Brand, holdDuration = Config.HoldDuration
    })
end

local function cleanup()
    generation = generation + 1
    dead, pending, distressPending, holdStarted = false, false, false, nil
    deathInfo = nil
    local ped = PlayerPedId()
    DetachEntity(ped, true, false)
    FreezeEntityPosition(ped, false)
    SetPlayerInvincible(PlayerId(), false)
    SetEntityInvincible(ped, false)
    SetPedMotionBlur(ped, false)
    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
    if Config.CameraEnabled then EndDeathCam() end
    setCursor(false)
    send('hide')
end

local function enterDeath()
    if dead or recovering or not ESX.PlayerLoaded then return end
    dead = true
    generation = generation + 1
    local cycle = generation
    local ped = PlayerPedId()
    ESX.SetPlayerData('dead', true)
    ESX.CloseContext()
    if Config.CameraEnabled then StartDeathCam() end
    TriggerEvent('esx_death:entered')
    TriggerMedalDeathClip()
    refreshUI()
    setCursor(true)

    CreateThread(function()
        if not dead or generation ~= cycle then return end
        if Config.DeathAnim.enabled then
            local anim = Config.DeathAnim
            local coords = GetEntityCoords(ped)
            NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
            SetPlayerInvincible(PlayerId(), true)
            SetEntityInvincible(ped, true)
            FreezeEntityPosition(ped, true)
            RequestAnimDict(anim.dict)
            local deadline = GetGameTimer() + 5000
            while not HasAnimDictLoaded(anim.dict) and dead and generation == cycle and GetGameTimer() < deadline do Wait(0) end
        elseif not IsEntityDead(ped) then
            SetEntityHealth(ped, 0)
        end
        while dead and generation == cycle do
            ped = PlayerPedId()
            -- Keep the framework flag aligned after model/spawn changes.
            if not ESX.PlayerData.dead then ESX.SetPlayerData('dead', true) end
            DisableAllControlActions(0)
            EnableControlAction(0, 245, true) -- chat
            EnableControlAction(0, 249, true) -- push to talk
            if Config.CameraEnabled and not cursor then ProcessCamControls() end
            if IsDisabledControlJustReleased(0, 289) then setCursor(not cursor) end -- F2
            if IsDisabledControlJustReleased(0, 47) then TriggerEvent('esx_death:requestDistress') end
            local early = remaining()
            if IsDisabledControlJustReleased(0, 38) and early <= 0 and not pending then
                requestRespawn()
            elseif IsDisabledControlPressed(0, 38) and early <= 0 and not pending then
                holdStarted = holdStarted or GetGameTimer()
                local progress = math.min(1, (GetGameTimer() - holdStarted) / Config.HoldDuration)
                send('hold', progress)
                if progress >= 1 then requestRespawn() end
            elseif holdStarted then
                holdStarted = nil
                send('hold', 0)
            end
            if Config.DeathAnim.enabled then
                local anim = Config.DeathAnim
                if HasAnimDictLoaded(anim.dict) and not IsEntityPlayingAnim(ped, anim.dict, anim.name, 3) and not IsPedInAnyVehicle(ped, false) then
                    TaskPlayAnim(ped, anim.dict, anim.name, anim.fadeIn, anim.fadeOut, -1, anim.flags, anim.playbackRate, false, false, false)
                end
            end
            Wait(0)
        end
        if Config.DeathAnim.enabled then RemoveAnimDict(Config.DeathAnim.dict) end
    end)
end

local function applyState(data)
    if type(data) ~= 'table' or not data.ok then return end
    state, syncedAt = data, GetGameTimer()
    if data.dead then enterDeath() end
    refreshUI()
end

local function recover(data)
    if recovering then return end
    recovering = true
    local thisSession = session
    cleanup()
    DoScreenFadeOut(500)
    local deadline = GetGameTimer() + 2000
    while not IsScreenFadedOut() and GetGameTimer() < deadline do Wait(0) end
    if thisSession ~= session or not ESX.PlayerLoaded then
        recovering = false
        DoScreenFadeIn(500)
        return
    end
    local ped = PlayerPedId()
    local coords = data.point or GetEntityCoords(ped)
    local heading = data.point and data.point.heading or GetEntityHeading(ped)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
    ClearPedTasksImmediately(ped)
    ClearPedBloodDamage(ped)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPlayerInvincible(PlayerId(), false)
    FreezeEntityPosition(ped, false)
    ESX.SetPlayerData('dead', false)
    if data.loadout then ESX.SetPlayerData('loadout', data.loadout) end
    TriggerEvent('esx_basicneeds:resetStatus')
    TriggerServerEvent('esx:onPlayerSpawn')
    TriggerEvent('esx:onPlayerSpawn')
    TriggerEvent('playerSpawned')
    if not Config.OxInventory then TriggerEvent('esx:restoreLoadout') end
    TriggerEvent('esx_death:recovered', data.point ~= nil and 'respawn' or 'revive')
    DoScreenFadeIn(600)
    recovering = false
end

requestRespawn = function()
    if not dead or pending or GetGameTimer() < retryAt then return end
    local early = remaining()
    if early > 0 then return end
    pending, holdStarted = true, nil
    send('hold', 0)
    refreshUI()
    local cycle = generation
    requestId = requestId + 1
    local request = requestId
    SetTimeout(15000, function()
        if dead and cycle == generation and request == requestId and pending then
            requestId = requestId + 1
            pending = false
            retryAt = GetGameTimer() + 5000
            send('feedback', Translate('unavailable'))
            syncState()
        end
    end)
    xLib.callback('esx_death:respawn', false, function(result)
        if not dead or request ~= requestId then return end
        pending = false
        if result and result.ok then return recover(result) end
        retryAt = GetGameTimer() + 5000
        send('feedback', errorMessage(result))
        refreshUI()
        if result and result.error == 'not_dead' then syncState() end
    end)
end

AddEventHandler('esx_death:requestDistress', function()
    local _, _, cooldown = remaining()
    if not dead or distressPending or cooldown > 0 or GetGameTimer() < distressRetryAt then return end
    distressPending = true
    distressRetryAt = GetGameTimer() + 1500
    refreshUI()
    local cycle = generation
    distressId = distressId + 1
    local request = distressId
    SetTimeout(10000, function()
        if dead and cycle == generation and request == distressId and distressPending then
            distressId = distressId + 1
            distressPending = false
            distressRetryAt = GetGameTimer() + 5000
            send('feedback', Translate('unavailable'))
            refreshUI()
        end
    end)
    xLib.callback('esx_death:distress', false, function(result)
        if not dead or request ~= distressId then return end
        distressPending = false
        if result and result.ok then
            applyState(result)
            send('feedback', Translate('distress_sent'))
        else
            if result and result.error == 'cooldown' then syncState() end
            send('feedback', errorMessage(result))
        end
        refreshUI()
    end)
end)

syncState = function()
    if restorePending or not ESX.PlayerLoaded or recovering or pending then return end
    if dead and GetGameTimer() - syncedAt < 2000 then return end
    restorePending = true
    local thisSession = session
    SetTimeout(10000, function() if thisSession == session then restorePending = false end end)
    xLib.callback('esx_death:getState', false, function(data)
        if thisSession ~= session then return end
        restorePending = false
        if not data or not data.ok then return end
        if dead and not data.dead then
            -- A server-authorized recovery may have arrived while NUI/client was restarting.
            recover(data.recovery or { loadout = ESX.PlayerData.loadout })
        else applyState(data) end
    end)
end

RegisterNetEvent('esx_death:sync', function(data)
    if source ~= 65535 then return end
    if ESX.PlayerLoaded and not recovering then applyState(data) end
end)
RegisterNetEvent('esx_death:recover', function(data)
    if source ~= 65535 then return end
    recover(data or {})
end)

AddEventHandler('esx:onPlayerDeath', function(data)
    if dead then return end
    deathInfo = type(data) == 'table' and data or nil
    local total = math.ceil((Config.EarlyRespawnTimer + Config.BleedoutTimer) / 1000)
    state = { dead = true, earlyRemaining = math.ceil(Config.EarlyRespawnTimer / 1000), remaining = total, total = total,
        distressRemaining = 0, fine = Config.EarlyRespawnFine and Config.EarlyRespawnFineAmount or 0 }
    syncedAt = GetGameTimer()
    enterDeath()
end)
AddEventHandler('esx:onPlayerSpawn', function()
    if recovering then return end
    SetTimeout(1000, syncState)
end)
RegisterNetEvent('esx:onPlayerLogout', function()
    session = session + 1
    restorePending = false
    cleanup()
    ClearPedTasksImmediately(PlayerPedId())
end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    local wasDead = dead
    cleanup()
    if wasDead then ClearPedTasksImmediately(PlayerPedId()) end
end)

RegisterNetEvent('esx_ambulancejob:clsearch', function(medicId)
    if source ~= 65535 or not dead then return end
    local player = GetPlayerFromServerId(tonumber(medicId) or -1)
    if player == -1 then return end
    local ped, medic = PlayerPedId(), GetPlayerPed(player)
    if #(GetEntityCoords(ped) - GetEntityCoords(medic)) > 4.0 then return end
    local cycle = generation
    AttachEntityToEntity(ped, medic, 11816, 0.54, 0.54, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    Wait(1000)
    DetachEntity(ped, true, false)
    if dead and cycle == generation then ClearPedTasksImmediately(ped) end
end)

RegisterNUICallback('ready', function(_, cb)
    uiReady = true
    refreshUI()
    if dead then
        setCursor(true)
    end
    cb({ ok = true })
end)
RegisterNUICallback('distress', function(_, cb)
    TriggerEvent('esx_death:requestDistress')
    cb({ ok = dead })
end)
RegisterNUICallback('respawn', function(_, cb)
    requestRespawn()
    cb({ ok = dead })
end)
RegisterNUICallback('releaseFocus', function(_, cb) setCursor(false); cb({ ok = true }) end)
exports('IsDead', function() return dead end)
exports('GetDeathState', function()
    local early, total, distress = remaining()
    return { dead = dead, earlyRemaining = early, remaining = total, distressRemaining = distress }
end)

CreateThread(function()
    local nextSync = 0
    while true do
        if ESX.PlayerLoaded and not recovering then
            if GetGameTimer() >= nextSync then
                nextSync = GetGameTimer() + 5000
                syncState()
            end
            if dead then
                refreshUI()
                local _, total = remaining()
                if total <= 0 then requestRespawn() end
            end
        end
        Wait(250)
    end
end)
