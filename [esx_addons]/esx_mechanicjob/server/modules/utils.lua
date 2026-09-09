-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local MechanicJob = ESXMechanicJob

function MechanicJob.currentTimeMs()
	if type(GetGameTimer) == 'function' then
		return GetGameTimer()
	end

	return math.floor(os.clock() * 1000)
end

function MechanicJob.rejectRateLimited(source, key, cooldown)
	local now = MechanicJob.currentTimeMs()
	local playerLimits = MechanicJob.RateLimits[source]

	if not playerLimits then
		playerLimits = {}
		MechanicJob.RateLimits[source] = playerLimits
	end

	if (playerLimits[key] or 0) > now then
		return true
	end

	playerLimits[key] = now + cooldown
	return false
end

function MechanicJob.getMechanicPlayer(source)
	local xPlayer = ESX.Player(source)

	if not xPlayer then
		return nil
	end

	local job = xPlayer.getJob()
	if not job or job.name ~= 'mechanic' then
		return nil
	end

	return xPlayer, job
end

function MechanicJob.getWorkshopMechanicPlayer(source)
	local xPlayer, job = MechanicJob.getMechanicPlayer(source)

	if not xPlayer then
		return nil
	end

	if Config.EnablePlayerManagement and job.grade_name == 'recrue' then
		return nil
	end

	return xPlayer
end

function MechanicJob.normalizeItemCount(count)
	count = tonumber(count)

	if not count then
		return nil
	end

	count = math.floor(count)
	if count <= 0 then
		return nil
	end

	return count
end

function MechanicJob.isPlayerNearCoords(source, coords, distance)
	local nearby = xLib.player.isNearCoords(source, coords, distance)
	return nearby
end

function MechanicJob.isPlayerNearZone(source, zoneName, distance)
	local zone = Config.Zones and Config.Zones[zoneName]
	if not zone or not zone.Pos then
		return false
	end

	return MechanicJob.isPlayerNearCoords(source, zone.Pos, distance)
end
