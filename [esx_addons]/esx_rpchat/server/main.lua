-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local function getCooldown(name, fallback)
	local cooldown = tonumber(Config[name]) or fallback
	if cooldown < 0 then
		return 0
	end
	return math.floor(cooldown)
end

local function createChatLimiter(configName, fallback)
	local cooldown = getCooldown(configName, fallback)
	if cooldown <= 0 then
		return nil
	end

	return xLib.rateLimiter({
		capacity = 1,
		refill = 1,
		interval = cooldown,
		staleMs = math.max(60000, cooldown * 4),
	})
end

local chatLimiters = {
	ooc = createChatLimiter('OocCooldown', 3000),
	twt = createChatLimiter('TwtCooldown', 10000),
	anontwt = createChatLimiter('AnonTwtCooldown', 15000),
}

local function sendRateLimitMessage(playerId, remainingMs)
	local seconds = math.max(1, math.ceil(remainingMs / 1000))
	local message = (Config.RateLimitMessage or "Please wait %s seconds before sending another message."):format(seconds)

	TriggerClientEvent('chat:addMessage', playerId, {args = {'SYSTEM', message}, color = {255, 0, 0}})
end

local function isRateLimited(playerId, key)
	local limiter = chatLimiters[key]
	if playerId == 0 or not limiter then
		return false
	end

	local allowed, retryAfter = limiter:consume(playerId)
	if not allowed then
		sendRateLimitMessage(playerId, retryAfter)
		return true
	end

	return false
end

local function getProximityDistance()
	local distance = tonumber(Config.ProximityDistance) or 20.0
	if distance <= 0 then
		return 20.0
	end
	return distance
end

local function getProximityTargets(playerId)
	local nearby = xLib.onesync.getPlayersInArea(playerId, getProximityDistance(), nil, GetPlayerRoutingBucket(playerId))
	local targets = {}
	local hasSender = false

	for i = 1, #nearby do
		local targetId = nearby[i].id
		targets[#targets + 1] = targetId

		if targetId == playerId then
			hasSender = true
		end
	end

	if not hasSender then
		targets[#targets + 1] = playerId
	end

	return targets
end

local function sendProximityMessage(playerId, title, message, color)
	local targets = getProximityTargets(playerId)
	xLib.triggerClientEvent('esx_rpchat:sendProximityMessage', targets, title, message, color)
end

AddEventHandler('chatMessage', function(playerId, playerName, message)
	if string.sub(message, 1, string.len('/')) ~= '/' then
		CancelEvent()

		if isRateLimited(playerId, 'ooc') then
			return
		end

		playerName = GetRealPlayerName(playerId)
		TriggerClientEvent('chat:addMessage', -1, {args = {TranslateCap('ooc_prefix', playerName), message}, color = {128, 128, 128}})
	end
end)

RegisterCommand('twt', function(playerId, args, rawCommand)
	if playerId == 0 then
		print('[^1ERROR^7] This Command Cannot Be Used By The Console!')
	else
		if isRateLimited(playerId, 'twt') then
			return
		end

		args = table.concat(args, ' ')

		local playerName = GetRealPlayerName(playerId)

		TriggerClientEvent('chat:addMessage', -1, {args = {TranslateCap('twt_prefix', playerName), args}, color = {0, 153, 204}})
	end
end, false)

RegisterCommand('anontwt', function(playerId, args, rawCommand)
	if playerId == 0 then
		print('[^1ERROR^7] This Command Cannot Be Used By The Console!')
	else
		if isRateLimited(playerId, 'anontwt') then
			return
		end

		args = table.concat(args, ' ')

		local playerName = GetRealPlayerName(playerId)

		TriggerClientEvent('chat:addMessage', -1, {args = {TranslateCap('twt_prefix', "Anonymous"), args}, color = {0, 153, 204}})
	end
end, false)

RegisterCommand('me', function(playerId, args, rawCommand)
	if playerId == 0 then
		print('[^1ERROR^7] This Command Cannot Be Used By The Console!')
	else
		args = table.concat(args, ' ')
		local playerName = GetRealPlayerName(playerId)

		sendProximityMessage(playerId, TranslateCap('me_prefix', playerName), args, {255, 0, 0})
	end
end, false)

RegisterCommand('do', function(playerId, args, rawCommand)
	if playerId == 0 then
		print('[^1ERROR^7] This Command Cannot Be Used By The Console!')
	else
		args = table.concat(args, ' ')
		local playerName = GetRealPlayerName(playerId)

		sendProximityMessage(playerId, TranslateCap('do_prefix', playerName), args, {0, 0, 255})
	end
end, false)

RegisterCommand('msg', function(source, args, user)

	if GetPlayerName(tonumber(args[1])) then
		local player = tonumber(args[1])
		table.remove(args, 1)

		TriggerClientEvent('chat:addMessage', player, {args = {"^1PM from "..GetPlayerName(source).. "[" .. source .. "]: ^7" ..table.concat(args, " ")}, color = {255, 153, 0}})
		TriggerClientEvent('chat:addMessage', source, {args = {"^1PM SEND TO "..GetPlayerName(player).. "[" .. player .. "]: ^7" ..table.concat(args, " ")}, color = {255, 153, 0}})
	else
		TriggerClientEvent('chatMessage', source, "SYSTEM", {255, 0, 0}, "Specified Player Does Not Exist!")
	end

end,false)

function GetRealPlayerName(playerId)
	local xPlayer = ESX.GetPlayerFromId(playerId)

	if xPlayer then
		if Config.EnableESXIdentity then
			if Config.OnlyFirstname then
				return xPlayer.get('firstName')
			else
				return xPlayer.getName()
			end
		else
			return GetPlayerName(playerId)
		end
	else
		return GetPlayerName(playerId)
	end
end
