-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

ESXCatalog.awaitReady()

local paidTests = {}
local purchases = {}
local paidTestDuration = 15 * 60 * 1000
local limiter = xLib.rateLimiter({ capacity = 2, refill = 1, interval = 2000 })
local checkpointLimiter = xLib.rateLimiter({ capacity = 4, refill = 1, interval = 250 })
local theoryAnswers = {}
local questionFile = Config.TheoryQuestionsFile or 'html/questions.js'
local questions = LoadResourceFile(GetCurrentResourceName(), questionFile) or ''

-- Use the answer key from the same question bank served by the NUI.
for answer in questions:gmatch('reponse%s*:%s*["\']([ABCD])["\']') do
    theoryAnswers[#theoryAnswers + 1] = answer
end

local function isValidTestType(testType)
    return type(testType) == 'string' and Config.Prices[testType] ~= nil
        and (testType == 'dmv' or Config.VehicleModels[testType] ~= nil)
end

local function isCurrentPlayer(source, player)
    return player.source == source and player.isCurrent() == true
end

local function isNearPosition(source, position, distance)
    local ped = GetPlayerPed(source)

    if ped <= 0 or not position then
        return false
    end

    return #(GetEntityCoords(ped) - vector3(position.x, position.y, position.z)) <= distance
end

local function isNearDmv(source)
    return isNearPosition(source, Config.Zones.DMVSchool.Pos, 20.0)
end

local function getTest(source, testType)
    local test = paidTests[source]

    if not test or test.granting or test.type ~= testType or test.expires < GetGameTimer() then
        return nil
    end

    if not isCurrentPlayer(source, test.player)
        or GetPlayerRoutingBucket(source) ~= test.bucket then
        return nil
    end

    return test
end

local function grantLicense(source, test, cb)
    if paidTests[source] ~= test or not isCurrentPlayer(source, test.player) then
        return cb(false)
    end

    test.granting = true
    test.expires = 0

    TriggerEvent('esx_license:addLicense', source, test.type, function(added)
        if paidTests[source] == test then
            paidTests[source] = nil
        end

        if not isCurrentPlayer(source, test.player) then
            return
        end

        if added then
            TriggerEvent('esx_license:getLicenses', source, function(licenses)
                if isCurrentPlayer(source, test.player) then
                    TriggerClientEvent('esx_dmvschool:loadLicenses', source, licenses)
                end
            end)
        end

        cb(added ~= nil and added ~= false)
    end)
end

xLib.callback.registerCompat('esx_dmvschool:canYouPay', function(source, cb, testType, account)
    local player = ESX.GetPlayerFromId(source)

    if not player or not isValidTestType(testType) or not isNearDmv(source) then
        return cb(false)
    end

    if not limiter:consume(source) then
        return cb(false, 'busy')
    end

    local identifier = player.getIdentifier()
    local previous = paidTests[source]

    if purchases[identifier] or (previous and previous.player.isCurrent() == true
        and (previous.granting or previous.expires >= GetGameTimer())) then
        return cb(false, 'busy')
    end

    if testType == 'dmv' and #theoryAnswers < 10 then
        return cb(false, 'questions_unavailable')
    end

    local pending = {}
    local finished = false
    purchases[identifier] = pending

    local function finish(success, failure, exam)
        if finished then
            return
        end

        finished = true
        purchases[identifier] = nil

        if isCurrentPlayer(source, player) then
            cb(success, failure, exam)
        end
    end

    SetTimeout(15000, function()
        if not finished then
            finish(false, 'unconfirmed')
        end
    end)

    local function purchase()
        TriggerEvent('esx_license:checkLicense', source, testType, function(hasLicense)
            if finished then
                return
            end

            if hasLicense or not isCurrentPlayer(source, player) or not isNearDmv(source) then
                return finish(false)
            end

            local charged, failure = PaymentGateway.Charge(
                player, account, Config.Prices[testType], 'DMV Purchase'
            )

            if not charged then
                return finish(false, failure)
            end

            local order = {}

            for index = 1, #theoryAnswers do
                order[index] = index - 1
            end

            for index = #order, 2, -1 do
                local swap = math.random(index)
                order[index], order[swap] = order[swap], order[index]
            end

            for index = #order, 11, -1 do
                order[index] = nil
            end

            local now = GetGameTimer()
            paidTests[source] = {
                player = player,
                type = testType,
                bucket = GetPlayerRoutingBucket(source),
                expires = now + paidTestDuration,
                started = now,
                lastCheckpointAt = now,
                checkpoint = 0,
                questions = order,
            }

            TriggerClientEvent('esx:showNotification', source,
                TranslateCap('you_paid', Config.Prices[testType]))
            finish(true, nil, { questions = order, required = 5 })
        end)
    end

    if testType == 'dmv' then
        purchase()
    else
        TriggerEvent('esx_license:checkLicense', source, 'dmv', function(hasTheory)
            if finished then
                return
            end

            if not hasTheory or not isCurrentPlayer(source, player) then
                return finish(false)
            end

            purchase()
        end)
    end
end)

xLib.callback.registerCompat('esx_dmvschool:finishTheory', function(source, cb, answers)
    local test = getTest(source, 'dmv')

    if not test or not limiter:consume(source) or not isNearDmv(source) then
        return cb(false)
    end

    local valid = type(answers) == 'table'
        and GetGameTimer() - test.started >= (Config.TheoryMinimumDuration or 30000)
    local correct = 0
    local count = 0

    if valid then
        for key, answer in pairs(answers) do
            count = count + 1

            if type(key) ~= 'number' or key % 1 ~= 0 or key < 1 or key > 10
                or type(answer) ~= 'string' or not answer:match('^[ABCD]$') then
                valid = false
                break
            end

            if theoryAnswers[test.questions[key] + 1] == answer then
                correct = correct + 1
            end
        end
    end

    if not valid or count ~= 10 or correct < 5 then
        paidTests[source] = nil
        return cb(false)
    end

    grantLicense(source, test, cb)
end)

xLib.callback.registerCompat('esx_dmvschool:checkpoint', function(source, cb, index)
    local test = paidTests[source]

    if not checkpointLimiter:consume(source) or not test or test.type == 'dmv'
        or not getTest(source, test.type) then
        return cb(false)
    end

    if type(index) ~= 'number' or index % 1 ~= 0 or index ~= test.checkpoint + 1 then
        return cb(false)
    end

    local checkpoint = Config.CheckPoints[index]
    local ped = GetPlayerPed(source)
    local vehicle = GetVehiclePedIsIn(ped, false)

    if not checkpoint or vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped
        or GetEntityModel(vehicle) ~= joaat(Config.VehicleModels[test.type])
        or (test.vehicle and test.vehicle ~= vehicle) then
        return cb(false)
    end

    local previous = test.checkpoint == 0 and Config.Zones.VehicleSpawnPoint
        or Config.CheckPoints[test.checkpoint]
    local from, to = previous.Pos, checkpoint.Pos
    local distance = #(vector3(to.x, to.y, to.z) - vector3(from.x, from.y, from.z))
    local minimumTravel = math.max(500, distance / 100 * 1000)
    local now = GetGameTimer()

    if now - test.lastCheckpointAt < minimumTravel
        or not isNearPosition(source, checkpoint.Pos, 12.0) then
        return cb(false)
    end

    test.vehicle = vehicle
    test.checkpoint = index
    test.lastCheckpointAt = now
    cb(true)
end)

xLib.callback.registerCompat('esx_dmvschool:finishDrive', function(source, cb, testType)
    local test = isValidTestType(testType) and getTest(source, testType)
    local checkpoint = Config.CheckPoints[#Config.CheckPoints]

    if not limiter:consume(source) or not test or testType == 'dmv'
        or test.checkpoint ~= #Config.CheckPoints
        or not isNearPosition(source, checkpoint.Pos, 35.0) then
        return cb(false)
    end

    grantLicense(source, test, cb)
end)

RegisterNetEvent('esx_dmvschool:cancelTest', function()
    local test = paidTests[source]

    if test and not test.granting then
        paidTests[source] = nil
    end
end)

AddEventHandler('esx:playerLoaded', function(source)
    local player = ESX.GetPlayerFromId(source)

    TriggerEvent('esx_license:getLicenses', source, function(licenses)
        if player and isCurrentPlayer(source, player) then
            TriggerClientEvent('esx_dmvschool:loadLicenses', source, licenses)
        end
    end)
end)

AddEventHandler('esx:playerDropped', function(playerId)
    paidTests[playerId] = nil
end)
