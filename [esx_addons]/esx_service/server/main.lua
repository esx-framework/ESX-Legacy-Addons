-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local InService    = {}
local MaxInService = {}

local function ensureService(name, max)
	if type(name) ~= 'string' or name == '' then return false end

	if InService[name] == nil then
		InService[name] = {}
	end

	if max ~= nil then
		max = tonumber(max)
		MaxInService[name] = max and math.floor(max) or -1
	elseif MaxInService[name] == nil then
		MaxInService[name] = -1
	end

	return true
end

local function validateInternalCall(eventName)
	local invokingResource = GetInvokingResource()

	if invokingResource then
		return true
	end

	print(('[^3WARNING^7] Blocked external call to ^5%s^7'):format(eventName))
	return false
end

function GetInServiceCount(name)
	local count = 0

	if InService[name] == nil then
		return count
	end

	for k,v in pairs(InService[name]) do
		if v == true then
			count = count + 1
		end
	end

	return count
end

AddEventHandler('esx_service:activateService', function(name, max)
	if not validateInternalCall('esx_service:activateService') then return end
	if not ensureService(name, max) then return end

	GlobalState[name] = GetInServiceCount(name)
end)

local function disableService(source, name)
	if not ensureService(name) then return false end

	InService[name][source] = nil
	GlobalState[name] = GetInServiceCount(name)
	return true
end

AddEventHandler('esx_service:disableService', function(name, target)
	if not validateInternalCall('esx_service:disableService') then return end

	local playerId = tonumber(target) or tonumber(source)
	if not playerId or playerId <= 0 then return end

	disableService(playerId, name)
end)

local function notifyAllInService(notification, name, sender)
	if type(notification) ~= 'table' or not InService[name] then return end

	for k,v in pairs(InService[name]) do
		if v == true then
			TriggerClientEvent('esx_service:notifyAllInService', k, notification, sender or 0)
		end
	end
end

AddEventHandler('esx_service:notifyAllInService', function(notification, name, sender)
	if not validateInternalCall('esx_service:notifyAllInService') then return end

	notifyAllInService(notification, name, sender)
end)

xLib.callback.registerCompat('esx_service:enableService', function(source, cb, name)
	local xPlayer = ESX.Player(source)

	if not xPlayer or not ensureService(name) or xPlayer.getJob().name ~= name then
		return cb(false, MaxInService[name] or 0, GetInServiceCount(name))
	end

	local inServiceCount = GetInServiceCount(name)
	
	if MaxInService[name] ~= -1 and inServiceCount >= MaxInService[name] then
		cb(false, MaxInService[name], inServiceCount)
	else
		InService[name][source] = true
		GlobalState[name] = GetInServiceCount(name)
		cb(true, MaxInService[name], inServiceCount)		
	end
end)

xLib.callback.registerCompat('esx_service:disableService', function(source, cb, name)
	local xPlayer = ESX.Player(source)

	if not xPlayer or xPlayer.getJob().name ~= name then
		return cb(false)
	end

	cb(disableService(source, name))
end)

xLib.callback.registerCompat('esx_service:isInService', function(source, cb, name)
	local isInService = false

	if InService[name] ~= nil then
		if InService[name][source] then
			isInService = true
		end
	else
		print(('[^3WARNING^7] Attempted To Use Inactive Service - ^5%s^7'):format(name))
	end

	cb(isInService)
end)

xLib.callback.registerCompat('esx_service:isPlayerInService', function(source, cb, name, target)
	local isPlayerInService = false
	local xPlayer = ESX.Player(source)
	local targetXPlayer = ESX.Player(target)

	if not xPlayer or not targetXPlayer or xPlayer.getJob().name ~= name or targetXPlayer.getJob().name ~= name then
		return cb(false)
	end

	if InService[name] and InService[name][targetXPlayer.src] then
		isPlayerInService = true
	end

	cb(isPlayerInService)
end)

xLib.callback.registerCompat('esx_service:getInServiceList', function(source, cb, name)
	local xPlayer = ESX.Player(source)

	if not xPlayer or xPlayer.getJob().name ~= name then
		return cb({})
	end

	cb(InService[name])
end)

AddEventHandler('esx:playerDropped', function(playerId, reason)
	for k,v in pairs(InService) do
		if v[playerId] == true then
			v[playerId] = nil
			GlobalState[k] = GetInServiceCount(k)
		end
	end
end)
