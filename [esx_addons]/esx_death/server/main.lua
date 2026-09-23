-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

-- Server state
local states = {}
local locks = {}
local published = {}
local retries = {}
local recoveredAt = {}
local ready = false

local deathLimiter = xLib.rateLimiter({ capacity = 3, refill = 1, interval = 5000, staleMs = 60000 })

local earlySeconds = math.ceil(Config.EarlyRespawnTimer / 1000)
local totalSeconds = earlySeconds + math.ceil(Config.BleedoutTimer / 1000)

-- Debug helpers

local function dbg(message, data)
    if not Config.Debug then
        return
    end

    local suffix = ''

    if data ~= nil then
        local ok, encoded = pcall(function()
            return json.encode(data)
        end)

        suffix = (' | %s'):format(ok and encoded or tostring(data))
    end

    print(('[esx_death:server] %s%s'):format(message, suffix))
end

-- Database bootstrap

MySQL.ready(function()
    dbg('mysql:ready:start', { autoMigrate = Config.AutoMigrate })

    if Config.AutoMigrate then
        local columns = MySQL.query.await('SHOW COLUMNS FROM users')
        local found = {}

        for _, column in ipairs(columns) do
            found[column.Field] = true
        end

        dbg('mysql:columns', { is_dead = found.is_dead, death_time = found.death_time })

        if not found.is_dead then
            dbg('mysql:migrate:add-is_dead')
            MySQL.query.await('ALTER TABLE users ADD COLUMN is_dead TINYINT(1) NOT NULL DEFAULT 0')
        end

        if not found.death_time then
            dbg('mysql:migrate:add-death_time')
            MySQL.query.await('ALTER TABLE users ADD COLUMN death_time BIGINT NULL DEFAULT NULL')
        end
    end

    -- Fail visibly at startup if the manual migration has not been applied.
    MySQL.query.await('SELECT is_dead, death_time FROM users LIMIT 0')
    ready = true
    dbg('mysql:ready:done', { ready = ready, earlySeconds = earlySeconds, totalSeconds = totalSeconds })
end)

-- State helpers

local function current(src, player)
    local active = ESX.GetPlayerFromId(src)

    return active ~= nil and player ~= nil and active.identifier == player.identifier
end

local function publish(src, state, reason)
    dbg('publish', { src = src, dead = state.dead, reason = reason, identifier = state.identifier })

    local bag = Player(src).state

    if (bag.isDead == true) ~= state.dead then
        bag:set('isDead', state.dead, true)
    end

    if (published[src] or false) == state.dead then
        return
    end

    published[src] = state.dead
    TriggerEvent('esx_death:stateChanged', src, state.dead, reason)
end

local function load(src, player)
    dbg('load:attempt', { src = src, identifier = player and player.identifier, cached = states[src] ~= nil })

    if states[src] and states[src].identifier == player.identifier then
        dbg('load:cached', { src = src, dead = states[src].dead, time = states[src].time })
        return states[src]
    end

    local row = MySQL.single.await('SELECT is_dead, death_time FROM users WHERE identifier = ?', { player.identifier })
    dbg('load:db-row', { src = src, row = row, stillCurrent = current(src, player) })

    if not row or not current(src, player) then
        return nil
    end

    local dead = row.is_dead == true or tonumber(row.is_dead) == 1
    local timestamp = dead and (tonumber(row.death_time) or tonumber(player.getMeta().deathTime) or os.time()) or nil
    local state = {
        identifier = player.identifier,
        dead = dead,
        time = timestamp,
        distressAt = 0,
    }

    states[src] = state

    if dead and not row.death_time then
        dbg('load:migrate-player-death-time', { src = src, timestamp = timestamp })
        MySQL.update.await('UPDATE users SET death_time = ? WHERE identifier = ?', { timestamp, player.identifier })

        if not current(src, player) then
            return nil
        end
    end

    publish(src, state, 'restore')

    return state
end

