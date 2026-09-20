-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local lastChange = {}
local openLimiter = xLib.rateLimiter({
    capacity = 3,
    refill = 1,
    interval = 1000
})
local listLimiter = xLib.rateLimiter({
    capacity = 3,
    refill = 1,
    interval = 1000
})

local function progressFor(player, job)
    local metadata = player.getMeta() or {}
    local data = metadata.joblisting or {}

    return type(data[job]) == 'table' and data[job] or {}
end

function getJobs(player)
    local available = {}

    for name, job in pairs(ESX.GetJobs()) do
        if job.whitelisted == false and ESX.DoesJobExist(name, 0) then
            local details = Config.JobDetails[name] or {}
            local grade = job.grades['0'] or job.grades[0] or {}
            local progress = player and progressFor(player, name) or {}

            available[#available + 1] = {
                name = name,
                label = job.label,
                salary = tonumber(grade.salary) or 0,
                subtitle = details.subtitle,
                description = details.description,
                image = details.image,
                rating = details.rating,
                requirement = details.requirement,
                location = details.location,
                tasks = progress.tasks or details.tasks or {}
            }
        end
    end

    table.sort(available, function(a, b)
        if a.label == b.label then
            return a.name < b.name
        end

        return a.label < b.label
    end)

    return available
end

function IsJobAvailable(name)
    if type(name) ~= 'string' then
        return false
    end

    local job = ESX.GetJobs()[name]

    return job ~= nil and job.whitelisted == false and ESX.DoesJobExist(name, 0)
end

function IsNearCentre(player)
    return xLib.player.isNearAnyCoords(player, Config.Zones, Config.DrawDistance)
end

local function ageFromBirth(value)
    if type(value) ~= 'string' then
        return nil
    end

    local year, month, day = value:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')

    if not year then
        day, month, year = value:match('^(%d%d)[/-](%d%d)[/-](%d%d%d%d)$')
    end

    year, month, day = tonumber(year), tonumber(month), tonumber(day)

    if not year or not month or not day then
        return nil
    end

    local now = os.date('*t')
    local age = now.year - year

    if now.month < month or (now.month == month and now.day < day) then
        age = age - 1
    end

    return age >= 0 and age <= 120 and age or nil
end

local function profileFor(player)
    local job = player.getJob()
    local progress = progressFor(player, job.name)
    local sex = player.get('sex')

    return {
        name = player.getName(),
        id = player.getSource(),
        age = ageFromBirth(player.get('dateofbirth')),
        gender = sex == 'm' and 'Male' or sex == 'f' and 'Female' or nil,
        phone = player.get('phoneNumber'),
        job = {
            name = job.name,
            label = job.label,
            gradeLabel = job.grade_label,
            salary = job.grade_salary,
            unemployed = job.name == Config.UnemployedJob
        },
        stats = progress.stats or {},
        tasks = progress.tasks or {}
    }
end

xLib.callback.registerCompat('esx_joblisting:getJobsList', function(source, cb)
    if not listLimiter:consume(source) then
        cb({})
        return
    end

    cb(getJobs(ESX.Player(source)))
end)

xLib.callback.register('esx_joblisting:open', function(source)
    local player = ESX.Player(source)

    if not player then
        return {ok = false}
    end

    if not openLimiter:consume(source) then
        return {ok = false}
    end

    if not IsNearCentre(source) then
        return {ok = false}
    end

    return {ok = true, jobs = getJobs(player), profile = profileFor(player)}
end)

local function changeJob(source, name)
    local player = ESX.Player(source)

    if not player or type(name) ~= 'string' or not IsNearCentre(source) then
        return {ok = false, message = 'Please visit the Job Center to change jobs.'}
    end

    if not IsJobAvailable(name) then
        return {ok = false, message = 'This job is not available.'}
    end

    if player.getJob().name == name then
        return {ok = false, message = 'You already have this job.'}
    end

    local now = GetGameTimer()

    if lastChange[source] and now - lastChange[source] < 1500 then
        return {ok = false, message = 'Please wait a moment before changing jobs again.'}
    end

    lastChange[source] = now
    player.setJob(name, 0)

    return {ok = true, profile = profileFor(player)}
end

xLib.callback.register('esx_joblisting:apply', function(source, name)
    return changeJob(source, name)
end)

xLib.callback.register('esx_joblisting:quit', function(source)
    return changeJob(source, Config.UnemployedJob)
end)

RegisterNetEvent('esx_joblisting:setJob', function(name)
    changeJob(source, name)
end)

exports('UpdateJobProgress', function(playerId, name, data)
    local player = ESX.Player(playerId)

    if not player or type(name) ~= 'string' or type(data) ~= 'table' then
        return false
    end

    local progress = {
        stats = {},
        tasks = {}
    }

    if type(data.stats) == 'table' then
        for key, value in pairs(data.stats) do
            if #progress.stats >= 64 then
                break
            end

            if type(key) ~= 'string' then
                key = tostring(key)
            end

            if type(value) == 'number' and math.abs(value) < 1e15 then
                progress.stats[key] = value
            elseif type(value) == 'string' and #value <= 64 then
                progress.stats[key] = value
            end
        end
    end

    if type(data.tasks) == 'table' then
        for i = 1, #data.tasks do
            if #progress.tasks >= 64 then
                break
            end

            local task = data.tasks[i]

            if type(task) == 'table' then
                local title = xLib.validation.string(task.title, {maxLength = 64})
                local current = xLib.validation.integer(task.current, 0, 100000, 'floor')
                local target = xLib.validation.integer(task.target, 0, 100000, 'floor')

                if title and current and target then
                    progress.tasks[#progress.tasks + 1] = {
                        title = title,
                        current = current,
                        target = target
                    }
                end
            end
        end
    end

    local all = (player.getMeta() or {}).joblisting or {}
    all[name] = progress
    player.setMeta('joblisting', all)

    TriggerClientEvent('esx_joblisting:profileUpdated', playerId, profileFor(player))

    return true
end)

AddEventHandler('playerDropped', function()
    lastChange[source] = nil
end)