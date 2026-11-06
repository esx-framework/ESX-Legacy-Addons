-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework
local RESOURCE_NAME = GetCurrentResourceName()
local catalog, playerLicenses = {}, {}
local attempt, startRequest, lastResult, schoolBlip, routeBlip, schoolInstructor
local nuiReady, menuOpen, openRequested, stopping = false, false, false, false
local screen, sequence, refreshPending, refreshWaiters = 'closed', 0, false, {}
local abortPractical, completePractical, sendPractical
for _, license in ipairs(Config.Licenses) do
  catalog[license.id] = license
end
local function event(name)
  return RESOURCE_NAME .. ':' .. name
end
local function nativeBoolean(value)
  return value == true or value == 1
end
-- Explicit NUI translation contract; ESX loads and falls back through Translate.
local UI_KEYS = {
  'school_name',
  'school_city',
  'school_label',
  'school_close',
  'school_open',
  'school_center',
  'school_closed_title',
  'school_closed_copy',
  'flow_label',
  'flow_title',
  'flow_complete',
  'flow_theory_passed',
  'flow_start',
  'flow_theory',
  'flow_theory_detail',
  'flow_practical',
  'flow_practical_detail',
  'flow_permit',
  'flow_permit_detail',
  'home_choose',
  'home_count',
  'home_selection',
  'home_theory_name',
  'home_driving_test',
  'home_obtained',
  'home_requires_theory',
  'home_amount',
  'home_approve_first',
  'home_continue',
  'home_locked',
  'home_all_owned',
  'screen_briefing',
  'screen_quiz',
  'screen_result',
  'screen_review',
  'screen_practical',
  'screen_checkpoint',
  'common_back',
  'common_previous',
  'common_next',
  'common_theory',
  'common_practical',
  'common_obtained',
  'license_car',
  'status_passed',
  'status_theory_first',
  'briefing_theory_title',
  'briefing_practical_title',
  'briefing_theory_copy',
  'briefing_practical_copy',
  'briefing_road_training',
  'briefing_question_rule',
  'briefing_review_rule',
  'briefing_pass_rule',
  'briefing_result_rule',
  'briefing_route_rule',
  'briefing_traffic_rule',
  'briefing_speed_rule',
  'briefing_error_rule',
  'briefing_price_rule',
  'briefing_refund_rule',
  'briefing_theory_footer',
  'briefing_practical_footer',
  'briefing_start',
  'quiz_choose',
  'quiz_progress',
  'quiz_one_answer',
  'quiz_pass_rule',
  'quiz_finish',
  'result_label',
  'result_practical_passed',
  'result_theory_passed',
  'result_failed',
  'result_errors',
  'result_correct',
  'result_practical_minimum',
  'result_theory_minimum',
  'result_practical_copy',
  'result_theory_copy',
  'result_failed_copy',
  'result_next_practical',
  'result_review_one',
  'result_review_many',
  'result_home',
  'result_exams',
  'result_licence',
  'review_all_correct',
  'review_none',
  'review_back',
  'review_label',
  'review_title',
  'review_count_one',
  'review_count_many',
  'review_question',
  'review_unanswered',
  'review_your_answer',
  'review_correct_answer',
  'review_error_position',
  'review_score',
  'practical_title',
  'practical_copy',
  'practical_in_progress',
  'practical_limit',
  'practical_route',
  'practical_points',
  'practical_errors',
  'practical_return',
  'practical_next',
  'practical_look',
  'practical_distance',
  'practical_residence',
  'practical_town',
  'practical_freeway',
  'practical_rule',
  'close_in_progress',
  'close_title',
  'close_copy',
  'close_resume',
  'close_exit',
  'notify_choose_elsewhere',
  'notify_theory_owned',
  'notify_theory_required',
  'notify_permit_owned',
  'notify_owned_retry',
  'notify_approve_theory',
  'notify_all_owned',
  'loading',
  'starting',
  'request_failed',
  'invalid_test',
  'test_in_progress',
  'notify_payment_failed',
  'notify_license_pending',
  'result_pending',
  'notify_bank_unavailable',
  'home_available',
  'error_busy',
  'error_invalid_license',
  'error_theory_required',
  'error_already_owned',
  'error_unavailable',
  'error_not_near_school',
  'error_not_enough_money',
  'error_timeout',
  'error_invalid_result',
  'error_invalid_session',
  'license_theory',
  'license_bike',
  'license_truck',
  'briefing_task_rule',
  'briefing_follow_instruction',
  'briefing_manoeuvre_rule',
  'hud_task',
  'hud_errors',
  'hud_distance',
  'hud_speed',
  'hud_hold',
  'hud_position',
  'result_incidents',
  'incident_speeding',
  'incident_damage',
  'incident_abandoned',
  'incident_timeout',
  'incident_death',
  'incident_vehicle_destroyed',
  'incident_server_rejected',
  'incident_spawn_blocked',
  'incident_spawn_failed',
  'incident_unknown',
  'hud_driver',
  'hud_engine',
  'hud_engine_off',
  'hud_fit_park',
  'hud_fit',
  'hud_align',
  'hud_parking_turn_left',
  'hud_parking_turn_right',
  'hud_stop',
  'hud_reverse',
}
local MESSAGE_KEYS = {
  unavailable = true,
  spawn_blocked = true,
  spawn_failed = true,
  speeding = true,
  damage = true,
  abandoned = true,
  timeout = true,
  death = true,
  vehicle_destroyed = true,
  server_rejected = true,
  preparing = true,
  confirming = true,
}
local function message(code)
  return Translate('exam_' .. (MESSAGE_KEYS[code] and code or 'unavailable'))
