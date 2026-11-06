-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local RESOURCE_NAME = GetCurrentResourceName()
local tickets, pendingPayments, pendingGrants, completed = {}, {}, {}, {}
local licenses, catalogReady, stopping, sequence = {}, false, false, 0
local TERMINAL_REASONS = {
  abandoned = true,
  timeout = true,
  death = true,
  vehicle_destroyed = true,
  server_rejected = true,
}
local MOVEMENT_MAX_SPEED = 90.0 -- metres per second
local MOVEMENT_SPEED_MARGIN = 8.0 -- acceleration and velocity replication tolerance, in metres per second
local MOVEMENT_JITTER = 8.0 -- metres that can carry over between updates
local MOVEMENT_RECOVERY_RADIUS = 2.0 -- metres from the last trusted position
local MOVEMENT_CREDIT_WINDOW = 1500 -- milliseconds
local MOVEMENT_HOLD_GAP = 1000 -- milliseconds without an observed sample breaks a continuous hold
local MOVEMENT_REJECTION_TIMEOUT = 5000 -- milliseconds before ending an unresolved invalid movement
local registerCompat = xLib.callback and xLib.callback.registerCompat or ESX.RegisterServerCallback
local requestLimiter = xLib.rateLimiter({ capacity = 16, refill = 6, interval = 1000 })
local requestCost = {
  canYouPay = 4,
  createVehicle = 4,
  submitTheory = 2,
  completePractical = 2,
}

local function allowRequest(playerId, name)
  return type(playerId) == 'number' and playerId > 0 and requestLimiter:consume(playerId, requestCost[name] or 1)
end

local function registerCallback(name, handler)
  registerCompat(RESOURCE_NAME .. ':' .. name, function(playerId, cb, ...)
    if allowRequest(playerId, name) then
      return handler(playerId, cb, ...)
    end
    if name == 'canYouPay' then
      return cb(false, { error = 'busy' })
    end
    if name == 'getLicenses' then
      return cb(false)
    end
    return cb({ ok = false, error = 'busy' })
  end)
end

local function registerRequestEvent(name, handler)
  RegisterNetEvent(RESOURCE_NAME .. ':' .. name, function(...)
    local playerId = source
    if allowRequest(playerId, name) then
      handler(playerId, ...)
    end
  end)
end

if ESXCatalog and ESXCatalog.awaitReady then
  ESXCatalog.awaitReady()
end

for _, license in ipairs(Config.Licenses) do
  assert(
    type(license.id) == 'string' and license.id:match('^[%w_]+$') and #license.id <= 60,
    'Invalid school license ID'
  )
  assert(not licenses[license.id], 'Duplicate school license ID')
  assert(license.kind == 'theory' or license.kind == 'practical', 'Invalid school license kind')
  assert(type(license.price) == 'number' and license.price >= 0 and license.price < math.huge, 'Invalid school price')
  if license.kind == 'practical' then
    assert(
      license.model and license.spawn and Config.Routes[license.route] and #Config.Routes[license.route] >= 5,
      'Practical route requires at least five steps'
    )
  end
  licenses[license.id] = license
end

local function player(playerId, identifier)
  local xPlayer = ESX.Player and ESX.Player(playerId) or ESX.GetPlayerFromId(playerId)
  if not xPlayer or (identifier and xPlayer.getIdentifier() ~= identifier) then
    return nil
  end
  return xPlayer
end

local function distance(a, b)
  return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
end

local function nativeBoolean(value)
  return value == true or value == 1
end

local function near(playerId, position, radius)
  local ped = GetPlayerPed(playerId)
  return ped and ped > 0 and position and distance(GetEntityCoords(ped), position) <= radius
end

local function owns(licenses, licenseId)
  for _, license in pairs(licenses or {}) do
    if license.type == licenseId then
      return true
    end
  end
  return false
end

