-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local states, locks, ready = {}, {}, false
local earlySeconds = math.ceil(Config.EarlyRespawnTimer / 1000)
local totalSeconds = earlySeconds + math.ceil(Config.BleedoutTimer / 1000)

MySQL.ready(function()
    if Config.AutoMigrate then
        local columns = MySQL.query.await('SHOW COLUMNS FROM users')
        local found = {}
        for _, column in ipairs(columns) do found[column.Field] = true end
        if not found.is_dead then
            MySQL.query.await('ALTER TABLE users ADD COLUMN is_dead TINYINT(1) NOT NULL DEFAULT 0')
        end
        if not found.death_time then
            MySQL.query.await('ALTER TABLE users ADD COLUMN death_time BIGINT NULL DEFAULT NULL')
        end
    end
    -- Fail visibly at startup if the manual migration has not been applied.
    MySQL.query.await('SELECT is_dead, death_time FROM users LIMIT 0')
    ready = true
end)

local function current(src, player)
    return ESX.GetPlayerFromId(src) == player
end

local function publish(src, state, reason)
    Player(src).state:set('isDead', state.dead, true)
    TriggerEvent('esx_death:stateChanged', src, state.dead, reason)
end

local function load(src, player)
    if states[src] and states[src].identifier == player.identifier then return states[src] end
    local row = MySQL.single.await('SELECT is_dead, death_time FROM users WHERE identifier = ?', { player.identifier })
    if not row or not current(src, player) then return nil end
    local dead = row.is_dead == true or tonumber(row.is_dead) == 1
    local timestamp = dead and (tonumber(row.death_time) or tonumber(player.getMeta().deathTime) or os.time()) or nil
    local state = { identifier = player.identifier, dead = dead, time = timestamp, distressAt = 0 }
    states[src] = state
    if dead and not row.death_time then
        MySQL.update.await('UPDATE users SET death_time = ? WHERE identifier = ?', { timestamp, player.identifier })
        if not current(src, player) then return nil end
    end
    publish(src, state, 'restore')
    return state
end

local function withPlayer(src, operation)
    src = tonumber(src)
    local player = src and ESX.GetPlayerFromId(src)
    if not ready or not player then return { ok = false, error = 'unavailable' } end
    if locks[src] then return { ok = false, error = 'busy' } end
    local token = {}
    locks[src] = token
    local ok, result = pcall(function()
        local state = load(src, player)
        if not state then return { ok = false, error = 'unavailable' } end
        return operation(src, player, state)
    end)
    if locks[src] == token then locks[src] = nil end
    if not ok then
        print(('[esx_death] Operation failed for player %s: %s'):format(src, result))
        return { ok = false, error = 'server_error' }
    end
    return result
end

local function snapshot(state)
    local elapsed = state.dead and math.max(0, os.time() - state.time) or 0
    return {
        ok = true, dead = state.dead, elapsed = elapsed,
        earlyRemaining = math.max(0, earlySeconds - elapsed),
        remaining = math.max(0, totalSeconds - elapsed), total = totalSeconds,
        distressRemaining = math.max(0, math.ceil(Config.DistressCooldown / 1000) - (os.time() - state.distressAt)),
        distressSent = state.distressAt > 0,
        fine = Config.EarlyRespawnFine and Config.EarlyRespawnFineAmount or 0,
        killedByPlayer = state.deathKiller and state.deathKiller.killedByPlayer or false,
        killerServerId = state.deathKiller and state.deathKiller.killerServerId or nil,
        recovery = not state.dead and state.recovery or nil
    }
end

local function save(src, player, state, dead, reason)
    local timestamp = dead and os.time() or nil
    if dead then
        MySQL.update.await('UPDATE users SET is_dead = 1, death_time = ? WHERE identifier = ?', { timestamp, player.identifier })
    else
        MySQL.update.await('UPDATE users SET is_dead = 0, death_time = NULL WHERE identifier = ?', { player.identifier })
    end
    if not current(src, player) then return false end
    state.dead, state.time, state.distressAt, state.recovery = dead, timestamp, 0, nil
    if dead then player.setMeta('deathTime', timestamp) else player.clearMeta('deathTime') end
    if not dead then state.deathKiller = nil end
    publish(src, state, reason)
    return true
end

local function recordDeath(src, deathInfo)
    return withPlayer(src, function(id, player, state)
        if not state.dead then
            state.deathKiller = type(deathInfo) == 'table' and { killedByPlayer = deathInfo.killedByPlayer, killerServerId = deathInfo.killerServerId } or nil
            if not save(id, player, state, true, 'death') then
                return { ok = false, error = 'unavailable' }
            end
        end
        local data = snapshot(state)
        TriggerClientEvent('esx_death:sync', id, data)
        return data
    end)
end

RegisterNetEvent('esx:onPlayerDeath', function(data)
    -- ESX owns detection; never accept a target id, timestamps or penalties from a client.
    local src, player = source, ESX.GetPlayerFromId(source)
    local result = recordDeath(src, data)
    if not result.ok and player then
        CreateThread(function()
            for _ = 1, 30 do
                Wait(1000)
                if not current(src, player) or recordDeath(src, data).ok then return end
            end
        end)
    end
end)

ESX.RegisterServerCallback('esx_death:getState', function(src, cb)
    cb(withPlayer(src, function(_, _, state) return snapshot(state) end))
end)

local function revive(src, reason)
    local result = withPlayer(src, function(id, player, state)
        local wasDead = state.dead
        if not save(id, player, state, false, reason or 'revive') then return { ok = false } end
        state.recovery = { loadout = not Config.OxInventory and player.getLoadout() or nil }
        TriggerClientEvent('esx_death:recover', id, state.recovery)
        return { ok = true, wasDead = wasDead }
    end)
    return result.ok, result.wasDead
