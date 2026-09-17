-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

---Computes the min/max salary across all grades of a job
---@param job table
---@return number minSalary
---@return number maxSalary
local function getSalaryRange(job)
	local minSalary, maxSalary

	for _, grade in pairs(job.grades or {}) do
		local salary = tonumber(grade.salary) or 0

		if minSalary == nil or salary < minSalary then
			minSalary = salary
		end

		if maxSalary == nil or salary > maxSalary then
			maxSalary = salary
		end
	end

	return minSalary or 0, maxSalary or 0
end

function getJobs()
	local jobs = ESX.GetJobs()
	local availableJobs = {}

	for k, v in pairs(jobs) do
		if v.whitelisted == false then
			local salaryMin, salaryMax = getSalaryRange(v)

			availableJobs[#availableJobs + 1] = {
				label = v.label,
				name = k,
				icon = (Config.JobIcons and Config.JobIcons[k]) or Config.DefaultJobIcon or 'Briefcase',
				description = Config.JobDescriptions and Config.JobDescriptions[k] or nil,
				salaryMin = salaryMin,
				salaryMax = salaryMax
			}
		end
	end

	return availableJobs
end

xLib.callback.registerCompat('esx_joblisting:getJobsList', function(source, cb)
	cb(getJobs())
end)

function IsJobAvailable(job)
	local jobs = ESX.GetJobs()
	local JobToCheck = jobs[job]

	return not JobToCheck.whitelisted
end

function IsNearCentre(player)
	local Ped = GetPlayerPed(player)
	local PedCoords = GetEntityCoords(Ped)

	for i = 1, #Config.Zones, 1 do
		local distance = #(PedCoords - Config.Zones[i])

		if distance < Config.DrawDistance then
			return true
		end
	end

	return false
end

---Validates and applies a job to a player
---@param source number Player server id
---@param job string Job name
---@return boolean success
---@return string reason
local function ApplyJobForPlayer(source, job)
	local xPlayer = ESX.Player(source)

	if not xPlayer then
		print("[^3WARNING^7] User ^5" .. source .. "^7 Attempted to Exploit ^5`esx_joblisting:setJob`^7!")
		return false, 'invalid_player'
	end

	if not ESX.DoesJobExist(job, 0) then
		print("[^1ERROR^7] Tried Setting User ^5" .. source .. "^7 To Invalid Job - ^5" .. job .. "^7!")
		return false, 'invalid_job'
	end

	if not IsJobAvailable(job) then
		print("[^3WARNING^7] User ^5" .. source .. "^7 Attempted to Exploit ^5`esx_joblisting:setJob`^7!")
		return false, 'job_unavailable'
	end

	if not IsNearCentre(source) then
		print("[^3WARNING^7] User ^5" .. source .. "^7 Attempted to Exploit ^5`esx_joblisting:setJob`^7!")
		return false, 'not_near'
	end

	xPlayer.setJob(job, 0)

	return true, 'success'
end

RegisterServerEvent('esx_joblisting:setJob')
AddEventHandler('esx_joblisting:setJob', function(job)
	ApplyJobForPlayer(source, job)
end)

xLib.callback.registerCompat('esx_joblisting:applyJob', function(source, cb, job)
	local success, reason = ApplyJobForPlayer(source, job)

	if success then
		local jobs = ESX.GetJobs()
		local label = jobs[job] and jobs[job].label or job

		cb({ success = success, reason = reason, label = label })
		return
	end

	cb({ success = success, reason = reason })
end)