local function withPlayer(src, operation)
    src = tonumber(src)
    local player = src and ESX.GetPlayerFromId(src)

    dbg('withPlayer:attempt', {
        src = src,
        ready = ready,
        hasPlayer = player ~= nil,
        locked = src and locks[src] ~= nil
    })

    if not ready or not player then
        dbg('withPlayer:blocked-unavailable', { src = src, ready = ready, hasPlayer = player ~= nil })
        return { ok = false, error = 'unavailable' }
    end

    if locks[src] then
        dbg('withPlayer:blocked-busy', { src = src })
        return { ok = false, error = 'busy' }
    end

    local token = {}
    locks[src] = token

    local ok, result = pcall(function()
        local state = load(src, player)

        if not state then
            return { ok = false, error = 'unavailable' }
        end

        return operation(src, player, state)
    end)

    if locks[src] == token then
        locks[src] = nil
    end

    if not ok then
        print(('[esx_death] Operation failed for player %s: %s'):format(src, result))
        dbg('withPlayer:pcall-error', { src = src, error = tostring(result) })
        return { ok = false, error = 'server_error' }
    end

    dbg('withPlayer:done', { src = src, result = result })

    return result
end

local function snapshot(state)
    local elapsed = state.dead and math.max(0, os.time() - state.time) or 0

    return {
        ok = true,
        dead = state.dead,
        elapsed = elapsed,
        earlyRemaining = math.max(0, earlySeconds - elapsed),
        remaining = math.max(0, totalSeconds - elapsed),
        total = totalSeconds,
        distressRemaining = math.max(0, math.ceil(Config.DistressCooldown / 1000) - (os.time() - state.distressAt)),
        distressSent = state.distressAt > 0,
        fine = Config.EarlyRespawnFine and Config.EarlyRespawnFineAmount or 0,
        killedByPlayer = state.deathKiller and state.deathKiller.killedByPlayer or false,
        killerServerId = state.deathKiller and state.deathKiller.killerServerId or nil,
        deathCause = state.deathKiller and state.deathKiller.deathCause or nil,
        recovery = not state.dead and state.recovery or nil,
    }
end

local function save(src, player, state, dead, reason)
    local timestamp = dead and os.time() or nil

    dbg('save:attempt', {
        src = src,
        identifier = player.identifier,
        dead = dead,
        reason = reason,
        timestamp = timestamp
    })

    if dead then
        MySQL.update.await(
            'UPDATE users SET is_dead = 1, death_time = ? WHERE identifier = ?',
            { timestamp, player.identifier }
        )
    else
        MySQL.update.await(
            'UPDATE users SET is_dead = 0, death_time = NULL WHERE identifier = ?',
            { player.identifier }
        )
    end

    if not current(src, player) then
        dbg('save:blocked-player-changed', { src = src, identifier = player.identifier })
        return false
    end

    state.dead = dead
    state.time = timestamp
    state.distressAt = 0
    state.recovery = nil

    if dead then
        player.setMeta('deathTime', timestamp)
    else
        player.clearMeta('deathTime')
    end

    if not dead then
        recoveredAt[src] = GetGameTimer()
        state.deathKiller = nil
    end

    publish(src, state, reason)
    dbg('save:done', { src = src, dead = state.dead, reason = reason })

    return true
end

-- Death recording

local function sanitizeDeathCause(value)
    if type(value) == 'number' then
        local hash = math.tointeger(value)

        if hash and hash >= -2147483648 and hash <= 4294967295 then
            return hash
        end

        return nil
    end

    if type(value) == 'string' and #value <= 64 and value:find('^[%w_]+$') then
        return value
    end

    return nil
end

local function sanitizeDeathInfo(src, data)
    if type(data) ~= 'table' then
        return nil
    end

    local killedByPlayer = data.killedByPlayer == true
    local killer = killedByPlayer and type(data.killerServerId) == 'number' and math.tointeger(data.killerServerId) or nil

    if killer and (killer == src or not ESX.GetPlayerFromId(killer)) then
        killer = nil
    end

    return {
        killedByPlayer = killedByPlayer,
        killerServerId = killer,
        deathCause = sanitizeDeathCause(data.deathCause),
    }
end

local function recordDeath(src, deathInfo)
    dbg('recordDeath:attempt', { src = src, deathInfo = deathInfo })

    return withPlayer(src, function(id, player, state)
        if not state.dead then
            state.deathKiller = deathInfo

            if not save(id, player, state, true, 'death') then
                dbg('recordDeath:save-failed', { src = id })
                return { ok = false, error = 'unavailable' }
            end
        else
            dbg('recordDeath:already-dead', { src = id, time = state.time })
        end

        local data = snapshot(state)

        dbg('recordDeath:sync-client', { src = id, data = data })
        TriggerClientEvent('esx_death:sync', id, data)

        return data
    end)
