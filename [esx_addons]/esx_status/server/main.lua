-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

ESXCatalog.awaitReady()

local MAX_STATUSES = 64
local MAX_STATUS_NAME_LENGTH = 64

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

		if
			count > MAX_STATUSES
			or type(index) ~= 'number'
			or index % 1 ~= 0
			or index < 1
			or index > MAX_STATUSES
			or type(entry) ~= 'table'
		then
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

	TriggerClientEvent('esx_status:load', xPlayer.source, status)
end)

---@param src number
---@param reason string
AddEventHandler('esx:playerDropped', function(src, reason)
	local xPlayer = ESX.Player(src)
	if not xPlayer then
		return
	end

	local status = normalizeStatus(xPlayer.get('status')) or {}
	MySQL.update('UPDATE users SET status = ? WHERE identifier = ?', { json.encode(status), xPlayer.getIdentifier() })
end)

---@param src number
---@param statusName string
---@param cb function|table
AddEventHandler('esx_status:getStatus', function(src, statusName, cb)
	local callbackType = type(cb)
	local callbackMetatable = callbackType == 'table' and getmetatable(cb)
	local callable = callbackType == 'function'
		or (callbackMetatable and type(callbackMetatable.__call) == 'function')

	if type(statusName) ~= 'string' or not callable then
		return
	end

	local xPlayer = ESX.Player(src)
	if not xPlayer then
		return
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

	xPlayer.set('status', status)
end)
