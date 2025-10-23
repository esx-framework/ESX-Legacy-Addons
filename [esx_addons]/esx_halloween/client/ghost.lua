local KEYBIND_MAP = {
    ['X'] = 73,
    ['E'] = 38,
    ['DELETE'] = 178,
    ['BACKSPACE'] = 177
}

---@type GhostState
local ghostState = {
    isGhost = false,
    lastScareTime = 0,
    activatedByDeath = false,
    startTime = 0,
    pendingRequest = false
}

local otherGhostPlayers = {}
local pendingGhostFromDeath = false
local ghostRequestTimeout = nil

--- Checks if the local player is currently in ghost mode
---@return boolean True if player is a ghost, false otherwise
local function IsGhost()
    return ghostState.isGhost
end

--- Requests ghost mode activation from server
--- Waits for server approval before enabling ghost mode
--- Includes timeout handling if server doesn't respond
---@param fromDeath boolean Whether ghost mode was activated from death
---@return nil
local function RequestGhostMode(fromDeath)
    if ghostState.isGhost or ghostState.pendingRequest then return end

    ghostState.pendingRequest = true
    ghostState.activatedByDeath = fromDeath or false

    -- Request ghost mode from server
    TriggerServerEvent(Events.REQUEST_GHOST_MODE, 'ghost')

    -- Set timeout in case server doesn't respond
    ghostRequestTimeout = SetTimeout(Config.Ghost.security.requestTimeout, function()
        if ghostState.pendingRequest then
            ghostState.pendingRequest = false
            ghostState.activatedByDeath = false
            print('^3[ESX Halloween] Ghost mode request timed out^7')
        end
    end)
end

--- Enables ghost mode after server approval
--- Changes model to zombie, applies transparency (30% alpha)
--- Disables combat, increases speed by 1.5x, shows ghost HUD
--- Automatically exits after Config.Ghost.maxDuration or manual X key press
---@param fromDeath boolean Whether ghost mode was activated from death
---@return boolean success True if ghost mode was enabled successfully
local function EnableGhostMode(fromDeath)
    if ghostState.isGhost then return false end

    -- Clear timeout if exists
    if ghostRequestTimeout then
        ClearTimeout(ghostRequestTimeout)
        ghostRequestTimeout = nil
    end

    ghostState.pendingRequest = false
    ghostState.activatedByDeath = fromDeath or false

    if fromDeath then
        TriggerEvent('esx_ambulancejob:revive')
        Wait(500)

        local playerPed = PlayerPedId()
        ClearPedTasks(playerPed)
        FreezeEntityPosition(playerPed, false)
        SetEntityInvincible(playerPed, false)

        Wait(100)
    end

    local model = GetHashKey(Config.Ghost.pedModel)

    RequestModel(model)
    local startTime = GetGameTimer()
    while not HasModelLoaded(model) do
        Wait(100)
        if GetGameTimer() - startTime > 10000 then -- 10 second timeout
            print('^1[ESX Halloween] Failed to load ghost model: ' .. Config.Ghost.pedModel .. '^7')
            -- Rollback state
            ghostState.activatedByDeath = false
            return false
        end
    end

    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)

    local playerPed = PlayerPedId()
    ghostState.isGhost = true
    ghostState.lastScareTime = 0
    ghostState.startTime = GetGameTimer()

    SetEntityAlpha(playerPed, Config.Ghost.visibility.alpha, false)
    SetPedCanRagdoll(playerPed, false)
    SetEntityInvincible(playerPed, true)
    SetPlayerInvincible(PlayerId(), true)

    SetRunSprintMultiplierForPlayer(PlayerId(), Config.Ghost.movement.speedMultiplier)

    SendNUIMessage({
        type = 'showGhostHUD',
        maxDuration = Config.Ghost.maxDuration,
        exitKey = Config.Ghost.exitKeybind,
        scareKey = Config.Ghost.abilities.scare.keybind
    })

    return true
end

