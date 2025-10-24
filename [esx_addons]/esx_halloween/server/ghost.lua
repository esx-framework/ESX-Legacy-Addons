local ghostPlayers = {}
local lastGhostRequest = {}
local lastScareTime = {}

---Checks if a player is currently in ghost mode
---@param source number Player server ID
---@return boolean isGhost True if player is a ghost
local function IsPlayerGhost(source)
    return ghostPlayers[source] ~= nil
end

---Validates if a player connection exists
---@param source number Player server ID
---@return boolean isValid True if player is online
local function IsPlayerValid(source)
    return GetPlayerEndpoint(source) ~= nil
end

---Gets the number of currently active ghosts
---@return number count Number of active ghosts
local function GetActiveGhostCount()
    local count = 0
    for _ in pairs(ghostPlayers) do
        count = count + 1
    end
    return count
end

---Sets or clears a player's ghost state and syncs to all clients
---@param source number Player server ID
---@param enabled boolean True to enable ghost mode, false to disable
local function SetGhostState(source, enabled)
    if enabled then
        ghostPlayers[source] = {
            startTime = os.time(),
            active = true
        }
    else
        ghostPlayers[source] = nil
        lastScareTime[source] = nil
    end

    TriggerClientEvent(Events.SYNC_GHOST_STATE, -1, source, enabled)
end

---Validates that the scare target is within allowed range
---Always performs server-side validation for security
---@param source number Ghost player server ID
---@param target number Target player server ID
---@return boolean inRange True if target is within scare range
local function ValidateScareRange(source, target)
    -- Prevent ghost from scaring themselves
    if source == target then
        return false
    end

    local sourcePed = GetPlayerPed(source)
    local targetPed = GetPlayerPed(target)

    if sourcePed == 0 or targetPed == 0 then
        return false
    end

    local sourceCoords = GetEntityCoords(sourcePed)
    local targetCoords = GetEntityCoords(targetPed)

    local distance = #(sourceCoords - targetCoords)

    return distance <= Config.Ghost.abilities.scare.range
end

---Checks if a player can request ghost mode (respects cooldown)
---@param source number Player server ID
---@return boolean canRequest True if cooldown has passed
---@return string|nil reason Reason for denial if canRequest is false
local function CanRequestGhost(source)
    local currentTime = os.time() * 1000
    local lastRequest = lastGhostRequest[source] or 0

    if currentTime - lastRequest < Config.Ghost.security.ghostRequestCooldown then
        local remainingMs = Config.Ghost.security.ghostRequestCooldown - (currentTime - lastRequest)
        local remainingSec = math.ceil(remainingMs / 1000)
        return false, string.format('Please wait %d seconds before requesting ghost mode again', remainingSec)
    end

    return true, nil
end

---Checks if a ghost can use scare ability (respects cooldown)
---@param source number Ghost player server ID
---@return boolean canScare True if cooldown has passed
---@return string|nil reason Reason for denial if canScare is false
local function CanUseScare(source)
    local currentTime = os.time() * 1000
    local lastScare = lastScareTime[source] or 0

    if currentTime - lastScare < Config.Ghost.abilities.scare.cooldown then
        local remainingMs = Config.Ghost.abilities.scare.cooldown - (currentTime - lastScare)
        local remainingSec = math.ceil(remainingMs / 1000)
        return false, string.format('Scare ability on cooldown (%d seconds remaining)', remainingSec)
    end

    return true, nil
end

-- Player disconnected
AddEventHandler('playerDropped', function()
    local source = source

    -- Cleanup ghost state if exists
    if ghostPlayers[source] then
        SetGhostState(source, false)
    end

    -- Always cleanup tracking tables (even if player was never a ghost)
    lastScareTime[source] = nil
    lastGhostRequest[source] = nil
end)

