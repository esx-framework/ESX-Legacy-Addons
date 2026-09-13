-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local dead, recovering, pending, distressPending = false, false, false, false
local generation, session, syncedAt, holdStarted, retryAt, distressRetryAt = 0, 0, 0, nil, 0, 0
local state = {}
local deathInfo = nil
local uiReady, restorePending, cursor = false, false, false
local requestId, distressId = 0, 0
local syncState, requestRespawn

local function dbg(message, data)
    if not Config.Debug then return end
    local suffix = ''
    if data ~= nil then
        local ok, encoded = pcall(function() return json.encode(data) end)
        suffix = (' | %s'):format(ok and encoded or tostring(data))
    end
    print(('[esx_death:client] %s%s'):format(message, suffix))
end

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
    dbg('setCursor', { enabled = enabled, cursor = cursor, dead = dead })
end

local function remaining()
    local elapsed = math.max(0, (GetGameTimer() - syncedAt) / 1000)
    return math.max(0, (state.earlyRemaining or 0) - elapsed), math.max(0, (state.remaining or 0) - elapsed),
        math.max(0, (state.distressRemaining or 0) - elapsed)
end

local function deathCauseLabel(cause)
    cause = tonumber(cause)
    if not cause or cause == 0 then return Translate('death_cause_unknown') end
    if cause < 0 then cause = cause + 4294967296 end
    local function hash(name)
        local value = GetHashKey(name)
        return value < 0 and value + 4294967296 or value
    end
    local labels = {
        [hash('WEAPON_UNARMED')] = Translate('death_cause_unarmed'),
        [hash('WEAPON_RUN_OVER_BY_CAR')] = Translate('death_cause_vehicle'),
        [hash('WEAPON_RAMMED_BY_CAR')] = Translate('death_cause_vehicle'),
        [hash('WEAPON_FALL')] = Translate('death_cause_fall'),
        [hash('WEAPON_DROWNING')] = Translate('death_cause_drowning'),
        [hash('WEAPON_DROWNING_IN_VEHICLE')] = Translate('death_cause_drowning'),
        [hash('WEAPON_EXPLOSION')] = Translate('death_cause_explosion'),
        [hash('WEAPON_FIRE')] = Translate('death_cause_fire'),
        [hash('WEAPON_BLEEDING')] = Translate('death_cause_bleeding'),
        [hash('WEAPON_ELECTRIC_FENCE')] = Translate('death_cause_electric'),
        [hash('WEAPON_EXHAUSTION')] = Translate('death_cause_exhaustion'),
        [hash('WEAPON_ANIMAL')] = Translate('death_cause_animal'),
        [hash('WEAPON_COUGAR')] = Translate('death_cause_animal'),
    }
    return labels[cause] or Translate('death_cause_weapon')
end

local function deathReason()
    if not Config.ShowDeathReason then return nil end
    local info = deathInfo or state
    if not info then return nil end
    if info.killedByPlayer then
        if Config.ShowKillerName and info.killerServerId then
            local player = GetPlayerFromServerId(info.killerServerId)
            local name = player ~= -1 and GetPlayerName(player) or nil
            if name and name ~= '' then return Translate('killed_by', name) end
        end
        return Translate('killed_by_player')
    end
    local cause = deathCauseLabel(info.deathCause)
    if not cause then return nil end
    return Translate('death_reason', cause)
end

local function updateDeathInfo(data)
    if type(data) ~= 'table' then return end
    deathInfo = deathInfo or {}
    if data.killedByPlayer ~= nil then deathInfo.killedByPlayer = data.killedByPlayer end
    if data.killerServerId ~= nil then deathInfo.killerServerId = data.killerServerId end
    if data.deathCause ~= nil then deathInfo.deathCause = data.deathCause end
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
    dbg('cleanup:start', { dead = dead, recovering = recovering, pending = pending, generation = generation })
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
    dbg('cleanup:done', { generation = generation })
end