--- Disables ghost mode and restores player to normal state
--- Handles screen fade, skin restoration, and optional hospital respawn
--- Re-enables combat controls and resets speed multiplier to 1.0
--- If activated by death, triggers hospital respawn via RespawnAtHospital()
--- Notifies server of ghost mode exit via event
---@return nil
local function DisableGhostMode()
    if not ghostState.isGhost then return end

    local wasActivatedByDeath = ghostState.activatedByDeath

    -- Reset ghost state
    ghostState.isGhost = false
    ghostState.activatedByDeath = false
    ghostState.startTime = 0

    -- Reset player stats
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
    SetPlayerInvincible(PlayerId(), false)

    -- Fade to black for smooth transition
    FadeScreenOut()

    -- Restore player model and skin
    RestorePlayerSkin(function()
        if wasActivatedByDeath then
            -- Respawn at hospital with fade in
            RespawnAtHospital()
        else
            -- Just fade back in at current location
            FadeScreenIn()
        end
    end)

    -- Notify server and hide UI
    TriggerServerEvent(Events.EXIT_GHOST_MODE)
    SendNUIMessage({
        type = 'hideGhostHUD'
    })
end

-- Death handler
AddEventHandler('esx:onPlayerDeath', function()
    if not Config.Ghost.enabled then return end

    if math.random(100) <= Config.Ghost.spawnChance then
        SetTimeout(Config.Ghost.security.deathCooldown, function()
            pendingGhostFromDeath = true
            SetNuiFocus(true, true)
            SendNUIMessage({
                type = 'showGhostChoice'
            })
        end)
    end
end)

-- Show ghost choice (admin command)
RegisterNetEvent(Events.SHOW_GHOST_CHOICE)
AddEventHandler(Events.SHOW_GHOST_CHOICE, function(forced)
    pendingGhostFromDeath = false
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = 'showGhostChoice',
        forced = forced or false
    })
end)

-- Server response to ghost mode request
RegisterNetEvent(Events.GHOST_MODE_RESPONSE)
AddEventHandler(Events.GHOST_MODE_RESPONSE, function(approved, reason)
    if not ghostState.pendingRequest then return end

    if approved then
        local success = EnableGhostMode(ghostState.activatedByDeath)
        if not success then
            print('^1[ESX Halloween] Failed to enable ghost mode^7')
        end
    else
        -- Request denied
        ghostState.pendingRequest = false
        ghostState.activatedByDeath = false

        if ghostRequestTimeout then
            ClearTimeout(ghostRequestTimeout)
            ghostRequestTimeout = nil
        end

        if reason then
            print('^3[ESX Halloween] ' .. reason .. '^7')
        end
    end
end)

-- NUI Callbacks
RegisterNUICallback('ghostChoice', function(data, cb)
    SetNuiFocus(false, false)

    -- Validate data
    if type(data) ~= 'table' or not data.choice then
        print('^1[ESX Halloween] Invalid ghost choice data^7')
        cb('error')
        return
    end

    if data.choice == 'ghost' then
        RequestGhostMode(pendingGhostFromDeath)
    end
    pendingGhostFromDeath = false
    cb('ok')
end)

-- Cache keybinds
local exitKey = KEYBIND_MAP[Config.Ghost.exitKeybind] or 73
local scareKey = KEYBIND_MAP[Config.Ghost.abilities.scare.keybind] or 38

-- Control disable thread - MUST run every frame (Wait(0))
CreateThread(function()
    while true do
        if ghostState.isGhost then
            Wait(0) -- CRITICAL: Must be 0 for DisableControlAction to work

            -- Disable combat controls
            DisableControlAction(0, 24, true) -- Attack
            DisableControlAction(0, 25, true) -- Aim
            DisableControlAction(0, 140, true) -- Melee light attack
            DisableControlAction(0, 141, true) -- Melee heavy attack
            DisableControlAction(0, 142, true) -- Melee alternate attack

            -- Check exit keybind
            if IsControlJustPressed(0, exitKey) then
                DisableGhostMode()
            end

            -- Check scare keybind
            if Config.Ghost.abilities.scare.enabled and IsControlJustPressed(0, scareKey) then
                local currentTime = GetGameTimer()
                if currentTime - ghostState.lastScareTime >= Config.Ghost.abilities.scare.cooldown then

                    local playerPed = PlayerPedId()
                    local playerCoords = GetEntityCoords(playerPed)

                    local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer(playerCoords)

                    if closestPlayer ~= -1 and closestDistance and closestDistance <= Config.Ghost.abilities.scare.range then
                        local targetId = GetPlayerServerId(closestPlayer)
                        TriggerServerEvent(Events.TRIGGER_SCARE, targetId)
                        ghostState.lastScareTime = currentTime
                    end
                end
            end

            ::continue::
        else
            Wait(500)
        end
    end
end)

