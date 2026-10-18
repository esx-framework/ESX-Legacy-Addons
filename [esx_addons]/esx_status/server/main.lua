-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

ESXCatalog.awaitReady()

local MAX_STATUSES = 64
local MAX_STATUS_NAME_LENGTH = 64
local statusClocks = setmetatable({}, { __mode = 'k' })
local loadRequests = setmetatable({}, { __mode = 'k' })
local loadingStatuses = setmetatable({}, { __mode = 'k' })
local loadRetryDelays = setmetatable({}, { __mode = 'k' })
local updateRequests = {}
local statusPlayers = {}

local function isCurrentPlayer(src, xPlayer)
    if xPlayer.isCurrent then
        return xPlayer.isCurrent() == true
    end
    return ESX.GetPlayerFromId(src) == xPlayer
end

local function getStatusPlayer(src)
    local xPlayer = statusPlayers[src]
    if xPlayer and isCurrentPlayer(src, xPlayer) then return xPlayer end

    xPlayer = ESX.GetPlayerFromId(src)
    statusPlayers[src] = xPlayer
    return xPlayer
end

local function normalizeStatus(status, statusName)
    if type(status) ~= 'table' then
        return nil
    end

    local normalized
    local selected
    local names = {}
    local count = 0
    local highestIndex = 0

    if statusName == nil then
        normalized = {}
    end

    for index, entry in pairs(status) do
        count = count + 1

        if count > MAX_STATUSES or type(index) ~= 'number' or index % 1 ~= 0 or index < 1 or index > MAX_STATUSES or type(entry) ~= 'table' then
            return nil
        end

        local name = entry.name
        local value = entry.val

        if
            type(name) ~= 'string'
            or name == ''
            or #name > MAX_STATUS_NAME_LENGTH
            or names[name]
            or type(value) ~= 'number'
            or value ~= value
            or value == math.huge
            or value == -math.huge
        then
            return nil
        end

        names[name] = true

        if index > highestIndex then
            highestIndex = index
        end

        if normalized or name == statusName then
            value = math.max(0, math.min(Config.StatusMax, value))

            local validated = {
                name = name,
                val = value,
                percent = value / Config.StatusMax * 100,
            }

            if normalized then
                normalized[index] = validated
            else
                selected = validated
            end
        end
    end

    if highestIndex ~= count then
        return nil
    end

    return normalized or selected
end