local function sendLicenses(playerId, identifier, cb)
  if not player(playerId, identifier) then
    if cb then
      cb(false)
    end
    return
  end
  TriggerEvent('esx_license:getLicenses', playerId, function(licenses)
    if not player(playerId, identifier) then
      if cb then
        cb(false)
      end
      return
    end
    if type(licenses) ~= 'table' then
      if cb then
        cb(false)
      end
      return
    end
    TriggerClientEvent(RESOURCE_NAME .. ':loadLicenses', playerId, licenses)
    if cb then
      cb(licenses)
    end
  end)
end

local function active(playerId)
  local ticket = tickets[playerId]
  return pendingPayments[playerId] ~= nil
    or pendingGrants[playerId] ~= nil
    or (ticket ~= nil and ticket.expiresAt >= GetGameTimer())
end

exports('IsExamActive', active)

local function anotherSchoolActive(playerId)
  for _, resource in ipairs(Config.SchoolResources or {}) do
    if resource ~= RESOURCE_NAME and GetResourceState(resource) == 'started' then
      local ok, isActive = pcall(function()
        return exports[resource]:IsExamActive(playerId)
      end)
      if ok and isActive then
        return true
      end
    end
  end
  return false
end

local function state(ticket)
  return {
    session = ticket.session,
    errors = ticket.errors,
    incidents = ticket.incidents,
    index = ticket.index,
    failed = ticket.errors >= Config.MaxErrors,
  }
end

local function pushState(playerId, ticket, reason)
  local data = state(ticket)
  data.reason, data.aborted = reason, reason and TERMINAL_REASONS[reason] == true or false
  TriggerClientEvent(RESOURCE_NAME .. ':practicalState', playerId, data)
end

local function deleteVehicle(ticket)
  if ticket then
    ESXDMVVehicles.Remove(ticket.session)
  end
end

local function remember(playerId, ticket, result)
  result.session, result.errors, result.incidents = ticket.session, ticket.errors, ticket.incidents
  result.kind, result.license = ticket.license.kind, ticket.license.id
  completed[playerId] =
    { identifier = ticket.identifier, expiresAt = GetGameTimer() + 60000, result = result, ticket = ticket }
  return result
end

local function previousResult(playerId, session)
  local previous = completed[playerId]
  if
    previous
    and previous.result.session == session
    and previous.expiresAt >= GetGameTimer()
    and player(playerId, previous.identifier)
  then
    return previous.result
  end
end