end

exports('IsDead', function(src) return states[tonumber(src)] ~= nil and states[tonumber(src)].dead end)
exports('GetDeathState', function(src)
    local state = states[tonumber(src)]
    return state and snapshot(state) or nil
end)
exports('GetDeadPlayers', function()
    local result = {}
    for src, state in pairs(states) do
        if state.dead then result[src] = state.distressAt > 0 and 'distress' or 'dead' end
    end
    return result
end)
exports('GetDeadPlayerLocations', function()
    local result = {}
    for src, state in pairs(states) do
        if state.dead then
            local coords = GetEntityCoords(GetPlayerPed(src))
            result[src] = { x = coords.x, y = coords.y, z = coords.z }
        end
    end
    return result
end)
exports('Revive', revive)
exports('SetDead', function(src) return recordDeath(src).ok end)

local function closestHospital(src)
    local coords = GetEntityCoords(GetPlayerPed(src))
    local closest, distance
    for _, point in ipairs(Config.RespawnPoints) do
        local candidate = #(coords - point.coords)
        if not distance or candidate < distance then closest, distance = point, candidate end
    end
    assert(closest, 'Config.RespawnPoints must contain at least one hospital')
    return { x = closest.coords.x, y = closest.coords.y, z = closest.coords.z, heading = closest.heading }
end

local function removePossessions(player)
    if Config.OxInventory then
        if Config.RemoveItemsAfterRPDeath then exports.ox_inventory:ClearInventory(player.source) end
    elseif Config.RemoveItemsAfterRPDeath then
        for key, item in pairs(player.inventory) do
            if item.count > 0 then player.setInventoryItem(item.name or key, 0) end
        end
    end
    if Config.RemoveCashAfterRPDeath then
        if player.getMoney() > 0 then player.removeMoney(player.getMoney(), 'Death') end
        local dirty = player.getAccount('black_money')
        if dirty and dirty.money > 0 then player.setAccountMoney('black_money', 0, 'Death') end
    end
    if not Config.OxInventory and Config.RemoveWeaponsAfterRPDeath then
        -- removeWeapon mutates the loadout array: iterate backwards.
        for i = #player.loadout, 1, -1 do player.removeWeapon(player.loadout[i].name) end
    end
end

ESX.RegisterServerCallback('esx_death:respawn', function(src, cb)
    cb(withPlayer(src, function(id, player, state)
        if not state.dead then return { ok = false, error = 'not_dead' } end
        local elapsed = math.max(0, os.time() - state.time)
        if elapsed < earlySeconds then return { ok = false, error = 'too_early' } end
        local fine = elapsed < totalSeconds and Config.EarlyRespawnFine and Config.EarlyRespawnFineAmount or 0
        local bank = player.getAccount('bank')
        if fine > 0 and (not bank or bank.money < fine) then return { ok = false, error = 'insufficient_funds' } end
        local point = closestHospital(id)
        if fine > 0 then player.removeAccountMoney('bank', fine, 'Respawn Fine') end
        removePossessions(player)
        if not save(id, player, state, false, 'respawn') then return { ok = false, error = 'unavailable' } end
        state.recovery = { ok = true, point = point, loadout = not Config.OxInventory and player.getLoadout() or nil }
        return state.recovery
    end))
end)

local function distress(src)
    return withPlayer(src, function(id, _, state)
        if not state.dead then return { ok = false, error = 'not_dead' } end
        if os.time() - state.distressAt < math.ceil(Config.DistressCooldown / 1000) then
            return { ok = false, error = 'cooldown' }
        end
        state.distressAt = os.time()
        local coords = GetEntityCoords(GetPlayerPed(id))
        TriggerEvent('esx_death:distress', id, { x = coords.x, y = coords.y, z = coords.z })
        return snapshot(state)
    end)
end
ESX.RegisterServerCallback('esx_death:distress', function(src, cb) cb(distress(src)) end)
RegisterNetEvent('esx_ambulancejob:onPlayerDistress', function() distress(source) end)

local function forget(src)
    src = tonumber(src)
    states[src], locks[src] = nil, nil
    -- Persisted death is intentionally retained across disconnect / character changes.
    TriggerEvent('esx_death:stateChanged', src, false, 'logout')
    if GetPlayerName(src) then Player(src).state:set('isDead', false, true) end
end
AddEventHandler('esx:playerDropped', forget)
AddEventHandler('esx:playerLogout', forget)
AddEventHandler('playerDropped', function() forget(source) end)

AddEventHandler('txAdmin:events:healedPlayer', function(data)
    if GetInvokingResource() ~= 'monitor' or type(data) ~= 'table' then return end
    if data.id == -1 then
        for _, player in pairs(ESX.GetExtendedPlayers()) do revive(player.source, 'txadmin') end
    elseif tonumber(data.id) then revive(tonumber(data.id), 'txadmin') end
end)
ESX.RegisterCommand('revive', 'admin', function(_, args) revive(args.playerId.source, 'admin') end, true, {
    help = 'Reanimar a un jugador', validate = true,
    arguments = { { name = 'playerId', help = 'ID del jugador', type = 'player' } }
})
ESX.RegisterCommand('reviveall', 'admin', function()
    for _, player in pairs(ESX.GetExtendedPlayers()) do revive(player.source, 'admin') end
end, true)

-- Hydrate state bags after a resource restart, even before clients request their UI.
CreateThread(function()
    while not ready do Wait(250) end
    for _, player in pairs(ESX.GetExtendedPlayers()) do
        withPlayer(player.source, function(id, _, state)
            TriggerClientEvent('esx_death:sync', id, snapshot(state))
            return { ok = true }
        end)
    end
end)