end

-- Events

local function retryDeath(src, player, deathInfo)
    local pending = retries[src]

    if pending then
        pending.deathInfo = deathInfo
        pending.since = GetGameTimer()
        return
    end

    pending = { deathInfo = deathInfo, since = GetGameTimer() }
    retries[src] = pending

    dbg('event:esx:onPlayerDeath:retry-start', { src = src })

    CreateThread(function()
        for _ = 1, 30 do
            Wait(1000)

            if retries[src] ~= pending then
                return
            end

            if not current(src, player) then
                dbg('event:esx:onPlayerDeath:retry-abort-player-changed', { src = src })
                break
            end

            if (recoveredAt[src] or -1) >= pending.since then
                dbg('event:esx:onPlayerDeath:retry-abort-recovered', { src = src })
                break
            end

            local retry = recordDeath(src, pending.deathInfo)
            dbg('event:esx:onPlayerDeath:retry-result', { src = src, retry = retry })

            if retry.ok then
                break
            end
        end

        if retries[src] == pending then
            retries[src] = nil
        end
    end)
end

RegisterNetEvent('esx:onPlayerDeath', function(data)
    -- ESX owns detection; never accept a target id, timestamps or penalties from a client.
    local src = source
    local player = ESX.GetPlayerFromId(src)

    if not player then
        dbg('event:esx:onPlayerDeath:no-player', { src = src })
        return
    end

    local allowed, retryAfter = deathLimiter:consume(src)

    if not allowed then
        dbg('event:esx:onPlayerDeath:rate-limited', { src = src, retryAfter = retryAfter })
        return
    end

    local deathInfo = sanitizeDeathInfo(src, data)
    local pending = retries[src]

    dbg('event:esx:onPlayerDeath', { src = src, deathInfo = deathInfo, retryPending = pending ~= nil })

    if pending then
        pending.deathInfo = deathInfo
        pending.since = GetGameTimer()
        return
    end

    if not recordDeath(src, deathInfo).ok then
        retryDeath(src, player, deathInfo)
    end
end)

-- Callbacks

xLib.callback.register('esx_death:getState', function(src)
    dbg('callback:getState', { src = src })

    return withPlayer(src, function(_, _, state)
        return snapshot(state)
    end)
end)

local function revive(src, reason)
    dbg('revive:attempt', { src = src, reason = reason })

    local result = withPlayer(src, function(id, player, state)
        local wasDead = state.dead

        if not wasDead then
            return { ok = false, wasDead = false }
        end

        dbg('revive:state-before-save', { src = id, wasDead = wasDead, state = state })

        if not save(id, player, state, false, reason or 'revive') then
            dbg('revive:save-failed', { src = id })
            return { ok = false }
        end

        state.recovery = { loadout = not Config.OxInventory and player.getLoadout() or nil }
        dbg('revive:trigger-client-recover', { src = id, wasDead = wasDead, recovery = state.recovery })

        TriggerClientEvent('esx_death:recover', id, state.recovery)

        return { ok = true, wasDead = wasDead }
    end)

    dbg('revive:result', { src = src, reason = reason, result = result })

    return result.ok, result.wasDead
end

-- Exports

exports('IsDead', function(src)
    local state = states[tonumber(src)]
    local dead = state ~= nil and state.dead

    dbg('export:IsDead', { src = src, dead = dead, cached = state ~= nil })

    return dead
end)

exports('GetDeathState', function(src)
    local state = states[tonumber(src)]

    dbg('export:GetDeathState', { src = src, found = state ~= nil })

    return state and snapshot(state) or nil
end)

exports('GetDeadPlayers', function()
    local result = {}

    for src, state in pairs(states) do
        if state.dead then
            result[src] = state.distressAt > 0 and 'distress' or 'dead'
        end
    end

    dbg('export:GetDeadPlayers', result)

    return result
end)