local function enterDeath()
    dbg('enterDeath:attempt', { dead = dead, recovering = recovering, playerLoaded = ESX.PlayerLoaded })
    if dead or recovering or not ESX.PlayerLoaded then
        dbg('enterDeath:blocked', { dead = dead, recovering = recovering, playerLoaded = ESX.PlayerLoaded })
        return
    end
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
    dbg('enterDeath:entered', { generation = generation, ped = ped, deathInfo = deathInfo, state = state })

    CreateThread(function()
        dbg('deathThread:start', { cycle = cycle, generation = generation, dead = dead })
        if not dead or generation ~= cycle then
            dbg('deathThread:aborted-before-anim', { cycle = cycle, generation = generation, dead = dead })
            return
        end
        if Config.DeathAnim.enabled then
            local anim = Config.DeathAnim
            local coords = GetEntityCoords(ped)
            dbg('deathThread:resurrect-for-death-anim', { x = coords.x, y = coords.y, z = coords.z, heading = GetEntityHeading(ped) })
            NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
            SetPlayerInvincible(PlayerId(), true)
            SetEntityInvincible(ped, true)
            FreezeEntityPosition(ped, true)
            RequestAnimDict(anim.dict)
            local deadline = GetGameTimer() + 5000
            while not HasAnimDictLoaded(anim.dict) and dead and generation == cycle and GetGameTimer() < deadline do Wait(0) end
            dbg('deathThread:anim-dict-result', { loaded = HasAnimDictLoaded(anim.dict), dict = anim.dict, dead = dead, generation = generation })
        elseif not IsEntityDead(ped) then
            dbg('deathThread:set-health-zero')
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
                dbg('input:E-released-respawn', { early = early, pending = pending, dead = dead })
                requestRespawn()
            elseif IsDisabledControlPressed(0, 38) and early <= 0 and not pending then
                holdStarted = holdStarted or GetGameTimer()
                local progress = math.min(1, (GetGameTimer() - holdStarted) / Config.HoldDuration)
                send('hold', progress)
                if progress >= 1 then
                    dbg('input:E-hold-complete-respawn', { early = early, progress = progress, pending = pending, dead = dead })
                    requestRespawn()
                end
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
        dbg('deathThread:ended', { cycle = cycle, generation = generation, dead = dead })
    end)
end

local function applyState(data)
    dbg('applyState:received', data)
    if type(data) ~= 'table' or not data.ok then
        dbg('applyState:ignored', data)
        return
    end
    updateDeathInfo(data)
    state, syncedAt = data, GetGameTimer()
    if data.dead then enterDeath() end
    refreshUI()
end

local function recover(data)
    dbg('recover:attempt', { recovering = recovering, dead = dead, data = data })
    if recovering then
        dbg('recover:blocked-already-recovering')
        return
    end
    recovering = true
    local thisSession = session
    cleanup()
    DoScreenFadeOut(500)
    local deadline = GetGameTimer() + 2000
    while not IsScreenFadedOut() and GetGameTimer() < deadline do Wait(0) end
    if thisSession ~= session or not ESX.PlayerLoaded then
        recovering = false
        DoScreenFadeIn(500)
        dbg('recover:aborted-session-or-not-loaded', { thisSession = thisSession, session = session, playerLoaded = ESX.PlayerLoaded })
        return
    end
    local ped = PlayerPedId()
    local coords = data.point or GetEntityCoords(ped)
    local heading = data.point and data.point.heading or GetEntityHeading(ped)
    dbg('recover:resurrecting', { ped = ped, x = coords.x, y = coords.y, z = coords.z, heading = heading, hasPoint = data.point ~= nil })
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
    dbg('recover:done', { dead = dead, recovering = recovering, esxDead = ESX.PlayerData.dead })
end

requestRespawn = function()
    dbg('requestRespawn:attempt', { dead = dead, pending = pending, retryAt = retryAt, now = GetGameTimer(), syncedAt = syncedAt, state = state })
    if not dead or pending or GetGameTimer() < retryAt then
        dbg('requestRespawn:blocked-initial', { dead = dead, pending = pending, retryAt = retryAt, now = GetGameTimer() })
        return
    end
    local early = remaining()
    if early > 0 then
        dbg('requestRespawn:blocked-too-early-client', { early = early })
        return
    end
    pending, holdStarted = true, nil
    send('hold', 0)
    refreshUI()
    local cycle = generation
    requestId = requestId + 1
    local request = requestId
    dbg('requestRespawn:calling-server', { request = request, generation = generation })
    SetTimeout(15000, function()
        if dead and cycle == generation and request == requestId and pending then
            requestId = requestId + 1
            pending = false
            retryAt = GetGameTimer() + 5000
            send('feedback', Translate('unavailable'))
            dbg('requestRespawn:timeout', { request = request, generation = generation, cycle = cycle })
            syncState()
        end
    end)
    xLib.callback('esx_death:respawn', false, function(result)
        dbg('requestRespawn:server-response', { request = request, currentRequest = requestId, dead = dead, result = result })
        if not dead or request ~= requestId then
            dbg('requestRespawn:stale-response-ignored', { request = request, currentRequest = requestId, dead = dead })
            return
        end
        pending = false
        if result and result.ok then
            dbg('requestRespawn:accepted-recovering', result)
            return recover(result)
        end
        retryAt = GetGameTimer() + 5000
        send('feedback', errorMessage(result))
        refreshUI()
        if result and result.error == 'not_dead' then syncState() end
    end)
