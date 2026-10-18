-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local OriginalStatus, Status, isPaused = {}, {}, false
local loadGeneration = 0
local statusLoaded = false

function GetStatusData(minimal)
	local status = {}

	for i=1, #Status, 1 do
		if minimal then
			table.insert(status, {
				name    = Status[i].name,
				val     = Status[i].val,
				percent = (Status[i].val / Config.StatusMax) * 100
			})
		else
			table.insert(status, {
				name    = Status[i].name,
				val     = Status[i].val,
				color   = Status[i].color,
				visible = Status[i].visible(Status[i]),
				percent = (Status[i].val / Config.StatusMax) * 100
			})
		end
	end

	return status
end

AddEventHandler('esx_status:registerStatus', function(name, default, color, visible, tickCallback)
	local status = CreateStatus(name, default, color, visible, tickCallback)
	
	for i=1, #OriginalStatus, 1 do
		if status.name == OriginalStatus[i].name then
			status.set(OriginalStatus[i].val)
		end
	end

	for i = 1, #Status do
		if Status[i].name == name then
			status.set(Status[i].val)
			Status[i] = status
			return
		end
	end

	table.insert(Status, status)
end)

AddEventHandler('esx_status:unregisterStatus', function(name)
	for k,v in ipairs(Status) do
		if v.name == name then
			table.remove(Status, k)
			break
		end
	end
end)

RegisterNetEvent('esx:onPlayerLogout', function()
	loadGeneration = loadGeneration + 1
	statusLoaded = false
	OriginalStatus = {}
	Status = {}
	if Config.Display then
		SendNUIMessage({
			update = true,
			status = Status
		})
	end
end)

RegisterNetEvent('esx_status:load', function(status)
	while not ESX.PlayerLoaded do Wait(0) end

	OriginalStatus = status
	ESX.PlayerData.variables = ESX.PlayerData.variables or {}
	ESX.PlayerData.variables.status = OriginalStatus
	statusLoaded = true
	loadGeneration = loadGeneration + 1

	local generation = loadGeneration
	
	for i = 1, #Status do
		for _, entry in ipairs(status) do
			if Status[i].name == entry.name then
				Status[i].set(entry.val)
				break
			end
		end
	end
	TriggerEvent('esx_status:loaded')

	if Config.Display then TriggerEvent('esx_status:setDisplay', 0.5) end

	CreateThread(function()
		local data = {}
		while ESX.PlayerLoaded and generation == loadGeneration do
			for i=1, #Status do
				Status[i].onTick()
				table.insert(data, {
					name = Status[i].name,
					val = Status[i].val,
					percent = (Status[i].val / Config.StatusMax) * 100
				})
			end

			if Config.Display then
				local fullData = data
				for i=1, #data, 1 do
					fullData[i].color = Status[i].color
					fullData[i].visible = Status[i].visible(Status[i])
				end
				SendNUIMessage({
					update = true,
					status = fullData
				})
			end

			TriggerEvent('esx_status:onTick', data)
			table.wipe(data)
			Wait(Config.TickTime)
		end
	end)
end)

CreateThread(function()
	local delay = Config.LoadRetryInitial or 5000
	while true do
		if ESX.PlayerLoaded and not statusLoaded then
			TriggerServerEvent('esx_status:requestLoad')
			Wait(delay)
			delay = math.min(delay * 2, Config.LoadRetryMax or 60000)
		else
			delay = Config.LoadRetryInitial or 5000
			Wait(delay)
		end
	end
end)

RegisterNetEvent('esx_status:sync', function(data)
	for _, entry in ipairs(data) do
		
		local saved

		for _, original in ipairs(OriginalStatus) do
			if original.name == entry.name then saved = original break end
		end

		if not saved then
			saved = { name = entry.name }
			OriginalStatus[#OriginalStatus + 1] = saved
		end

		saved.val = entry.val
		saved.percent = entry.val / Config.StatusMax * 100

		for _, status in ipairs(Status) do
			if status.name == entry.name then status.set(entry.val) break end
		end
	end

	ESX.PlayerData.variables = ESX.PlayerData.variables or {}
	ESX.PlayerData.variables.status = OriginalStatus

	if Config.Display then
		SendNUIMessage({ update = true, status = GetStatusData() })
	end
end)

RegisterNetEvent('esx_status:set', function(name, val)
	for i=1, #Status, 1 do
		if Status[i].name == name then
			Status[i].set(val)
			break
		end
	end
	if Config.Display then
		SendNUIMessage({
			update = true,
			status = GetStatusData()
		})
	end
end)

RegisterNetEvent('esx_status:add', function(name, val)
	for i=1, #Status, 1 do
		if Status[i].name == name then
			Status[i].add(val)
			break
		end
	end
	if Config.Display then
		SendNUIMessage({
			update = true,
			status = GetStatusData()
		})
	end
end)

RegisterNetEvent('esx_status:remove', function(name, val)
	for i=1, #Status, 1 do
		if Status[i].name == name then
			Status[i].remove(val)
			break
		end
	end
		if Config.Display then
		SendNUIMessage({
			update = true,
			status = GetStatusData()
		})
	end
end)

AddEventHandler('esx_status:getStatus', function(name, cb)
	for i=1, #Status, 1 do
		if Status[i].name == name then
			cb(Status[i])
			return
		end
	end
end)

AddEventHandler('esx_status:getAllStatus', function(cb)
	cb(Status)
end)

AddEventHandler('esx_status:setDisplay', function(val)
	SendNUIMessage({
		setDisplay = true,
		display    = val
	})
end)

-- Pause menu disable hud display
if Config.Display then
	AddEventHandler('esx:pauseMenuActive', function(state)
		if state then
			isPaused = true
			TriggerEvent('esx_status:setDisplay', 0.0)
			return
		end
		isPaused = false
		TriggerEvent('esx_status:setDisplay', 0.5)
	end)

	-- Loading screen off event
	AddEventHandler('esx:loadingScreenOff', function()
		if not isPaused then
			TriggerEvent('esx_status:setDisplay', 0.3)
		end
	end)
end

-- Update server
CreateThread(function()
	local hadCustomStatuses = false

	Wait(math.random(0, Config.UpdateInterval - 1))
	
	while true do
		if ESX.PlayerLoaded and statusLoaded then
			local custom = {}

			for _, status in ipairs(Status) do
				if not (Config.AuthoritativeStatuses or {})[status.name] then
					custom[#custom + 1] = { name = status.name, val = status.val }
				end
			end

			if #custom > 0 or hadCustomStatuses then
				TriggerServerEvent('esx_status:update', custom)
			end

			hadCustomStatuses = #custom > 0
		else
			hadCustomStatuses = false
		end
		
		Wait(Config.UpdateInterval)
	end
end)