exports('GetDeadPlayerLocations', function()
    local result = {}

    for src, state in pairs(states) do
        if state.dead then
            local coords = GetEntityCoords(GetPlayerPed(src))

            result[src] = {
                x = coords.x,
                y = coords.y,
                z = coords.z,
            }
        end
    end

    dbg('export:GetDeadPlayerLocations', result)

    return result
end)

exports('Revive', revive)

exports('SetDead', function(src)
    dbg('export:SetDead', { src = src })

    return recordDeath(src).ok
end)

-- Respawn handling

local function closestHospital(src)
    local coords = GetEntityCoords(GetPlayerPed(src))
    local closest, distance

    for _, point in ipairs(Config.RespawnPoints) do
        local candidate = #(coords - point.coords)

        if not distance or candidate < distance then
            closest = point
            distance = candidate
        end
    end

    assert(closest, 'Config.RespawnPoints must contain at least one hospital')

    dbg('closestHospital', {
        src = src,
        distance = distance,
        point = {
            x = closest.coords.x,
            y = closest.coords.y,
            z = closest.coords.z,
            heading = closest.heading
        }
    })

    return {
        x = closest.coords.x,
        y = closest.coords.y,
        z = closest.coords.z,
        heading = closest.heading,
    }
end

local function removePossessions(player)
    dbg('removePossessions:start', {
        src = player.source,
        oxInventory = Config.OxInventory,
        removeItems = Config.RemoveItemsAfterRPDeath,
        removeCash = Config.RemoveCashAfterRPDeath,
        removeWeapons = Config.RemoveWeaponsAfterRPDeath,
    })

    if Config.OxInventory then
        if Config.RemoveItemsAfterRPDeath then
            exports.ox_inventory:ClearInventory(player.source)
        end
    elseif Config.RemoveItemsAfterRPDeath then
        for key, item in pairs(player.inventory) do
            if item.count > 0 then
                player.setInventoryItem(item.name or key, 0)
            end
        end
    end

    if Config.RemoveCashAfterRPDeath then
        if player.getMoney() > 0 then
            player.removeMoney(player.getMoney(), 'Death')
        end

        local dirty = player.getAccount('black_money')

        if dirty and dirty.money > 0 then
            player.setAccountMoney('black_money', 0, 'Death')
        end
    end

    if not Config.OxInventory and Config.RemoveWeaponsAfterRPDeath then
        -- removeWeapon mutates the loadout array: iterate backwards.
        for i = #player.loadout, 1, -1 do
            player.removeWeapon(player.loadout[i].name)
        end
    end

    dbg('removePossessions:done', { src = player.source })
end

local function respawn(src)
    dbg('respawn:attempt', { src = src })

    return withPlayer(src, function(id, player, state)
        dbg('respawn:state', { src = id, state = state })

        if not state.dead then
            dbg('respawn:blocked-not-dead', { src = id })
            return { ok = false, error = 'not_dead' }
        end

        local elapsed = math.max(0, os.time() - state.time)

        if elapsed < earlySeconds then
            dbg('respawn:blocked-too-early', { src = id, elapsed = elapsed, earlySeconds = earlySeconds })
            return { ok = false, error = 'too_early' }
        end

        local fine = elapsed < totalSeconds and Config.EarlyRespawnFine and Config.EarlyRespawnFineAmount or 0
        local bank = player.getAccount('bank')

        dbg('respawn:fine-check', { src = id, elapsed = elapsed, fine = fine, bank = bank and bank.money })

        if fine > 0 and (not bank or bank.money < fine) then
            dbg('respawn:blocked-insufficient-funds', { src = id, fine = fine, bank = bank and bank.money })
            return { ok = false, error = 'insufficient_funds' }
        end

        local point = closestHospital(id)

        if not save(id, player, state, false, 'respawn') then
            dbg('respawn:save-failed', { src = id })
            return { ok = false, error = 'unavailable' }
        end

        local penalized, penaltyError = pcall(function()
            if fine > 0 then
                player.removeAccountMoney('bank', fine, 'Respawn Fine')
            end

            removePossessions(player)
        end)

        if not penalized then
            print(('[esx_death] Respawn penalties failed for player %s: %s'):format(id, penaltyError))
        end

        state.recovery = {
            ok = true,
            point = point,
            loadout = not Config.OxInventory and player.getLoadout() or nil,
        }

        dbg('respawn:done', { src = id, recovery = state.recovery })

        return state.recovery
    end)
