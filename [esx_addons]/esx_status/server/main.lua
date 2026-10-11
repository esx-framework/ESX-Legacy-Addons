-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

ESXCatalog.awaitReady()

local MAX_STATUSES = 64
local MAX_STATUS_NAME_LENGTH = 64
local statusClocks = setmetatable({}, { __mode = 'k' })

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

local function advanceStatuses(xPlayer)
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

    xPlayer.set('status', status)
    return status
end

local function changeStatus(src, name, value, additive)
    if type(value) ~= 'number' or value ~= value or math.abs(value) == math.huge then
        return false
    end

    local xPlayer = ESX.Player(src)

    if not xPlayer then
        return false
    end

    local statuses = advanceStatuses(xPlayer)

    for _, entry in ipairs(statuses) do
        if entry.name == name then
            entry.val = math.max(0, math.min(Config.StatusMax, (additive and entry.val or 0) + value))
            entry.percent = entry.val / Config.StatusMax * 100
            xPlayer.set('status', statuses)
            TriggerClientEvent('esx_status:set', src, name, entry.val)
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
        Wait(Config.UpdateInterval)

        for _, xPlayer in pairs(ESX.GetExtendedPlayers()) do
            for _, entry in ipairs(advanceStatuses(xPlayer)) do
                if (Config.AuthoritativeStatuses or {})[entry.name] then
                    TriggerClientEvent('esx_status:set', xPlayer.source, entry.name, entry.val)
                end
            end
        end
    end
end)

---@param src number
---@param xPlayer table
AddEventHandler('esx:playerLoaded', function(src, xPlayer)
    local status = MySQL.scalar.await('SELECT `status` FROM `users` WHERE `identifier` = ? LIMIT 1', { xPlayer.getIdentifier() })

    if ESX.GetPlayerFromId(src) ~= xPlayer then
        return
    end

    if type(status) == 'string' then
        local ok, decoded = pcall(json.decode, status)

        status = ok and decoded or nil
    end

    status = normalizeStatus(status) or {}
    xPlayer.set('status', status)

    if next(Config.AuthoritativeStatuses or {}) then
        status = advanceStatuses(xPlayer)
    end

    TriggerClientEvent('esx_status:load', xPlayer.source, status)
end)

---@param src number
---@param reason string
AddEventHandler('esx:playerDropped', function(src, reason)
    local xPlayer = ESX.Player(src)

    if not xPlayer then
        return
    end

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

    local xPlayer = ESX.Player(src)

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
    local xPlayer = ESX.Player(source)

    if not xPlayer then
        return
    end

    status = normalizeStatus(status)

    if not status then
        return
    end

    if not next(Config.AuthoritativeStatuses or {}) then
        xPlayer.set('status', status)
        return
    end

    local authoritative = advanceStatuses(xPlayer)
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

    xPlayer.set('status', merged)
end)