end

AddEventHandler('esx_death:requestDistress', function()
    local _, _, cooldown = remaining()
    dbg('distress:attempt', { dead = dead, distressPending = distressPending, cooldown = cooldown, retryAt = distressRetryAt, now = GetGameTimer() })
    if not dead or distressPending or cooldown > 0 or GetGameTimer() < distressRetryAt then
        dbg('distress:blocked', { dead = dead, distressPending = distressPending, cooldown = cooldown, retryAt = distressRetryAt, now = GetGameTimer() })
        return
    end
    distressPending = true
    distressRetryAt = GetGameTimer() + 1500
    refreshUI()
    local cycle = generation
    distressId = distressId + 1
    local request = distressId
    dbg('distress:calling-server', { request = request })
    SetTimeout(10000, function()
        if dead and cycle == generation and request == distressId and distressPending then
            distressId = distressId + 1
            distressPending = false
            distressRetryAt = GetGameTimer() + 5000
            send('feedback', Translate('unavailable'))
            dbg('distress:timeout', { request = request })
            refreshUI()
        end
    end)
    xLib.callback('esx_death:distress', false, function(result)
        dbg('distress:server-response', { request = request, currentRequest = distressId, dead = dead, result = result })
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
    if restorePending or not ESX.PlayerLoaded or recovering or pending then
        dbg('syncState:blocked', { restorePending = restorePending, playerLoaded = ESX.PlayerLoaded, recovering = recovering, pending = pending })
        return
    end
    if dead and GetGameTimer() - syncedAt < 2000 then return end
    restorePending = true
    local thisSession = session
    SetTimeout(10000, function() if thisSession == session then restorePending = false end end)
    xLib.callback('esx_death:getState', false, function(data)
        dbg('syncState:server-response', data)
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
    dbg('event:esx_death:sync', { source = source, data = data })
    if source ~= 65535 then return end
    if ESX.PlayerLoaded and not recovering then applyState(data) end
end)
RegisterNetEvent('esx_death:recover', function(data)
    dbg('event:esx_death:recover', { source = source, data = data })
    if source ~= 65535 then return end
    recover(data or {})
end)

AddEventHandler('esx:onPlayerDeath', function(data)
    dbg('event:esx:onPlayerDeath', { dead = dead, data = data })
    if dead then return end
    deathInfo = type(data) == 'table' and data or nil
    local total = math.ceil((Config.EarlyRespawnTimer + Config.BleedoutTimer) / 1000)
    state = { dead = true, earlyRemaining = math.ceil(Config.EarlyRespawnTimer / 1000), remaining = total, total = total,
        distressRemaining = 0, fine = Config.EarlyRespawnFine and Config.EarlyRespawnFineAmount or 0 }
    syncedAt = GetGameTimer()
    enterDeath()
end)
AddEventHandler('esx:onPlayerSpawn', function()
    dbg('event:esx:onPlayerSpawn', { recovering = recovering, dead = dead })
    if recovering then return end
    SetTimeout(1000, syncState)
end)
RegisterNetEvent('esx:onPlayerLogout', function()
    dbg('event:esx:onPlayerLogout')
    session = session + 1
    restorePending = false
    cleanup()
    ClearPedTasksImmediately(PlayerPedId())
end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    dbg('event:onResourceStop', { resource = resource, dead = dead })
    local wasDead = dead
    cleanup()
    if wasDead then ClearPedTasksImmediately(PlayerPedId()) end
end)

RegisterNetEvent('esx_ambulancejob:clsearch', function(medicId)
    dbg('event:esx_ambulancejob:clsearch', { source = source, medicId = medicId, dead = dead })
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
    dbg('nui:ready', { dead = dead, uiReady = uiReady })
    uiReady = true
    refreshUI()
    if dead then
        setCursor(true)
    end
    cb({ ok = true })
end)
RegisterNUICallback('distress', function(_, cb)
    dbg('nui:distress-click', { dead = dead })
    TriggerEvent('esx_death:requestDistress')
    cb({ ok = dead })
end)
RegisterNUICallback('respawn', function(_, cb)
    dbg('nui:respawn-click', { dead = dead, pending = pending })
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