end

xLib.callback.register('esx_death:respawn', function(src)
    dbg('callback:respawn', { src = src })

    return respawn(src)
end)

-- Distress handling

local function distress(src)
    dbg('distress:attempt', { src = src })

    return withPlayer(src, function(id, _, state)
        if not state.dead then
            dbg('distress:blocked-not-dead', { src = id })
            return { ok = false, error = 'not_dead' }
        end

        if os.time() - state.distressAt < math.ceil(Config.DistressCooldown / 1000) then
            dbg('distress:blocked-cooldown', { src = id, distressAt = state.distressAt })
            return { ok = false, error = 'cooldown' }
        end

        state.distressAt = os.time()
        local coords = GetEntityCoords(GetPlayerPed(id))

        TriggerEvent('esx_death:distress', id, { x = coords.x, y = coords.y, z = coords.z })
        dbg('distress:done', { src = id, coords = { x = coords.x, y = coords.y, z = coords.z } })

        return snapshot(state)
    end)
end

xLib.callback.register('esx_death:distress', function(src)
    dbg('callback:distress', { src = src })

    return distress(src)
end)

RegisterNetEvent('esx_ambulancejob:onPlayerDistress', function()
    dbg('event:esx_ambulancejob:onPlayerDistress', { src = source })
    distress(source)
end)

-- Logout / disconnect cleanup

local function forget(src)
    src = tonumber(src)

    if not src then
        return
    end

    local wasDead = published[src] == true

    dbg('forget', { src = src, hadState = states[src] ~= nil, hadLock = locks[src] ~= nil, wasDead = wasDead })
    states[src] = nil
    locks[src] = nil
    retries[src] = nil
    published[src] = nil
    recoveredAt[src] = nil

    -- Persisted death is intentionally retained across disconnect / character changes.
    if wasDead then
        TriggerEvent('esx_death:stateChanged', src, false, 'logout')
    end

    if GetPlayerName(src) and Player(src).state.isDead then
        Player(src).state:set('isDead', false, true)
    end
end

AddEventHandler('esx:playerDropped', forget)

-- Admin commands

AddEventHandler('txAdmin:events:healedPlayer', function(data)
    dbg('event:txAdmin:healedPlayer', { data = data, invoking = GetInvokingResource() })

    if GetInvokingResource() ~= 'monitor' or type(data) ~= 'table' then
        return
    end

    if data.id == -1 then
        for _, player in pairs(ESX.GetExtendedPlayers()) do
            revive(player.source, 'txadmin')
        end
    elseif tonumber(data.id) then
        revive(tonumber(data.id), 'txadmin')
    end
end)

ESX.RegisterCommand('revive', 'admin', function(xPlayer, args)
    dbg('command:revive', { executor = xPlayer and xPlayer.source, target = args.playerId and args.playerId.source })
    revive(args.playerId.source, 'admin')
end, true, {
    help = Translate('revive_help'),
    validate = true,
    arguments = {
        {
            name = 'playerId',
            help = Translate('player_id'),
            type = 'player',
        },
    },
})

ESX.RegisterCommand('reviveall', 'admin', function()
    dbg('command:reviveall')

    for _, player in pairs(ESX.GetExtendedPlayers()) do
        revive(player.source, 'admin')
    end
end, true)

AddEventHandler('esx:playerLoaded', function(playerId)
    CreateThread(function()
        while not ready do
            Wait(250)
        end

        withPlayer(playerId, function(id, _, state)
            TriggerClientEvent('esx_death:sync', id, snapshot(state))

            return { ok = true }
        end)
    end)
end)

-- Hydrate state bags after a resource restart, even before clients request their UI.

CreateThread(function()
    dbg('hydrate:start-wait-ready')

    while not ready do
        Wait(250)
    end

    dbg('hydrate:ready')

    for _, player in pairs(ESX.GetExtendedPlayers()) do
        withPlayer(player.source, function(id, _, state)
            dbg('hydrate:sync-player', { src = id, state = state })
            TriggerClientEvent('esx_death:sync', id, snapshot(state))

            return { ok = true }
        end)
    end
end)