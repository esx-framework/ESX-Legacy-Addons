local InService    = {}
local MaxInService = {}
local PlayersJob = {}

function GetInServiceCount(name)
	if InService[name] == nil then return 0 end
	local count = 0

	for k,v in pairs(InService[name]) do
		if v == true then
			count = count + 1
		end
	end

	return count
end

AddEventHandler('esx:playerLoaded', function (playerId, xPlayer, isNew)
	local job = xPlayer.job
	PlayersJob[playerId] = xPlayer.job
	if InService[job.name] then
		InService[job.name][playerId] = job.onDuty
	end
end)

AddEventHandler('esx:setJob', function(source,job,lastJob)
    PlayersJob[source] = job
end)

local function checkPlayersService(name)
	local jobPlayers = ESX.GetExtendedPlayers('job', name)
	
	for i, xPlayer in ipairs(jobPlayers) do
		InService[name][xPlayer.source] = xPlayer.job.onDuty
	end
end

local function setDuty(playerId, status)
	local xPlayer = ESX.GetPlayerFromId(playerId)
	local job = PlayersJob[playerId]

	xPlayer.setJob(job.name, job.grade, status)
end

RegisterServerEvent('esx_service:activateService')
AddEventHandler('esx_service:activateService', function(name, max)
	if not name or not max then return end
	
	InService[name] = {}
	MaxInService[name] = max
	GlobalState[name] = GetInServiceCount(name)
	checkPlayersService(name)
end)

RegisterServerEvent('esx_service:disableService')
AddEventHandler('esx_service:disableService', function()
	local job = PlayersJob[source]

	if not InService[job.name] then return end

	InService[job.name][source] = nil
	GlobalState[job.name] = GetInServiceCount(job.name)
	setDuty(source, false)
end)

RegisterServerEvent('esx_service:notifyAllInService')
AddEventHandler('esx_service:notifyAllInService', function(notification, name)
	for k,v in pairs(InService[name]) do
		if v == true then
			TriggerClientEvent('esx_service:notifyAllInService', k, notification, source)
		end
	end
end)

ESX.RegisterServerCallback('esx_service:enableService', function(source, cb)
	local job = PlayersJob[source]

	local inServiceCount = GetInServiceCount(job.name)
	
	if inServiceCount >= MaxInService[job.name] then
		cb(false, MaxInService[job.name], inServiceCount)
	else
		InService[job.name][source] = true
		GlobalState[job.name] = GetInServiceCount(job.name)
		setDuty(source, true)
		cb(true, MaxInService[job.name], inServiceCount)		
	end
end)

ESX.RegisterServerCallback('esx_service:isInService', function(source, cb)
	local job = PlayersJob[source]
	local isInService = job and job.onDuty or false

	if InService[job.name] == nil then
		print(('[^3WARNING^7] Attempted To Use Inactive Service - ^5%s^7'):format(job.name))
	end

	cb(isInService)
end)

ESX.RegisterServerCallback('esx_service:isPlayerInService', function(source, cb, _, target)
	local job = PlayersJob[target]

	local isPlayerInService = job and job.onDuty or false

	cb(isPlayerInService)
end)

ESX.RegisterServerCallback('esx_service:getInServiceList', function(source, cb, name)
	cb(InService[name])
end)

AddEventHandler('esx:playerDropped', function(playerId, reason)
	PlayersJob[playerId] = nil
	for k,v in pairs(InService) do
		if v[playerId] == true then
			v[playerId] = nil
			GlobalState[k] = GetInServiceCount(k)
		end
	end
end)

AddEventHandler('onResourceStart', function(resourceName)
  if (GetCurrentResourceName() ~= resourceName) then return end
  local xPlayers = ESX.GetExtendedPlayers()
 
	for i, xPlayer in ipairs(xPlayers) do
		PlayersJob[xPlayer.source] = xPlayer.job
	end
end)