end
local function hideInteraction(force)
  if ESXDMVInteraction then
    ESXDMVInteraction.Hide(force)
  end
end
local function ownedLicenses()
  local owned = {}
  for id in pairs(catalog) do
    owned[id] = false
  end
  for _, license in pairs(playerLicenses) do
    if type(license) == 'table' and catalog[license.type] then
      owned[license.type] = true
    end
  end
  return owned
end
local function theoryLicense()
  for _, license in ipairs(Config.Licenses) do
    if license.kind == 'theory' then
      return license
    end
  end
end
local function uiData()
  local ui, prices, labels, licenses = {}, {}, {}, {}
  for _, key in ipairs(UI_KEYS) do
    ui[key] = Translate('ui_' .. key)
  end
  local title, theory = Translate(Config.School.title), theoryLicense()
  local locale = Config.Locale
  ui.school_name, labels.driving_school = title, title
  for _, license in ipairs(Config.Licenses) do
    prices[license.id], labels[license.id] = license.price, Translate(license.label)
    licenses[#licenses + 1] = {
      id = license.id,
      kind = license.kind,
      label = Translate(license.label),
      price = license.price,
      icon = license.icon,
      requires = license.requires,
      taskCount = license.route and #(Config.Routes[license.route] or {}) or nil,
    }
  end
  labels.theory_test = theory and Translate(theory.label) or ''
  labels.road_test_car, labels.road_test_bike, labels.road_test_truck =
    labels.drive, labels.drive_bike, labels.drive_truck
  return {
    locale = locale,
    ui = ui,
    labels = labels,
    prices = prices,
    owned = ownedLicenses(),
    licenses = licenses,
    school = { id = Config.School.id, title = title, icon = Config.School.icon },
    theory = theory and {
      id = theory.id,
      bank = theory.bank or Config.School.id,
      questionCount = theory.questionCount,
      answersNeeded = theory.answersNeeded,
    } or nil,
    practical = {
      maxErrors = Config.MaxErrors,
      unit = Config.SpeedUnit,
      checkpoints = attempt and attempt.steps and #attempt.steps or 0,
    },
    currency = '$',
  }
end
local function nearSchool(radius)
  return ESXDMVEvaluation.Distance(GetEntityCoords(PlayerPedId()), Config.School.menu) <= (radius or 20)
end
local function otherSchoolBusy()
  for _, resource in ipairs(Config.SchoolResources or {}) do
    if resource ~= RESOURCE_NAME and GetResourceState(resource) == 'started' then
      local ok, busy = pcall(function()
        return exports[resource]:HasActiveExam()
      end)
      if ok and busy then
        return true
      end
    end
  end
  return false
end
exports('HasActiveExam', function()
  return attempt ~= nil or startRequest ~= nil
end)
local function callback(name, done, ...)
  local finished = false
  local function finish(result)
    if finished then
      return
    end
    finished = true
    done(type(result) == 'table' and result or { ok = false, error = 'unavailable' })
  end
  xLib.callback(event(name), false, finish, ...)
  SetTimeout(10000, function()
    finish({ ok = false, error = 'timeout' })
  end)
end
local function sendLicenses()
  local owned = ownedLicenses()
  if nuiReady then
    xLib.nui.send('dmv:licenses', { owned = owned })
  end
  if lastResult and lastResult.passed and owned[lastResult.license] and not lastResult.confirmed then
    lastResult.confirmed = true
    if nuiReady and screen == 'result' then
      xLib.nui.send('dmv:result', lastResult)
    end
  end