local function incident(playerId, ticket, reason)
  local now = GetGameTimer()
  if reason == 'damage' and now - (ticket.lastDamageAt or -100000) < (Config.DamageCooldown or 2000) then
    return
  end
  if reason == 'damage' then
    ticket.lastDamageAt = now
  end
  local step = ticket.route and ticket.route[math.min(ticket.index, #ticket.route)]
  ticket.incidents[#ticket.incidents + 1] =
    { reason = reason, stage = step and Translate(step.label) or '', elapsed = now - ticket.startedAt }
  if reason == 'damage' or reason == 'speeding' then
    ticket.errors = ticket.errors + 1
  end
  pushState(playerId, ticket, reason)
end

local function abort(playerId, ticket, reason)
  if tickets[playerId] ~= ticket then
    return
  end
  incident(playerId, ticket, reason)
  tickets[playerId] = nil
  deleteVehicle(ticket)
  remember(playerId, ticket, { ok = true, passed = false, confirmed = false, cancelled = true, reason = reason })
end

local function getTicket(playerId, session, practical)
  local ticket = tickets[playerId]
  if
    type(session) ~= 'string'
    or not ticket
    or ticket.session ~= session
    or not player(playerId, ticket.identifier)
  then
    return nil, 'invalid_session'
  end
  if ticket.expiresAt < GetGameTimer() then
    abort(playerId, ticket, 'timeout')
    return nil, 'timeout'
  end
  if practical and ticket.license.kind ~= 'practical' then
    return nil, 'invalid_license'
  end
  return ticket
end

local function finite(value)
  return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end

local function finiteVector(vector)
  return vector and finite(vector.x) and finite(vector.y) and finite(vector.z)
end

local function snapshot(playerId, ticket)
  local ped, vehicle = GetPlayerPed(playerId), ticket.vehicle
  if not ped or ped <= 0 or GetEntityHealth(ped) <= 0 then
    return nil, 'death'
  end
  if not vehicle or not DoesEntityExist(vehicle) or NetworkGetEntityFromNetworkId(ticket.netId) ~= vehicle then
    return nil, 'vehicle_destroyed'
  end
  if not ESXDMVVehicles.Matches(ticket.session, playerId, ticket.netId) then
    return nil, 'vehicle_destroyed'
  end
  if GetEntityModel(vehicle) ~= joaat(ticket.license.model) then
    return nil, 'invalid_vehicle'
  end
  if GetVehiclePedIsIn(ped, false) ~= vehicle or GetPedInVehicleSeat(vehicle, -1) ~= ped then
    return nil, 'not_driver'
  end
  local pos, heading, velocity = GetEntityCoords(vehicle), GetEntityHeading(vehicle), GetEntityVelocity(vehicle)
  if not finiteVector(pos) or not finite(heading) or not finiteVector(velocity) then
    return nil, 'invalid_movement'
  end
  local speed = math.sqrt(velocity.x ^ 2 + velocity.y ^ 2 + velocity.z ^ 2)
  if speed > MOVEMENT_MAX_SPEED then
    return nil, 'invalid_movement'
  end
  local dimensions = ticket.license.dimensions or { width = 2.5, length = 5.0 }
  local radians = math.rad(heading)
  return {
    x = pos.x,
    y = pos.y,
    z = pos.z,
    heading = heading,
    speed = speed * Config.SpeedMultiplier,
    speedMps = speed,
    driving = true,
    engine = nativeBoolean(GetIsVehicleEngineRunning(vehicle)),
    vehicleWidth = dimensions.width,
    vehicleLength = dimensions.length,
    footprintOffset = dimensions.offset,
    forwardSpeed = -math.sin(radians) * velocity.x + math.cos(radians) * velocity.y,
  }
end

local function resetTracking(ticket)
  ticket.tracking, ticket.ready = {}, false
  if ticket.lastTracking then
    ticket.lastTracking = {}
  end
end

local function verifyMovement(ticket, data, now)
  local movement = ticket.movement
  if not movement then
    ticket.movement = { position = data, sampledAt = now, allowance = MOVEMENT_JITTER }
    return true
  end

  local elapsed = math.max(0, now - movement.sampledAt)
  local travelled = distance(movement.position, data)
  local allowance = movement.allowance
  if movement.interrupted then
    -- A missing driver or rejected position cannot establish a new baseline at a checkpoint.
    if travelled > math.min(allowance, MOVEMENT_RECOVERY_RADIUS) then
      return false
    end
  else
    local speed = math.max(movement.position.speedMps, data.speedMps) + MOVEMENT_SPEED_MARGIN
    allowance = allowance + math.min(elapsed, MOVEMENT_CREDIT_WINDOW) / 1000 * math.min(speed, MOVEMENT_MAX_SPEED)
    if travelled > allowance then
      return false
    end
  end

  if elapsed > MOVEMENT_HOLD_GAP then
    resetTracking(ticket)
  end
  movement.position, movement.sampledAt = data, now
  movement.allowance = math.min(MOVEMENT_JITTER, allowance - travelled)
  movement.interrupted, movement.invalidSince = nil, nil
  return true
end

local function sample(playerId, ticket)
  if not player(playerId, ticket.identifier) then
    return abort(playerId, ticket, 'abandoned')
  end
  if GetGameTimer() > ticket.expiresAt then
    return abort(playerId, ticket, 'timeout')
  end
  if not ticket.vehicle then
    return
  end
  local step = ticket.route[math.min(ticket.index, #ticket.route)]
  local now = GetGameTimer()
  local data, errorCode = snapshot(playerId, ticket)
  if data then
    ticket.leftAt = nil
    if not verifyMovement(ticket, data, now) then
      data, errorCode = nil, 'invalid_movement'
    end
  end
  if not data then
    resetTracking(ticket)
    if errorCode == 'death' or errorCode == 'vehicle_destroyed' then
      return abort(playerId, ticket, errorCode)
    end
    local movement = ticket.movement
    if movement then
      movement.sampledAt, movement.interrupted = now, true
      if errorCode == 'invalid_movement' then
        movement.invalidSince = movement.invalidSince or now
      end
      if movement.invalidSince and now - movement.invalidSince >= MOVEMENT_REJECTION_TIMEOUT then
        return abort(playerId, ticket, 'server_rejected')
      end
    end
    if errorCode == 'not_driver' then
      ticket.leftAt = ticket.leftAt or now
      if now - ticket.leftAt >= (Config.AbandonTimeout or 20000) then
        abort(playerId, ticket, 'abandoned')
      end
    end
    return
  end
  local health = GetVehicleBodyHealth(ticket.vehicle)
  if health <= 0 or GetVehicleEngineHealth(ticket.vehicle) <= -4000 then
    return abort(playerId, ticket, 'vehicle_destroyed')
  end
  local damageCooling = GetGameTimer() - (ticket.lastDamageAt or -100000) < (Config.DamageCooldown or 2000)
  if not ticket.lastHealth or health > ticket.lastHealth or damageCooling then
    ticket.lastHealth = health
  elseif ticket.lastHealth - health >= (Config.DamageThreshold or 20) then
    incident(playerId, ticket, 'damage')
    ticket.lastHealth = health
  end
  local limit = step.limit
  if limit and data.speed > limit + (Config.SpeedTolerance or 5) then
    ticket.speedingSince = ticket.speedingSince or GetGameTimer()
    if not ticket.speedingReported and GetGameTimer() - ticket.speedingSince >= (Config.SpeedingGrace or 2500) then
      ticket.speedingReported = true
      incident(playerId, ticket, 'speeding')
    end
  else
    ticket.speedingSince, ticket.speedingReported = nil, false
  end
  if ticket.index <= #ticket.route then
    ticket.ready = ESXDMVEvaluation.Evaluate(step, data, ticket.tracking, GetGameTimer())
  else
    ESXDMVEvaluation.Evaluate(step, data, ticket.lastTracking or {}, GetGameTimer())
  end
  return data
end

registerCallback('getLicenses', function(playerId, cb)
  local xPlayer = player(playerId)
  if not xPlayer then
    return cb(false)
  end
  sendLicenses(playerId, xPlayer.getIdentifier(), cb)
end)

registerCallback('canYouPay', function(playerId, cb, licenseId, requestId)
  local xPlayer, license = player(playerId), licenses[licenseId]
  local function reject(reason)
    cb(false, { error = reason })
  end
  if not catalogReady or not xPlayer then
    return reject('unavailable')
  end
  if not license then
    return reject('invalid_license')
  end
  if not near(playerId, Config.School.menu, 20.0) then
    return reject('not_near_school')
  end
  local previous = tickets[playerId]
  if previous and previous.expiresAt < GetGameTimer() then
    abort(playerId, previous, 'timeout')
  end
  if active(playerId) or anotherSchoolActive(playerId) then
    return reject('busy')
  end
  if type(requestId) ~= 'string' or #requestId > 96 or #requestId < 1 then
    return reject('invalid_session')
  end

  local pending = { identifier = xPlayer.getIdentifier(), requestId = requestId, licenseId = licenseId }
  pendingPayments[playerId] = pending
  local function finish(ok, response)
    if pendingPayments[playerId] ~= pending then
      return
    end
    pendingPayments[playerId] = nil
    cb(ok, response)
  end
  pending.cancel = function()
    finish(false, { error = 'unavailable' })
  end
  SetTimeout(7000, function()
    finish(false, { error = 'timeout' })
  end)
  TriggerEvent('esx_license:getLicenses', playerId, function(owned)
    if pendingPayments[playerId] ~= pending then
      return
    end
    local currentPlayer = player(playerId, pending.identifier)
    if not currentPlayer then
      return finish(false, { error = 'unavailable' })
    end
    if not near(playerId, Config.School.menu, 20.0) then
      return finish(false, { error = 'not_near_school' })
    end
    if anotherSchoolActive(playerId) then
      return finish(false, { error = 'busy' })
    end
    if type(owned) ~= 'table' then
      return finish(false, { error = 'unavailable' })
    end
    if owns(owned, licenseId) then
      return finish(false, { error = 'already_owned' })
    end
    if license.requires and not owns(owned, license.requires) then
      return finish(false, { error = 'theory_required' })
    end
    if currentPlayer.getMoney() < license.price then
      return finish(false, { error = 'not_enough_money' })
    end

    local theory, theoryError
    if license.kind == 'theory' then
      theory, theoryError = ESXDMVTheory.Create(license, Config.Locale)
      if not theory then
        return finish(false, { error = theoryError or 'unavailable' })
      end
    end

    sequence = sequence + 1
    local session = ('%s:%s:%s:%s'):format(RESOURCE_NAME, playerId, GetGameTimer(), sequence)
    currentPlayer.removeMoney(license.price, 'School exam purchase')
    if completed[playerId] then
      deleteVehicle(completed[playerId].ticket)
    end
    completed[playerId] = nil
    tickets[playerId] = {
      license = license,
      identifier = pending.identifier,
      session = session,
      requestId = requestId,
      startedAt = GetGameTimer(),
      expiresAt = GetGameTimer() + (Config.ExamTimeout or 1200000),
      errors = 0,
      incidents = {},
      index = 1,
      tracking = {},
      route = license.kind == 'practical' and Config.Routes[license.route] or nil,
      theory = theory,
    }
    local response = { session = session }
    if theory then
      response.theory = {
        questions = theory.publicQuestions,
        questionCount = theory.total,
        answersNeeded = theory.needed,
        locale = theory.locale,
      }
    end
    finish(true, response)
  end)
end)

registerCallback('createVehicle', function(playerId, cb, session)
  local ticket, errorCode = getTicket(playerId, session, true)
  if not ticket then
    return cb({ ok = false, error = errorCode })
  end
  if not near(playerId, Config.School.menu, 30.0) then
    return cb({ ok = false, error = 'not_near_school' })
  end
  ESXDMVVehicles.Create(playerId, ticket.license, ticket.session, function(netId, entityOrError)
    if stopping or tickets[playerId] ~= ticket or not player(playerId, ticket.identifier) then
      ESXDMVVehicles.Remove(ticket.session)
      return cb({ ok = false, error = 'invalid_session' })
    end
    if not netId then
      return cb({ ok = false, error = entityOrError or 'spawn_failed' })
    end
    cb({ ok = true, netId = netId })
  end)
end)

registerCallback('beginPractical', function(playerId, cb, session, netId)
  local ticket, errorCode = getTicket(playerId, session, true)
  if not ticket then
    return cb({ ok = false, error = errorCode })
  end
  if type(netId) ~= 'number' or netId ~= math.floor(netId) or netId <= 0 or netId >= 2147483647 then
    return cb({ ok = false, error = 'invalid_vehicle' })
  end
  local assigned, assignedVehicle = ESXDMVVehicles.Matches(ticket.session, playerId, netId)
  if not assigned then
    return cb({ ok = false, error = 'invalid_vehicle' })
  end
  if ticket.netId then
    local result = state(ticket)
    result.ok, result.duplicate = ticket.netId == netId, true
    result.error = not result.ok and 'invalid_vehicle' or nil
    return cb(result)
  end
  local entity, ped = assignedVehicle, GetPlayerPed(playerId)
  if not entity or entity == 0 or not DoesEntityExist(entity) then
    return cb({ ok = false, error = 'vehicle_not_ready' })
  end
  if GetEntityType(entity) ~= 2 or GetEntityModel(entity) ~= joaat(ticket.license.model) then
    return cb({ ok = false, error = 'invalid_vehicle' })
  end
  local position = GetEntityCoords(entity)
  if not finiteVector(position) or distance(position, ticket.license.spawn) > 25.0 then
    return cb({ ok = false, error = 'invalid_vehicle' })
  end
  if GetVehiclePedIsIn(ped, false) ~= entity or GetPedInVehicleSeat(entity, -1) ~= ped then
    return cb({ ok = false, error = 'vehicle_not_ready' })
  end
  ticket.netId, ticket.vehicle, ticket.lastHealth = netId, entity, GetVehicleBodyHealth(entity)
  if not sample(playerId, ticket) then
    ticket.netId, ticket.vehicle, ticket.lastHealth = nil, nil, nil
    return cb({ ok = false, error = tickets[playerId] == ticket and 'vehicle_not_ready' or 'invalid_session' })
  end
  local result = state(ticket)
  result.ok = true
  cb(result)
end)

registerCallback('advancePractical', function(playerId, cb, session, index)
  local ticket, errorCode = getTicket(playerId, session, true)
  if not ticket then
    return cb({ ok = false, error = errorCode })
  end
  if not ticket.vehicle then
    return cb({ ok = false, error = 'invalid_vehicle' })
  end
  if type(index) ~= 'number' or index ~= math.floor(index) or index < 1 or index > #ticket.route then
    return cb({ ok = false, error = 'invalid_step' })
  end
  if index < ticket.index then
    sample(playerId, ticket)
    if tickets[playerId] ~= ticket then
      return cb({ ok = false, error = 'invalid_session' })
    end
    local result = state(ticket)
    result.ok, result.duplicate = true, true
    return cb(result)
  end
  if index ~= ticket.index then
    return cb({ ok = false, error = 'invalid_step' })
  end
  local data = sample(playerId, ticket)
  if tickets[playerId] ~= ticket then
    return cb({ ok = false, error = 'invalid_session' })
  end
  if not data or not ticket.ready then
    return cb({ ok = false, error = 'step_not_ready', errors = ticket.errors, incidents = ticket.incidents })
  end
  ticket.lastTracking, ticket.tracking = ticket.tracking, { lastAt = GetGameTimer() }
  ticket.index, ticket.ready = ticket.index + 1, false
  local result = state(ticket)
  result.ok = true
  cb(result)
end)

local function grant(playerId, ticket, cb)
  if pendingGrants[playerId] then
    return cb({ ok = false, error = 'busy' })
  end
  tickets[playerId] = nil
  pendingGrants[playerId] = ticket
  ticket.grantWaiters = { cb }
  local finished = false
  local function finish(confirmed)
    if finished then
      return
    end
    finished = true
    local matchingGrant = pendingGrants[playerId] == ticket
    if matchingGrant then
      pendingGrants[playerId] = nil
    end
    if stopping or not matchingGrant or not player(playerId, ticket.identifier) then
      deleteVehicle(ticket)
      for _, reply in ipairs(ticket.grantWaiters) do
        reply({ ok = false, error = 'invalid_session' })
      end
      return
    end
    local result =
      remember(playerId, ticket, { ok = confirmed == true, passed = confirmed == true, confirmed = confirmed == true })
    if ticket.theoryResult then
      result.score, result.total = ticket.theoryResult.score, ticket.theoryResult.total
      result.correctAnswers = ticket.theoryResult.correctAnswers
      result.passed = ticket.theoryResult.passed
    end
    if not confirmed then
      result.error = 'unavailable'
    end
    SetTimeout(10000, function()
      deleteVehicle(ticket)
    end)
    for _, reply in ipairs(ticket.grantWaiters) do
      reply(result)
    end
  end
  SetTimeout(8000, function()
    finish(false)
  end)
  TriggerEvent('esx_license:addLicense', playerId, ticket.license.id, function()
    sendLicenses(playerId, ticket.identifier, function(licenses)
      finish(type(licenses) == 'table' and owns(licenses, ticket.license.id))
    end)
  end)
end

registerCallback('submitTheory', function(playerId, cb, session, answers)
  local previous = previousResult(playerId, session)
  if previous then
    return cb(previous.kind == 'theory' and previous or { ok = false, error = 'invalid_license' })
  end
  local pending = pendingGrants[playerId]
  if
    pending
    and pending.session == session
    and pending.license.kind == 'theory'
    and player(playerId, pending.identifier)
  then
    pending.grantWaiters[#pending.grantWaiters + 1] = cb
    return
  end
  local ticket, errorCode = getTicket(playerId, session)
  if not ticket then
    return cb({ ok = false, error = errorCode })
  end
  if ticket.license.kind ~= 'theory' then
    return cb({ ok = false, error = 'invalid_license' })
  end
  if not near(playerId, Config.School.menu, 20.0) then
    return cb({ ok = false, error = 'not_near_school' })
  end
  local graded, gradeError = ESXDMVTheory.Grade(ticket.theory, answers)
  if not graded then
    return cb({ ok = false, error = gradeError })
  end
  ticket.errors, ticket.theoryResult, ticket.theory = graded.total - graded.score, graded, nil
  if graded.passed then
    return grant(playerId, ticket, cb)
  end
  tickets[playerId] = nil
  cb(remember(playerId, ticket, {
    ok = true,
    passed = false,
    confirmed = false,
    score = graded.score,
    total = graded.total,
    correctAnswers = graded.correctAnswers,
  }))
end)

registerCallback('completePractical', function(playerId, cb, session)
  local previous = previousResult(playerId, session)
  if previous then
    return cb(previous.kind == 'practical' and previous or { ok = false, error = 'invalid_license' })
  end
  local pending = pendingGrants[playerId]
  if
    pending
    and pending.session == session
    and pending.license.kind == 'practical'
    and player(playerId, pending.identifier)
  then
    pending.grantWaiters[#pending.grantWaiters + 1] = cb
    return
  end
  local ticket, errorCode = getTicket(playerId, session, true)
  if not ticket then
    return cb({ ok = false, error = errorCode })
  end
  if ticket.index <= #ticket.route then
    return cb({ ok = false, error = 'incomplete_route' })
  end
  local step = ticket.route[#ticket.route]
  local data = sample(playerId, ticket)
  if tickets[playerId] ~= ticket then
    return cb(previousResult(playerId, session) or { ok = false, error = 'invalid_session' })
  end
  local passed = data and ESXDMVEvaluation.Evaluate(step, data, ticket.lastTracking or {}, GetGameTimer())
  if not passed then
    return cb({ ok = false, error = 'step_not_ready' })
  end
  if ticket.errors >= Config.MaxErrors then
    tickets[playerId] = nil
    deleteVehicle(ticket)
    return cb(remember(playerId, ticket, { ok = true, passed = false, confirmed = false }))
  end
  grant(playerId, ticket, cb)
end)

local function cancel(playerId, licenseId, session, requestId)
  local pending = pendingPayments[playerId]
  local pendingCancelled = pending and pending.licenseId == licenseId and requestId and pending.requestId == requestId
  if pendingCancelled then
    pending.cancel()
  end
  local ticket = tickets[playerId]
  if
    ticket
    and ticket.license.id == licenseId
    and ((session and ticket.session == session) or (requestId and ticket.requestId == requestId))
  then
    tickets[playerId] = nil
    deleteVehicle(ticket)
    return remember(playerId, ticket, { ok = true, cancelled = true, passed = false, confirmed = false })
  end
  local previous = previousResult(playerId, session)
  if previous then
    return previous
  end
  if pendingCancelled then
    return { ok = true, cancelled = true, passed = false, confirmed = false }
  end
  return { ok = false, error = 'invalid_session' }
end

registerCallback('cancelTest', function(playerId, cb, licenseId, session, requestId)
  cb(cancel(playerId, licenseId, session, requestId))
end)
registerRequestEvent('cancelTest', cancel)

local function reportIncident(playerId, session, reason, index)
  local ticket, errorCode = getTicket(playerId, session, true)
  if not ticket then
    local previous = previousResult(playerId, session)
    return previous or { ok = false, error = errorCode }
  end
  if not (TERMINAL_REASONS[reason] or reason == 'speeding' or reason == 'damage') or index ~= ticket.index then
    return { ok = false, error = 'invalid_incident' }
  end
  -- Reports prompt an independent sample; they never trust a client error count.
  sample(playerId, ticket)
  local result = state(ticket)
  result.ok = true
  return result
end
registerCallback('reportIncident', function(playerId, cb, session, reason, index)
  cb(reportIncident(playerId, session, reason, index))
end)
registerRequestEvent('reportIncident', reportIncident)

registerRequestEvent('releaseVehicle', function(playerId, session)
  local previous = completed[playerId]
  if previous and previous.result.session == session and player(playerId, previous.identifier) then
    deleteVehicle(previous.ticket)
  end
end)

local function clearPlayer(playerId)
  local ticket = tickets[playerId] or pendingGrants[playerId] or (completed[playerId] and completed[playerId].ticket)
  if ticket then
    deleteVehicle(ticket)
  end
  tickets[playerId], completed[playerId], pendingGrants[playerId] = nil, nil, nil
  if pendingPayments[playerId] then
    pendingPayments[playerId].cancel()
  end
end
AddEventHandler('esx:playerDropped', clearPlayer)
AddEventHandler('esx:playerLogout', clearPlayer)
AddEventHandler('playerDropped', function()
  local playerId = source
  requestLimiter:reset(playerId)
  clearPlayer(playerId)
end)
AddEventHandler('esx:playerLoaded', function(playerId)
  clearPlayer(playerId)
  local xPlayer = player(playerId)
  if xPlayer then
    sendLicenses(playerId, xPlayer.getIdentifier())
  end
end)
AddEventHandler('onResourceStop', function(resource)
  if resource ~= RESOURCE_NAME then
    return
  end
  stopping = true
  for playerId in pairs(tickets) do
    clearPlayer(playerId)
  end
  for playerId in pairs(pendingPayments) do
    clearPlayer(playerId)
  end
  for playerId in pairs(pendingGrants) do
    clearPlayer(playerId)
  end
  for playerId in pairs(completed) do
    clearPlayer(playerId)
  end
end)

CreateThread(function()
  MySQL.ready(function()
    if stopping then
      return
    end
    for _, license in ipairs(Config.Licenses) do
      MySQL.query.await(
        'INSERT IGNORE INTO licenses (type, label) VALUES (?, ?)',
        { license.id, Translate(license.label) }
      )
    end
    while not stopping and not catalogReady do
      TriggerEvent('esx:sqlCatalogReady', { licenses = true })
      TriggerEvent('esx_license:getLicensesList', function(catalog)
        local found = {}
        for _, license in pairs(catalog or {}) do
          found[license.type] = true
        end
        catalogReady = true
        for id in pairs(licenses) do
          if not found[id] then
            catalogReady = false
            break
          end
        end
      end)
      if not catalogReady then
        Wait(1000)
      end
    end
    if catalogReady then
      print(('[%s] License catalog ready.'):format(RESOURCE_NAME))
    end
  end)
end)

CreateThread(function()
  while not stopping do
    for playerId, ticket in pairs(tickets) do
      sample(playerId, ticket)
    end
    Wait(200)
  end
end)