local function advanceStatuses(xPlayer, persist)
    local now = GetGameTimer()
    local previous = statusClocks[xPlayer] or now
    local elapsed = math.max(0, now - previous)

    statusClocks[xPlayer] = now

    local status = normalizeStatus(xPlayer.get('status')) or {}

    for name, settings in pairs(Config.AuthoritativeStatuses or {}) do
        local entry

        for _, value in ipairs(status) do
            if value.name == name then
                entry = value
                break
            end
        end

        if not entry then
            if #status >= MAX_STATUSES then
                for i = #status, 1, -1 do
                    if not Config.AuthoritativeStatuses[status[i].name] then
                        table.remove(status, i)
                        break
                    end
                end
            end

            entry = { name = name, val = math.min(Config.StatusMax, settings.default) }
            status[#status + 1] = entry
        end

        entry.val = math.max(0, entry.val - settings.decay * elapsed / Config.TickTime)
        entry.percent = entry.val / Config.StatusMax * 100
    end

    if persist ~= false then xPlayer.set('status', status, false) end
    return status
end

local function syncStatuses(xPlayer, statuses, changedName)
    local data = {}

    for _, entry in ipairs(statuses) do
        if (Config.AuthoritativeStatuses or {})[entry.name] or entry.name == changedName then
            data[#data + 1] = { name = entry.name, val = entry.val }
        end
    end

    if #data > 0 then TriggerClientEvent('esx_status:sync', xPlayer.source, data) end
end

local function changeStatus(src, name, value, additive)
    if type(value) ~= 'number' or value ~= value or math.abs(value) == math.huge then
        return false
    end

    local xPlayer = getStatusPlayer(src)

    if not xPlayer then
        return false
    end

    local statuses = advanceStatuses(xPlayer, false)

    for _, entry in ipairs(statuses) do
        if entry.name == name then
            entry.val = math.max(0, math.min(Config.StatusMax, (additive and entry.val or 0) + value))
            entry.percent = entry.val / Config.StatusMax * 100
            xPlayer.set('status', statuses, false)
            syncStatuses(xPlayer, statuses, name)
            return true
        end
    end

    return false
end

AddEventHandler('esx_status:set', function(src, name, value)
    changeStatus(src, name, value, false)
end)

AddEventHandler('esx_status:add', function(src, name, value)
    changeStatus(src, name, value, true)
end)

CreateThread(function()
    while true do
        local playerIds = ESX.GetExtendedPlayers(nil, nil, true)
        local slices = math.max(1, math.floor(math.min(Config.SyncSlices or 30, Config.UpdateInterval)))
        local sliceInterval = math.max(1, math.floor(Config.UpdateInterval / slices))

        for slice = 1, slices do
            Wait(sliceInterval)

            for index = slice, #playerIds, slices do
                local xPlayer = getStatusPlayer(playerIds[index])

                if xPlayer and not loadingStatuses[xPlayer] then
                    local status = xPlayer.get('status')
                    if type(status) == 'table' then
                        syncStatuses(xPlayer, advanceStatuses(xPlayer))
                    end
                end
            end
        end
    end
end)

---@param src number
---@param xPlayer table
local function loadPlayerStatuses(src, xPlayer)
    if not isCurrentPlayer(src, xPlayer) then return end
    
    local current = statusPlayers[src]
    if current and isCurrentPlayer(src, current) then xPlayer = current end

    if loadingStatuses[xPlayer] then return end

    statusPlayers[src] = xPlayer
    loadingStatuses[xPlayer] = true
    
    local ok, status = pcall(MySQL.scalar.await,
        'SELECT `status` FROM `users` WHERE `identifier` = ? LIMIT 1', { xPlayer.getIdentifier() })
    loadingStatuses[xPlayer] = nil

    if not ok then
        local delay = loadRetryDelays[xPlayer] or Config.LoadRetryInitial or 5000
        loadRequests[xPlayer] = loadRequests[xPlayer] or (GetGameTimer() + delay)
        loadRetryDelays[xPlayer] = math.min(delay * 2, Config.LoadRetryMax or 60000)
        
        print(('[esx_status] Unable to load statuses for player %s: %s'):format(src, tostring(status)))
        return
    end

    if not isCurrentPlayer(src, xPlayer) then
        return
    end

    if type(status) == 'string' then
        local ok, decoded = pcall(json.decode, status)

        status = ok and decoded or nil
    end

    status = normalizeStatus(status) or {}
    loadRetryDelays[xPlayer] = nil
    xPlayer.set('status', status, false)

    if next(Config.AuthoritativeStatuses or {}) then
        status = advanceStatuses(xPlayer)
    end

    TriggerClientEvent('esx_status:load', xPlayer.source, status)
end

AddEventHandler('esx:playerLoaded', loadPlayerStatuses)

RegisterNetEvent('esx_status:requestLoad', function()
    local src = source
    local xPlayer = getStatusPlayer(src)
    if not xPlayer or loadingStatuses[xPlayer] then return end

    local now = GetGameTimer()
    if loadRequests[xPlayer] and now < loadRequests[xPlayer] then return end
    loadRequests[xPlayer] = now + (loadRetryDelays[xPlayer] or Config.LoadRetryInitial or 5000)

    local status = xPlayer.get('status')
    if type(status) ~= 'table' then
        loadPlayerStatuses(src, xPlayer)
    else
        TriggerClientEvent('esx_status:load', src, advanceStatuses(xPlayer))
    end
end)

---@param src number
---@param reason string
AddEventHandler('esx:playerDropped', function(src, reason)
    updateRequests[src] = nil
    local xPlayer = getStatusPlayer(src)

    if not xPlayer then
        return
    end

    statusPlayers[src] = nil
    local storedStatus = xPlayer.get('status')
    if loadingStatuses[xPlayer] or type(storedStatus) ~= 'table' then return end
    local status = advanceStatuses(xPlayer)

    MySQL.update('UPDATE users SET status = ? WHERE identifier = ?', { json.encode(status), xPlayer.getIdentifier() })
end)

---@param src number
---@param statusName string
---@param cb function|table
AddEventHandler('esx_status:getStatus', function(src, statusName, cb)
    local callbackType = type(cb)
    local callbackMetatable = callbackType == 'table' and getmetatable(cb)
    local callable = callbackType == 'function' or (callbackMetatable and type(callbackMetatable.__call) == 'function')

    if type(statusName) ~= 'string' or not callable then
        return
    end

    local xPlayer = getStatusPlayer(src)

    if not xPlayer then
        return
    end

    if next(Config.AuthoritativeStatuses or {}) then
        advanceStatuses(xPlayer)
    end

    local status = normalizeStatus(xPlayer.get('status'), statusName)

    if status then
        return cb(status)
    end
end)

---@param status table
RegisterNetEvent('esx_status:update', function(status)
    local src = source
    local now = GetGameTimer()
    local lastUpdate = updateRequests[src]
    if lastUpdate and now - lastUpdate < (Config.MinUpdateInterval or 10000) then return end
    updateRequests[src] = now
    local xPlayer = getStatusPlayer(src)

    if not xPlayer or loadingStatuses[xPlayer] then
        return
    end

    if next(Config.AuthoritativeStatuses or {}) then
        local storedStatus = xPlayer.get('status')
        if type(storedStatus) ~= 'table' then return end
    end

    status = normalizeStatus(status)

    if not status then
        return
    end

    if not next(Config.AuthoritativeStatuses or {}) then
        xPlayer.set('status', status, false)
        return
    end

    local authoritative = advanceStatuses(xPlayer, false)
    local merged = {}

    for _, entry in ipairs(authoritative) do
        if (Config.AuthoritativeStatuses or {})[entry.name] then
            merged[#merged + 1] = entry
        end
    end

    for _, entry in ipairs(status) do
        if not (Config.AuthoritativeStatuses or {})[entry.name] and #merged < MAX_STATUSES then
            merged[#merged + 1] = entry
        end
    end

    xPlayer.set('status', merged, false)
end)