-- Client requests ghost mode
RegisterNetEvent(Events.REQUEST_GHOST_MODE)
AddEventHandler(Events.REQUEST_GHOST_MODE, function(choice)
    local source = source

    if not IsPlayerValid(source) then
        return
    end

    if choice ~= 'ghost' then
        TriggerClientEvent(Events.GHOST_MODE_RESPONSE, source, false, 'Invalid choice')
        return
    end

    -- Check if already a ghost
    if IsPlayerGhost(source) then
        TriggerClientEvent(Events.GHOST_MODE_RESPONSE, source, false, 'You are already a ghost')
        return
    end

    -- Check rate limiting
    local canRequest, reason = CanRequestGhost(source)
    if not canRequest then
        TriggerClientEvent(Events.GHOST_MODE_RESPONSE, source, false, reason)
        return
    end

    -- Check concurrent ghost limit
    if GetActiveGhostCount() >= Config.Ghost.security.maxConcurrentGhosts then
        TriggerClientEvent(Events.GHOST_MODE_RESPONSE, source, false, 'Maximum number of ghosts reached')
        return
    end

    -- Approve request
    lastGhostRequest[source] = os.time() * 1000
    SetGhostState(source, true)
    TriggerClientEvent(Events.GHOST_MODE_RESPONSE, source, true)
end)

-- Client exits ghost mode
RegisterNetEvent(Events.EXIT_GHOST_MODE)
AddEventHandler(Events.EXIT_GHOST_MODE, function()
    local source = source

    if not IsPlayerValid(source) then
        return
    end

    if not IsPlayerGhost(source) then
        return
    end

    SetGhostState(source, false)
end)

-- Scare ability triggered
RegisterNetEvent(Events.TRIGGER_SCARE)
AddEventHandler(Events.TRIGGER_SCARE, function(targetId)
    local source = source

    -- Validate input type
    if type(targetId) ~= 'number' then
        print(string.format('^3[ESX Halloween] Player %d sent invalid targetId: %s^7', source, tostring(targetId)))
        return
    end

    -- Validate ghost status
    if not IsPlayerGhost(source) then
        print(string.format('^3[ESX Halloween] Player %d tried to scare without being a ghost^7', source))
        return
    end

    -- Validate target exists
    if not IsPlayerValid(targetId) then
        return
    end

    -- Validate scare cooldown
    local canScare, reason = CanUseScare(source)
    if not canScare then
        -- Silent fail - client should handle cooldown UI
        return
    end

    -- Validate range
    if not ValidateScareRange(source, targetId) then
        -- Silent fail - client should handle range checking
        return
    end

    -- Update cooldown
    lastScareTime[source] = os.time() * 1000

    -- Get ghost player name
    local ghostName = GetPlayerName(source) or 'A ghost'

    -- Trigger scare effect
    TriggerClientEvent(Events.RECEIVE_SCARE, targetId, ghostName)
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    -- Notify all clients to disable all ghosts
    for playerId in pairs(ghostPlayers) do
        TriggerClientEvent(Events.SYNC_GHOST_STATE, -1, playerId, false)
    end

    ghostPlayers = {}
    lastScareTime = {}
    lastGhostRequest = {}
end)

-- Export for other resources with parameter validation
exports('IsPlayerGhost', function(source)
    if type(source) ~= 'number' or source < 0 then
        print('^3[ESX Halloween] Warning: IsPlayerGhost called with invalid source^7')
        return false
    end

    if not IsPlayerValid(source) then
        return false
    end

    return IsPlayerGhost(source)
end)

exports('SetPlayerGhost', function(source, enabled)
    if type(source) ~= 'number' or source < 0 then
        print('^1[ESX Halloween] Error: SetPlayerGhost called with invalid source^7')
        return
    end

    if type(enabled) ~= 'boolean' then
        print('^1[ESX Halloween] Error: SetPlayerGhost called with invalid enabled value^7')
        return
    end

    if not IsPlayerValid(source) then
        print('^3[ESX Halloween] Warning: SetPlayerGhost called for offline player^7')
        return
    end

    SetGhostState(source, enabled)
end)