end
local function refreshLicenses(done)
  if done then
    refreshWaiters[#refreshWaiters + 1] = done
  end
  if refreshPending then
    return
  end
  refreshPending = true
  local finished = false
  local function finish(licenses)
    if finished or stopping then
      return
    end
    finished, refreshPending = true, false
    if type(licenses) == 'table' then
      playerLicenses = licenses
    end
    sendLicenses()
    local waiters = refreshWaiters
    refreshWaiters = {}
    for _, waiter in ipairs(waiters) do
      waiter(type(licenses) == 'table')
    end
  end
  xLib.callback(event('getLicenses'), false, finish)
  SetTimeout(8000, function()
    finish(false)
  end)
end
local function removeRoute(keepMarkers)
  if routeBlip and DoesBlipExist(routeBlip) then
    RemoveBlip(routeBlip)
  end
  routeBlip = nil
  if not keepMarkers and ESXDMVMarkers then
    ESXDMVMarkers.Clear()
  end
end
local function cleanupEntities(a, confirmedReturn)
  removeRoute()
  if a.examiner and DoesEntityExist(a.examiner) then
    DeletePed(a.examiner)
  end
  local vehicle = a.vehicle
  a.vehicle, a.examiner = nil, nil
  local ped = PlayerPedId()
  local function release()
    TriggerServerEvent(event('releaseVehicle'), a.session)
  end
  if not vehicle or not DoesEntityExist(vehicle) then
    release()
    if confirmedReturn and not stopping and not IsEntityDead(ped) then
      local p = Config.School.returnPos
      SetEntityCoords(ped, p.x, p.y, p.z, false, false, false, false)
      SetEntityHeading(ped, p.w or 0)
    end
    return
  end
  if confirmedReturn and not IsEntityDead(ped) then
    local p = Config.School.returnPos
    if IsPedInVehicle(ped, vehicle, false) then
      TaskLeaveVehicle(ped, vehicle, 16)
    end
    CreateThread(function()
      local deadline = GetGameTimer() + 1500
      while DoesEntityExist(vehicle) and IsPedInVehicle(ped, vehicle, false) and GetGameTimer() < deadline do
        Wait(25)
      end
      release()
      if not stopping and not IsEntityDead(ped) then
        SetEntityCoords(ped, p.x, p.y, p.z, false, false, false, false)
        SetEntityHeading(ped, p.w or 0)
      end
    end)
  elseif stopping or not IsPedInVehicle(ped, vehicle, false) or IsEntityDead(ped) then
    release()
  else
    TaskLeaveVehicle(ped, vehicle, 16)
    CreateThread(function()
      local deadline = GetGameTimer() + 3000
      while DoesEntityExist(vehicle) and IsPedInVehicle(ped, vehicle, false) and GetGameTimer() < deadline do
        Wait(50)
      end
      release()
    end)
  end
end
local function closeUI()
  hideInteraction()
  menuOpen, openRequested, screen = false, false, 'closed'
  xLib.nui.focus(false, false, false)
  if nuiReady then
    xLib.nui.send('dmv:close', {})
  end
end
local function showResult(result)
  hideInteraction()
  lastResult, screen, menuOpen = result, 'result', true
  if nuiReady then
    xLib.nui.send('dmv:result', result)
  end
  xLib.nui.focus(true, true, false)
end
local function cancelStart()
  if not startRequest then
    return
  end
  local request = startRequest
  startRequest = nil
  TriggerServerEvent(event('cancelTest'), request.license, nil, request.id)
  request.reply({ ok = false, error = 'unavailable' })
end
local function applyServerState(a, response)
  if type(response.errors) == 'number' then
    a.errors = math.max(0, math.floor(response.errors))
  end
  if type(response.incidents) == 'table' then
    a.incidents = {}
    for _, incident in ipairs(response.incidents) do
      local step = a.steps and a.steps[tonumber(incident.index) or tonumber(incident.stage)]
      a.incidents[#a.incidents + 1] = {
        reason = message(incident.reason),
        code = incident.reason,
        stage = step and Translate(step.label) or tostring(incident.stage or ''),
        elapsed = incident.elapsed or 0,
      }
    end
  end
end
local function reportIncident(a, reason)
  if attempt ~= a or a.status ~= 'active' then
    return
  end
  a.lastError = { reason = message(reason), code = reason, time = GetGameTimer() }
  TriggerServerEvent(event('reportIncident'), a.session, reason, a.index)
end
local function spawnClear(license)
  local p = license.spawn
  if not p then
    return false
  end
  local radius = license.dimensions and license.dimensions.length / 2 + 1.5 or 4
  return not IsAnyVehicleNearPoint(p.x, p.y, p.z, math.max(4, radius))
end
local function loadModel(model)
  local hash = type(model) == 'number' and model or joaat(model)
  if not IsModelInCdimage(hash) or not IsModelValid(hash) then
    return nil
  end
  RequestModel(hash)
  local deadline = GetGameTimer() + 5000
  while not HasModelLoaded(hash) and GetGameTimer() < deadline and not stopping do
    Wait(25)
  end
  return HasModelLoaded(hash) and hash or nil
end
local function setRoute(a)
  removeRoute(true)
  local step = a.steps[a.index]
  if ESXDMVMarkers then
    ESXDMVMarkers.SetTarget(step, a.license)
  end
  if not step or step.type == 'engine' then
    return
  end
  routeBlip = AddBlipForCoord(step.pos.x, step.pos.y, step.pos.z)
  SetBlipSprite(routeBlip, 280)
  SetBlipColour(routeBlip, 47)
  SetBlipScale(routeBlip, 0.65)
  SetBlipAsShortRange(routeBlip, false)
  BeginTextCommandSetBlipName('STRING')
  AddTextComponentString(Translate(step.label))
  EndTextCommandSetBlipName(routeBlip)
  SetBlipRoute(routeBlip, true)
  SetBlipRouteColour(routeBlip, 47)
end
local function snapshot(a)
  local vehicle = a.vehicle
  local p = GetEntityCoords(vehicle)
  if a.modelCenter then
    p = GetOffsetFromEntityInWorldCoords(vehicle, a.modelCenter.x, a.modelCenter.y, 0)
  end
  local relative = GetEntitySpeedVector(vehicle, true)
  return {
    x = p.x,
    y = p.y,
    z = p.z,
    heading = GetEntityHeading(vehicle),
    speed = GetEntitySpeed(vehicle) * Config.SpeedMultiplier,
    driving = GetPedInVehicleSeat(vehicle, -1) == PlayerPedId(),
    engine = nativeBoolean(GetIsVehicleEngineRunning(vehicle)),
    vehicleWidth = a.width,
    vehicleLength = a.length,
    forwardSpeed = relative.y,
  }
end
sendPractical = function()
  local a = attempt
  if not nuiReady or not a or a.kind ~= 'practical' or not a.steps then
    return
  end
  local step = a.steps[a.index] or a.steps[#a.steps]
  local current = a.vehicle and DoesEntityExist(a.vehicle) and snapshot(a) or nil
  local routeDistance = (step.type == 'navigate') and ESXDMVMarkers and ESXDMVMarkers.RouteDistance()
  local distance = current and ESXDMVEvaluation.Distance(current, step.pos) or 0
  if current and (step.type == 'park' or step.type == 'stop' or step.type == 'finish') then
    distance = math.sqrt((current.x - step.pos.x) ^ 2 + (current.y - step.pos.y) ^ 2)
  end
  xLib.nui.send('dmv:practical', {
    active = true,
    session = a.session,
    vehicle = a.license.id,
    speed = current and math.floor(current.speed + 0.5) or 0,
    limit = step.limit,
    errors = a.errors,
    checkpoint = math.min(a.index, #a.steps),
    total = #a.steps,
    stage = Translate(step.label),
    instruction = a.status == 'spawning' and message('preparing')
      or a.status == 'finishing' and message('confirming')
      or Translate(step.instruction),
    taskType = step.type,
    distance = math.floor((routeDistance or distance) + 0.5),
    holdProgress = a.holdProgress or 0,
    taskStatus = a.taskStatus,
    parkingHint = current and ESXDMVEvaluation.ParkingHint(step, current, a.taskStatus) or nil,
    maxErrors = Config.MaxErrors,
    unit = Config.SpeedUnit,
    lastError = a.lastError,
    heading = current and math.floor(current.heading) or nil,
  })
end
abortPractical = function(reason, silently)
  local a = attempt
  if not a or a.kind ~= 'practical' or a.status == 'cancelling' then
    return false
  end
  a.status, a.pending = 'cancelling', true
  if reason == 'abandoned' or reason == 'timeout' or reason == 'death' or reason == 'vehicle_destroyed' then
    TriggerServerEvent(event('reportIncident'), a.session, reason, a.index)
  end
  callback('cancelTest', function(response)
    if attempt ~= a then
      return
    end
    applyServerState(a, response)
    attempt = nil
    cleanupEntities(a, response.ok == true and response.cancelled == true)
    if not silently and not stopping then
      showResult({
        kind = 'practical',
        session = a.session,
        passed = false,
        confirmed = response.ok == true,
        errors = a.errors,
        incidents = a.incidents,
        reason = reason,
        license = a.license.id,
      })
    else
      closeUI()
    end
  end, a.license.id, a.session, a.requestId)
  return true
end
completePractical = function(a)
  if attempt ~= a or a.status ~= 'active' then
    return
  end
  a.status, a.pending = 'finishing', true
  sendPractical()
  callback('completePractical', function(response)
    if attempt ~= a then
      return
    end
    applyServerState(a, response)
    if not response.ok or not response.passed or not response.confirmed then
      a.status, a.pending = 'active', false
      if response.error == 'step_not_ready' or response.error == 'not_ready' then
        a.retryAt = GetGameTimer() + 350
        return
      end
      abortPractical(response.error or 'server_rejected')
      return
    end
    attempt = nil
    cleanupEntities(a, true)
    showResult({
      kind = 'practical',
      session = a.session,
      passed = true,
      confirmed = true,
      errors = a.errors,
      incidents = a.incidents,
      license = a.license.id,
    })
    refreshLicenses()
  end, a.session)
end
local function advance(a)
  if a.pending or GetGameTimer() < (a.retryAt or 0) then
    return
  end
  a.pending = true
  local index = a.index
  callback('advancePractical', function(response)
    if attempt ~= a or a.status ~= 'active' or a.index ~= index then
      return
    end
    a.pending = false
    applyServerState(a, response)
    if not response.ok then
      if response.error == 'step_not_ready' or response.error == 'not_ready' then
        a.retryAt = GetGameTimer() + 350
      else
        abortPractical(response.error or 'server_rejected')
      end
      return
    end
    if index == #a.steps then
      completePractical(a)
      return
    end
    a.index, a.tracking, a.holdProgress, a.speedingSince, a.retryAt, a.taskStatus = index + 1, {}, 0, nil, nil, nil
    setRoute(a)
    sendPractical()
  end, a.session, index)
end
local function createExamVehicle(a, ready)
  callback('createVehicle', function(response)
    if attempt ~= a or stopping then
      TriggerServerEvent(event('releaseVehicle'), a.session)
      return
    end
    if not response.ok or type(response.netId) ~= 'number' then
      abortPractical(response.error or 'spawn_failed')
      return
    end
    CreateThread(function()
      local deadline = GetGameTimer() + 8000
      while attempt == a and a.status == 'spawning' and not stopping and GetGameTimer() < deadline do
        local vehicle = NetworkGetEntityFromNetworkId(response.netId)
        if
          vehicle
          and vehicle ~= 0
          and DoesEntityExist(vehicle)
          and GetEntityModel(vehicle) == joaat(a.license.model)
        then
          ready(vehicle)
          return
        end
        Wait(50)
      end
      if attempt == a and a.status == 'spawning' then
        abortPractical('spawn_failed')
      end
    end)
  end, a.session)
end

local function startPractical(a)
  if attempt ~= a then
    return false
  end
  a.status, a.steps, a.index, a.tracking = 'spawning', Config.Routes[a.license.route], 1, {}
  if not spawnClear(a.license) then
    abortPractical('spawn_blocked')
    return false
  end
  screen, menuOpen = 'practical', false
  hideInteraction()
  xLib.nui.focus(false, false, false)
  sendPractical()
  createExamVehicle(a, function(vehicle)
    if attempt ~= a or a.status ~= 'spawning' or stopping then
      TriggerServerEvent(event('releaseVehicle'), a.session)
      return
    end
    if not vehicle or not DoesEntityExist(vehicle) then
      abortPractical('spawn_failed')
      return
    end
    a.vehicle = vehicle
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleNumberPlateText(vehicle, 'EXAM')
    local function prepareFuel()
      SetVehicleFuelLevel(vehicle, 100.0)
      -- ox_fuel reads this state on entry. Keep native/state/decorator coherent.
      if NetworkHasControlOfEntity(vehicle) then
        Entity(vehicle).state:set('fuel', 100.0, true)
      end
      if DecorIsRegisteredAsType('_FUEL_LEVEL', 1) then
        DecorSetFloat(vehicle, '_FUEL_LEVEL', 100.0)
      end
    end
    prepareFuel()
    SetVehicleEngineOn(vehicle, false, true, false)
    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    local minimum, maximum = GetModelDimensions(GetEntityModel(vehicle))
    a.width, a.length = maximum.x - minimum.x, maximum.y - minimum.y
    a.modelCenter = { x = (minimum.x + maximum.x) / 2, y = (minimum.y + maximum.y) / 2 }
    a.health, a.damageAt = GetVehicleBodyHealth(vehicle), GetGameTimer()
    local netId, bindStarted = NetworkGetNetworkIdFromEntity(vehicle), nil
    if netId == 0 then
      abortPractical('spawn_failed')
      return
    end
    SetNetworkIdCanMigrate(netId, true)
    local function bindVehicle()
      if attempt ~= a or a.status ~= 'spawning' then
        return
      end
      bindStarted = bindStarted or GetGameTimer()
      callback('beginPractical', function(response)
        if attempt ~= a or a.status ~= 'spawning' then
          return
        end
        if not response.ok then
          if response.error == 'vehicle_not_ready' and GetGameTimer() - bindStarted < 8000 then
            SetTimeout(350, bindVehicle)
          else
            abortPractical(response.error or 'server_rejected')
          end
          return
        end
        applyServerState(a, response)
        a.status, a.startedAt = 'active', GetGameTimer()
        if GetPedInVehicleSeat(vehicle, -1) ~= PlayerPedId() then
          abortPractical('abandoned')
          return
        end
        prepareFuel()
        SetVehicleUndriveable(vehicle, false)
        -- One request after server binding, never a loop overriding other resources.
        if not nativeBoolean(GetIsVehicleEngineRunning(vehicle)) then
          SetVehicleEngineOn(vehicle, true, false, false)
        end
        if a.license.instructor ~= false then
          CreateThread(function()
            local hash = loadModel(Config.School.instructor)
            if not hash then
              return
            end
            if attempt == a and a.status == 'active' and DoesEntityExist(vehicle) and IsVehicleSeatFree(vehicle, 0) then
              a.examiner = CreatePedInsideVehicle(vehicle, 4, hash, 0, false, false)
              SetBlockingOfNonTemporaryEvents(a.examiner, true)
              SetEntityInvincible(a.examiner, true)
            end
            SetModelAsNoLongerNeeded(hash)
          end)
        end
        setRoute(a)
        sendPractical()
      end, a.session, netId)
    end
    -- Enter the assigned vehicle through the driver's door.
    local ped = PlayerPedId()
    local door = GetOffsetFromEntityInWorldCoords(vehicle, minimum.x - 0.8, a.modelCenter.y, 0)
    SetEntityCoords(ped, door.x, door.y, door.z, false, false, false, false)
    SetEntityHeading(ped, GetEntityHeading(vehicle))
    TaskEnterVehicle(ped, vehicle, 8000, -1, 1.0, 1, 0)
    CreateThread(function()
      local deadline = GetGameTimer() + 8000
      while
        attempt == a
        and a.status == 'spawning'
        and not stopping
        and DoesEntityExist(vehicle)
        and GetPedInVehicleSeat(vehicle, -1) ~= ped
        and not IsEntityDead(ped)
        and GetGameTimer() < deadline
      do
        Wait(100)
      end
      if attempt ~= a or a.status ~= 'spawning' or stopping then
        return
      end
      if IsEntityDead(ped) then
        abortPractical('death')
        return
      end
      if not DoesEntityExist(vehicle) then
        abortPractical('vehicle_destroyed')
        return
      end
      if GetPedInVehicleSeat(vehicle, -1) ~= ped then
        -- If GTA's entry task stalls, preserve the paid attempt with the existing
        -- warp fallback, only into an empty assigned seat beside the player.
        if
          GetPedInVehicleSeat(vehicle, -1) == 0
          and ESXDMVEvaluation.Distance(GetEntityCoords(ped), GetEntityCoords(vehicle)) <= 10
        then
          TaskWarpPedIntoVehicle(ped, vehicle, -1)
        else
          abortPractical('spawn_failed')
          return
        end
      end
      bindVehicle()
    end)
  end)
  SetTimeout(25000, function()
    if attempt == a and a.status == 'spawning' then
      abortPractical('spawn_failed')
    end
  end)
  return true
end
local function startTheory(a)
  hideInteraction()
  screen, menuOpen, a.status = 'theory', true, 'active'
  local data = uiData()
  data.session, data.questionCount, data.answersNeeded = a.session, a.theory.questionCount, a.theory.answersNeeded
  data.questions = a.theory.questions
  data.theory.id, data.theory.bank = a.license.id, a.license.bank or 'road'
  xLib.nui.send('dmv:theory', data)
  xLib.nui.focus(true, true, false)
end
local function cancelTheory(reason)
  local a = attempt
  if not a or a.kind ~= 'theory' then
    return false
  end
  attempt = nil
  TriggerServerEvent(event('cancelTest'), a.license.id, a.session, a.requestId)
  showResult({
    kind = 'theory',
    session = a.session,
    passed = false,
    confirmed = false,
    cancelled = true,
    reason = reason,
    total = a.theory.questionCount,
    license = a.license.id,
  })
  return true
end
function OpenDMVSchoolMenu()
  if stopping or attempt or startRequest or openRequested or not nearSchool() or otherSchoolBusy() then
    return
  end
  openRequested = true
  hideInteraction()
  refreshLicenses(function(ok)
    if not openRequested or not ok or not nuiReady or not nearSchool() then
      openRequested = false
      return
    end
    openRequested, menuOpen, screen, lastResult = false, true, 'home', nil
    xLib.nui.send('dmv:home', uiData())
    xLib.nui.focus(true, true, false)
  end)
end
xLib.nui.register('ready', function()
  nuiReady = true
  xLib.nui.focus(false, false, false)
  refreshLicenses(function()
    if stopping then
      return
    end
    if attempt then
      if attempt.kind == 'theory' then
        startTheory(attempt)
      else
        xLib.nui.send('dmv:home', uiData())
        sendPractical()
      end
    elseif menuOpen then
      xLib.nui.send('dmv:home', uiData())
      if lastResult and screen == 'result' then
        xLib.nui.send('dmv:result', lastResult)
      end
      xLib.nui.focus(true, true, false)
    end
  end)
  return { ok = true }
end)
xLib.nui.register('startTest', function(data, reply)
  local license = catalog[data.license]
  local function reject(reason)
    return { ok = false, error = reason }
  end
  if not license then
    return reject('invalid_license')
  end
  if attempt or startRequest or otherSchoolBusy() then
    return reject('busy')
  end
  if not nuiReady or not menuOpen or screen ~= 'home' then
    return reject('unavailable')
  end
  if not nearSchool() then
    return reject('not_near_school')
  end
  local owned = ownedLicenses()
  if owned[license.id] then
    return reject('already_owned')
  end
  if license.requires and not owned[license.requires] then
    return reject('theory_required')
  end
  if license.kind == 'practical' then
    if not Config.Routes[license.route] or #Config.Routes[license.route] < 5 then
      return reject('unavailable')
    end
    if not spawnClear(license) then
      return reject('spawn_blocked')
    end
  end
  sequence = sequence + 1
  local request = { id = ('%s:%s'):format(GetGameTimer(), sequence), license = license.id, reply = reply }
  startRequest = request
  hideInteraction()
  xLib.callback(event('canYouPay'), false, function(haveMoney, response)
    response = type(response) == 'table' and response or {}
    if startRequest ~= request or stopping then
      if haveMoney then
        TriggerServerEvent(event('cancelTest'), license.id, response.session, request.id)
      end
      return
    end
    startRequest = nil
    if not haveMoney or type(response.session) ~= 'string' then
      reply(reject(response.error or 'unavailable'))
      return
    end
    if
      license.kind == 'theory' and (type(response.theory) ~= 'table' or type(response.theory.questions) ~= 'table')
    then
      TriggerServerEvent(event('cancelTest'), license.id, response.session, request.id)
      reply(reject('unavailable'))
      return
    end
    local a = {
      session = response.session,
      requestId = request.id,
      license = license,
      kind = license.kind,
      createdAt = GetGameTimer(),
      errors = 0,
      incidents = {},
      theory = response.theory,
    }
    attempt, lastResult = a, nil
    if license.kind == 'theory' then
      startTheory(a)
    else
      startPractical(a)
    end
    reply({ ok = true, session = a.session })
  end, license.id, request.id)
  SetTimeout(8000, function()
    if startRequest ~= request then
      return
    end
    startRequest = nil
    TriggerServerEvent(event('cancelTest'), license.id, nil, request.id)
    reply(reject('timeout'))
  end)
  return xLib.nui.defer
end)
xLib.nui.register('theoryResult', function(data, reply)
  if lastResult and lastResult.kind == 'theory' and lastResult.session == data.session then
    return { ok = true, duplicate = true, result = lastResult }
  end
  local a = attempt
  if not a or a.kind ~= 'theory' or data.session ~= a.session then
    return { ok = false, error = 'invalid_session' }
  end
  if a.pending then
    return { ok = false, error = 'busy' }
  end
  if type(data.answers) ~= 'table' then
    return { ok = false, error = 'invalid_result' }
  end
  a.pending = true
  callback('submitTheory', function(response)
    if attempt ~= a or stopping then
      return reply({ ok = false, error = 'invalid_session' })
    end
    a.pending = false
    if response.session ~= a.session or response.kind ~= 'theory' or type(response.score) ~= 'number' then
      return reply({ ok = false, error = response.error or 'unavailable' })
    end
    attempt = nil
    showResult(response)
    if response.passed then
      refreshLicenses()
    end
    reply({ ok = response.ok == true, error = response.error, result = response })
  end, a.session, data.answers)
  return xLib.nui.defer
end)
xLib.nui.register('close', function(data)
  if attempt and data.abandon ~= true then
    return { ok = false, error = 'busy' }
  end
  cancelStart()
  if attempt then
    if attempt.kind == 'theory' then
      cancelTheory('cancelled')
    else
      abortPractical('cancelled', true)
    end
  end
  closeUI()
  return { ok = true }
end)
xLib.nui.register('returnToMenu', function()
  if attempt or startRequest then
    return { ok = false, error = 'busy' }
  end
  if not nearSchool() then
    return { ok = false, error = 'not_near_school' }
  end
  OpenDMVSchoolMenu()
  return { ok = true }
end)
xLib.nui.register('question', function()
  return { ok = attempt ~= nil and attempt.kind == 'theory' }
end)
xLib.nui.register('kick', function()
  if not attempt or attempt.kind ~= 'theory' then
    return { ok = false, error = 'invalid_session' }
  end
  cancelTheory('cancelled')
  return { ok = true }
end)
RegisterNetEvent(event('loadLicenses'), function(licenses)
  if type(licenses) == 'table' then
    playerLicenses = licenses
    sendLicenses()
  end
end)
RegisterNetEvent(event('practicalState'), function(response)
  local a = attempt
  if not a or a.kind ~= 'practical' or type(response) ~= 'table' or response.session ~= a.session then
    return
  end
  local previous = a.errors
  applyServerState(a, response)
  if a.errors > previous then
    local incident = a.incidents[#a.incidents]
    a.lastError = { reason = incident and incident.reason or message('damage'), time = GetGameTimer() }
  end
  if response.failed or response.aborted or a.errors >= Config.MaxErrors then
    abortPractical(response.reason or 'server_rejected')
  end
  sendPractical()
end)
RegisterNetEvent('esx:playerLoaded', function()
  refreshLicenses()
end)
local function resetPlayer()
  hideInteraction()
  cancelStart()
  local a = attempt
  attempt, playerLicenses, lastResult = nil, {}, nil
  if a then
    TriggerServerEvent(event('cancelTest'), a.license.id, a.session, a.requestId)
    cleanupEntities(a, false)
  end
  closeUI()
end
RegisterNetEvent('esx:onPlayerLogout', resetPlayer)
RegisterNetEvent('esx:playerDropped', resetPlayer)
CreateThread(function()
  local p, blip = Config.School.menu, Config.School.blip
  schoolBlip = AddBlipForCoord(p.x, p.y, p.z)
  SetBlipSprite(schoolBlip, blip.sprite)
  SetBlipDisplay(schoolBlip, 4)
  SetBlipColour(schoolBlip, blip.colour or 0)
  SetBlipScale(schoolBlip, blip.scale or 0.8)
  SetBlipAsShortRange(schoolBlip, true)
  BeginTextCommandSetBlipName('STRING')
  AddTextComponentString(Translate(Config.School.title))
  EndTextCommandSetBlipName(schoolBlip)
  local hash = loadModel(Config.School.instructor)
  if hash and not stopping then
    schoolInstructor = CreatePed(4, hash, p.x, p.y, p.z, p.w or 0, false, false)
    SetEntityInvincible(schoolInstructor, true)
    SetBlockingOfNonTemporaryEvents(schoolInstructor, true)
    FreezeEntityPosition(schoolInstructor, true)
    TaskStartScenarioInPlace(schoolInstructor, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    SetModelAsNoLongerNeeded(hash)
  end
  while not ESX.PlayerLoaded and not stopping do
    Wait(500)
  end
  if not stopping then
    refreshLicenses()
  end
end)
CreateThread(function()
  while not stopping do
    local a, now = attempt, GetGameTimer()
    if a and a.kind == 'practical' and a.status == 'active' then
      local ped = PlayerPedId()
      if IsEntityDead(ped) then
        abortPractical('death')
      elseif not a.vehicle or not DoesEntityExist(a.vehicle) or GetEntityHealth(a.vehicle) <= 0 then
        abortPractical('vehicle_destroyed')
      elseif now - a.createdAt >= Config.ExamTimeout then
        abortPractical('timeout')
      else
        local current, step = snapshot(a), a.steps[a.index]
        if not current.driving then
          a.abandonSince = a.abandonSince or now
          a.tracking, a.holdProgress, a.taskStatus = {}, 0, 'driver'
          if now - a.abandonSince >= Config.AbandonTimeout then
            abortPractical('abandoned')
          end
        else
          a.abandonSince = nil
          if a.errors >= Config.MaxErrors then
            abortPractical('server_rejected')
          else
            if a.tracking.lastAt and now - a.tracking.lastAt > 1000 then
              a.tracking = {}
            end
            local passed, progress, detail = ESXDMVEvaluation.Evaluate(step, current, a.tracking, now)
            a.holdProgress, a.taskStatus = progress, detail.reason
            if passed then
              advance(a)
            end
            if step.limit and current.speed > step.limit + Config.SpeedTolerance then
              a.speedingSince = a.speedingSince or now
              if now - a.speedingSince >= Config.SpeedingGrace and now >= (a.speedingNext or 0) then
                reportIncident(a, 'speeding')
                a.speedingNext = now + Config.SpeedingGrace
              end
            else
              a.speedingSince = nil
            end
            local health = GetVehicleBodyHealth(a.vehicle)
            if health < a.health - Config.DamageThreshold and now - a.damageAt >= Config.DamageCooldown then
              reportIncident(a, 'damage')
              a.damageAt, a.health = now, health
            elseif health > a.health then
              a.health = health
            end
          end
        end
      end
    elseif a and a.kind == 'theory' and now - a.createdAt >= Config.ExamTimeout then
      cancelTheory('timeout')
    end
    Wait(100)
  end
end)
CreateThread(function()
  while not stopping do
    if attempt and attempt.kind == 'practical' then
      sendPractical()
    end
    Wait(200)
  end
end)
CreateThread(function()
  while not stopping do
    local sleep, a = 500, attempt
    local canInteract = not a
      and not menuOpen
      and not openRequested
      and not startRequest
      and ESX.PlayerLoaded
      and nearSchool(3.5)
      and not IsNuiFocused()
      and not IsPauseMenuActive()
      and not otherSchoolBusy()
    if canInteract then
      if ESXDMVInteraction then
        ESXDMVInteraction.Show(Translate(Config.School.title))
      end
    else
      hideInteraction()
    end
    if a and a.kind == 'theory' then
      sleep = 0
      DisableControlAction(0, 1, true)
      DisableControlAction(0, 2, true)
      DisablePlayerFiring(PlayerId(), true)
      DisableControlAction(0, 142, true)
    elseif a and a.kind == 'practical' and a.steps and a.steps[a.index] and ESXDMVMarkers then
      if a.vehicle and DoesEntityExist(a.vehicle) and (a.status == 'active' or a.status == 'finishing') then
        sleep = 0
        ESXDMVMarkers.Draw(a.vehicle, a.status, a.holdProgress or 0, a.taskStatus)
      end
    elseif canInteract then
      sleep = 0
      if IsControlJustReleased(0, 38) then
        OpenDMVSchoolMenu()
      end
    end
    if menuOpen and screen == 'home' and not startRequest and not nearSchool() then
      closeUI()
    end
    Wait(sleep)
  end
end)
AddEventHandler('onResourceStop', function(resource)
  if resource ~= RESOURCE_NAME then
    return
  end
  stopping = true
  resetPlayer()
  hideInteraction(true)
  if schoolInstructor and DoesEntityExist(schoolInstructor) then
    DeletePed(schoolInstructor)
  end
  if schoolBlip and DoesBlipExist(schoolBlip) then
    RemoveBlip(schoolBlip)
  end
  xLib.nui.focus(false, false, false)
end)