-- Auto-exit ghost mode after maxDuration
CreateThread(function()
    while true do
        Wait(1000)

        if ghostState.isGhost and ghostState.startTime > 0 then
            local elapsed = GetGameTimer() - ghostState.startTime
            if elapsed >= Config.Ghost.maxDuration then
                DisableGhostMode()
            end
        end
    end
end)

-- Receive scare effect
RegisterNetEvent(Events.RECEIVE_SCARE)
AddEventHandler(Events.RECEIVE_SCARE, function(ghostName)
    SendNUIMessage({
        type = 'triggerJumpscare',
        soundVolume = Config.Ghost.abilities.scare.effects.soundVolume
    })

    if Config.Ghost.abilities.scare.effects.screenShake then
        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.3)
    end

    if Config.Ghost.abilities.scare.effects.sound then
        PlaySoundFrontend(-1, 'CHECKPOINT_MISSED', 'HUD_MINI_GAME_SOUNDSET', true)
    end

    -- Show notification AFTER jumpscare effect (2 second delay)
    SetTimeout(2000, function()
        SendNUIMessage({
            type = 'showNotification',
            size = 'large',
            position = 'bottom-center',
            header = 'You were scared!',
            description = (ghostName or 'A ghost') .. ' has haunted you as a ghost!',
            duration = 4000
        })
    end)
end)

-- Sync ghost states from server
RegisterNetEvent(Events.SYNC_GHOST_STATE)
AddEventHandler(Events.SYNC_GHOST_STATE, function(playerId, isGhost)
    if isGhost then
        otherGhostPlayers[playerId] = true
    else
        otherGhostPlayers[playerId] = nil
    end
end)

-- Ghost visibility thread
CreateThread(function()
    -- Localize config values to avoid constant global table access
    local visibilityRange = Config.Ghost.visibility.range
    local visibilityAlpha = Config.Ghost.visibility.alpha

    while true do
        -- Check if any ghosts exist
        local hasGhosts = next(otherGhostPlayers) ~= nil

        if hasGhosts then
            Wait(500) -- 500ms when ghosts active

            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)

            for playerId in pairs(otherGhostPlayers) do
                local targetPlayer = GetPlayerFromServerId(playerId)

                if targetPlayer ~= -1 then
                    local targetPed = GetPlayerPed(targetPlayer)
                    if targetPed ~= 0 then
                        local targetCoords = GetEntityCoords(targetPed)
                        local distance = #(playerCoords - targetCoords)

                        if distance <= visibilityRange then
                            SetEntityAlpha(targetPed, visibilityAlpha, false)
                        else
                            SetEntityAlpha(targetPed, 0, false)
                        end
                    end
                end
            end
        else
            Wait(2000) -- 2000ms when idle (no ghosts)
        end
    end
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    SetNuiFocus(false, false)

    -- Reset all ghost players alpha
    for playerId in pairs(otherGhostPlayers) do
        local targetPlayer = GetPlayerFromServerId(playerId)
        if targetPlayer ~= -1 then
            local targetPed = GetPlayerPed(targetPlayer)
            if targetPed ~= 0 then
                SetEntityAlpha(targetPed, 255, false)
            end
        end
    end

    if ghostState.isGhost then
        DisableGhostMode()
    end

    -- Clear timeouts
    if ghostRequestTimeout then
        ClearTimeout(ghostRequestTimeout)
    end
end)
