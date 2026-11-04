-- Native/UI/callback fixtures only. This file is not loaded by the manifest.
local checks = 0
local function check(value, label)
  checks = checks + 1
  assert(value, label)
end
local function fixture()
  local w = {
    time = 0,
    tasks = {},
    messages = {},
    events = {},
    registrations = {},
    nui = {},
    callbacks = {},
    playerPos = Config.School.menu,
    pos = { x = 0, y = 0, z = 0 },
    heading = 0,
    exists = false,
    inside = false,
    engine = false,
    speed = 0,
    forward = 0,
    body = 1000,
    licenses = { { type = 'dmv' } },
    paid = 0,
    spawned = 0,
    deleted = 0,
    returned = 0,
    began = 0,
    advanced = {},
    completed = 0,
    cancelled = 0,
    errors = 0,
    beginNotReady = 0,
    numericBooleans = true,
    tickets = {},
    theoryResults = {},
    submissions = 0,
    grades = 0,
    stateWrites = 0,
  }
  local env = setmetatable(
    { Config = Config, ESXDMVEvaluation = ESXDMVEvaluation, ESX = { PlayerLoaded = true } },
    { __index = _G }
  )
  local selected = assert(load(LocaleSources[Config.Locale] or LocaleSources.en))()
  local english = assert(load(LocaleSources.en))()
  env.Translate = function(key, ...)
    return string.format(selected[key] or english[key] or key, ...)
  end
  env.ESXDMVInteraction = {
    Show = function()
      w.interactionVisible = true
    end,
    Hide = function(force)
      w.interactionVisible = false
      w.interactionDisposed = force == true
    end,
  }
  local function queue(fn, at)
    w.tasks[#w.tasks + 1] = { co = coroutine.create(fn), at = at or w.time }
  end
  function w.run(ms)
    local untilTime, iterations = w.time + ms, 0
    while true do
      local selected
      for i, task in ipairs(w.tasks) do
        if task.at <= untilTime and (not selected or task.at < w.tasks[selected].at) then
          selected = i
        end
      end
      if not selected then
        break
      end
      local task = table.remove(w.tasks, selected)
      w.time = task.at
      local ok, delay = coroutine.resume(task.co)
      assert(ok, delay)
      if coroutine.status(task.co) ~= 'dead' then
        task.at = w.time + math.max(tonumber(delay) or 1, 1)
        w.tasks[#w.tasks + 1] = task
      end
      iterations = iterations + 1
      assert(iterations < 500000, 'fixture scheduler runaway')
    end
    w.time = untilTime
  end
  function w.last(action)
    for i = #w.messages, 1, -1 do
      if w.messages[i].action == action then
        return w.messages[i].data
      end
    end
  end
  env.GetCurrentResourceName = function()
    return 'esx_dmvschool'
  end
  env.GetGameTimer = function()
    return w.time
  end
  env.CreateThread = function(fn)
    queue(fn)
  end
  env.SetTimeout = function(ms, fn)
    queue(fn, w.time + ms)
  end
  env.Wait = function(ms)
    return coroutine.yield(ms)
  end
  env.PlayerPedId, env.PlayerId = function()
    return 1
  end, function()
    return 0
  end
  env.GetResourceState = function()
    return 'stopped'
  end
  env.IsNuiFocused = function()
    return w.focus and w.focus[1] or false
  end
  env.IsPauseMenuActive = function()
    return w.paused == true
  end
  env.exports = setmetatable({}, {
    __call = function(_, name, fn)
      w.registrations[name] = fn
    end,
  })
  env.vector3 = function(x, y, z)
    return { x = x, y = y, z = z }
  end
  env.GetEntityCoords = function(entity)
    if entity == 1 and not w.inside then
      return w.playerPos
    end
    return w.pos
  end
  env.GetEntityHeading = function()
    return w.heading
  end
  env.GetEntityModel = function()
    return w.model
  end
  env.GetEntityHealth = function(entity)
    return entity == 1 and (w.dead and 0 or 200) or 1000
  end
  env.DoesEntityExist = function(entity)
    return entity ~= 100 or w.exists
  end
  env.IsEntityDead = function(entity)
    return entity == 1 and w.dead == true
  end
  env.IsPedInVehicle = function(_, vehicle)
    return vehicle == 100 and w.inside
  end
  env.GetPedInVehicleSeat = function(_, seat)
    return seat == -1 and w.inside and 1 or 0
  end
  env.IsVehicleSeatFree = function()
    return true
  end
  local function nativeBool(value)
    if w.numericBooleans then
      return value and 1 or 0
    end
    return value
  end
  env.GetIsVehicleEngineRunning = function()
    return nativeBool(w.engine)
  end
  env.GetVehicleBodyHealth = function()
    return w.body
  end
  env.GetEntitySpeed = function()
    return w.speed
  end
  env.GetEntityVelocity = function()
    return { x = -math.sin(math.rad(w.heading)) * w.forward, y = math.cos(math.rad(w.heading)) * w.forward, z = 0 }
  end
  env.GetEntitySpeedVector = function()
    return { x = 0, y = w.forward, z = 0 }
  end
  env.IsEntityInAir = function()
    return nativeBool(false)
  end
  env.IsVehicleOnAllWheels = function()
    return nativeBool(true)
  end
  env.IsAnyVehicleNearPoint = function()
    return w.blocked == true
  end
  env.GetModelDimensions = function()
    if w.model == 'mule3' then
      w.modelCenterY = -0.21931338310241
      return { x = -1.35928034782409, y = -4.2580542564392, z = -1.25547444820404 }, {
        x = 1.35928106307983,
        y = 3.81942749023437,
        z = 2.49432110786438,
      }
    end
    return { x = -1, y = -1.6, z = -0.5 }, { x = 1, y = 2.4, z = 1 }
  end
  env.GetOffsetFromEntityInWorldCoords = function(_, x, y, z)
    local h = math.rad(w.heading)
    return {
      x = w.pos.x + x * math.cos(h) - y * math.sin(h),
      y = w.pos.y + x * math.sin(h) + y * math.cos(h),
      z = w.pos.z + z,
    }
  end
  env.GetGroundZFor_3dCoord = function(_, _, z)
    return true, z - 20
  end
  env.TaskWarpPedIntoVehicle = function()
    w.inside = true
  end
  env.TaskEnterVehicle = function(_, _, _, _, _, flag)
    w.entryFlag, w.entryFuel, w.entryDecorator, w.entryState = flag, w.fuel, w.decoratorFuel, w.stateFuel
    w.entryRequests = (w.entryRequests or 0) + 1
    if not w.stallEntry then
      queue(function()
        w.inside = true
      end, w.time + 50)
    end
  end
  env.TaskLeaveVehicle = function()
    w.inside = false
  end
  env.SetVehicleEngineOn = function(_, value, _, disableAutoStart)
    w.engine, w.autoStartDisabled = value, disableAutoStart
    if value then
      w.engineStarts = (w.engineStarts or 0) + 1
      w.startedBeforeBind = not w.bound or not w.inside
    end
  end
  env.SetVehicleFuelLevel = function(_, value)
    w.fuel = value
  end
  env.Entity = function()
    return {
      state = {
        set = function(_, key, value)
          if key == 'fuel' then
            w.stateFuel = value
            w.stateWrites = w.stateWrites + 1
          end
        end,
      },
    }
  end
  env.DecorIsRegisteredAsType = function()
    return w.decorRegistered ~= false
  end
  env.DecorSetFloat = function(_, key, value)
    if key == '_FUEL_LEVEL' then
      w.decoratorFuel = value
    end
  end
  env.SetVehicleUndriveable = function(_, value)
    w.undriveable = value
  end
  function w.accelerate()
    -- GTA fixture: the accelerator naturally starts an occupied vehicle
    -- unless the resource explicitly disables automatic engine starting.
    if w.inside and not w.autoStartDisabled then
      w.engine = true
    end
  end
  env.SetEntityCoords = function(_, x, y, z)
    local target = { x = x, y = y, z = z }
    if ESXDMVEvaluation.Distance(target, Config.School.returnPos) < 0.01 then
      w.returned = w.returned + 1
    else
      w.preparationMoves = (w.preparationMoves or 0) + 1
    end
    w.playerPos = target
  end
  env.SetEntityHeading = function(_, heading)
    w.heading = heading
  end
  env.NetworkGetNetworkIdFromEntity = function()
    return 123
  end
  env.NetworkGetEntityFromNetworkId = function(netId)
    return netId == 123 and w.exists and not w.networkMissing and 100 or 0
  end
  env.NetworkHasControlOfEntity = function()
    return w.owns ~= false
  end
  env.joaat = function(model)
    return model
  end
  env.IsModelInCdimage, env.IsModelValid, env.HasModelLoaded =
    function()
      return true
    end, function()
      return true
    end, function()
      return true
    end
  env.CreatePed = function()
    return 300
  end
  env.CreatePedInsideVehicle = function()
    w.examinerCreated = true
    return 201
  end
  env.DeletePed = function(ped)
    w.deletedPed = ped
  end
  env.AddBlipForCoord = function()
    w.blips = (w.blips or 0) + 1
    return w.blips
  end
  env.DoesBlipExist = function()
    return true
  end
  env.RemoveBlip = function()
    w.removedBlips = (w.removedBlips or 0) + 1
  end
  env.IsControlJustReleased = function()
    local pressed = w.press
    w.press = false
    return pressed == true
  end
  local function noop() end
  for _, name in ipairs({
    'SetEntityAsMissionEntity',
    'SetVehicleNumberPlateText',
    'SetNetworkIdCanMigrate',
    'SetVehicleDoorsLocked',
    'SetVehicleNeedsToBeHotwired',
    'SetBlockingOfNonTemporaryEvents',
    'SetEntityInvincible',
    'SetModelAsNoLongerNeeded',
    'RequestModel',
    'SetBlipSprite',
    'SetBlipColour',
    'SetBlipScale',
    'SetBlipAsShortRange',
    'BeginTextCommandSetBlipName',
    'AddTextComponentString',
    'EndTextCommandSetBlipName',
    'SetBlipRoute',
    'SetBlipRouteColour',
    'SetBlipDisplay',
    'FreezeEntityPosition',
    'TaskStartScenarioInPlace',
    'DisableControlAction',
    'DisablePlayerFiring',
    'DrawLine',
  }) do
    env[name] = noop
  end
  env.ESX.ShowNotification = function(value)
    w.notification = value
  end
  env.ESX.ShowHelpNotification = noop
  env.RegisterNetEvent = function(name, fn)
    w.events[name] = fn
  end
  env.AddEventHandler = env.RegisterNetEvent
  env.TriggerServerEvent = function(name, ...)
    local args = { ... }
    w.eventsSent = w.eventsSent or {}
    w.eventsSent[#w.eventsSent + 1] = { name = name, args = args }
    if name:match(':cancelTest$') and args[2] == w.vehicleSession then
      w.leaseCompleted = true
    end
    if name:match(':releaseVehicle$') and args[1] == w.vehicleSession and w.leaseCompleted and w.exists then
      w.deleted, w.exists, w.inside = w.deleted + 1, false, false
    end
  end
  env.xLib = { nui = { defer = {} }, game = {} }
  env.xLib.nui.register = function(name, fn)
    w.nui[name] = fn
  end
  env.xLib.nui.send = function(action, data)
    w.messages[#w.messages + 1] = { action = action, data = data }
  end
  env.xLib.nui.focus = function(a, b, c)
    w.focus = { a, b, c }
  end
  local function theoryPayload()
    local questions = {}
    for index = 1, 10 do
      questions[index] =
        { id = index, text = ('Question %d'):format(index), answers = { 'First', 'Second', 'Third', 'Fourth' } }
    end
    return { questions = questions, questionCount = 10, answersNeeded = 5, locale = 'en' }
  end
  local function gradeTheory(session, answers)
    if w.theoryResults[session] then
      return w.theoryResults[session]
    end
    local ticket = w.tickets[session]
    if not ticket or ticket.license ~= 'dmv' then
      return { ok = false, error = 'invalid_session' }
    end
    if type(answers) ~= 'table' then
      return { ok = false, error = 'invalid_result' }
    end
    for key, value in pairs(answers) do
      if
        type(key) ~= 'number'
        or key % 1 ~= 0
        or key < 1
        or key > 10
        or type(value) ~= 'number'
        or value % 1 ~= 0
        or value < 0
        or value > 3
      then
        return { ok = false, error = 'invalid_result' }
      end
    end
    local score, correct = 0, {}
    for index = 1, 10 do
      if answers[index] == nil then
        return { ok = false, error = 'invalid_result' }
      end
      correct[index] = index <= 5 and 0 or 1
      if answers[index] == correct[index] then
        score = score + 1
      end
    end
    w.grades = w.grades + 1
    local passed = score >= 5
    local result = {
      ok = true,
      kind = 'theory',
      session = session,
      license = 'dmv',
      score = score,
      total = 10,
      passed = passed,
      confirmed = passed and not w.deferTheoryGrant,
      correctAnswers = correct,
    }
    w.theoryResults[session] = result
    if result.confirmed then
      w.licenses = { { type = 'dmv' } }
    end
    return result
  end
  env.xLib.callback = function(name, _, done, ...)
    local args, suffix = { ... }, name:match(':([^:]+)$')
    if suffix == 'getLicenses' then
      done(w.licenses)
    elseif suffix == 'canYouPay' then
      w.paid, w.selected = w.paid + 1, args[1]
      local session = 'session-' .. w.paid
      w.tickets[session] = { license = args[1] }
      if w.deferPay then
        w.payReply = done
      else
        done(true, { session = session, theory = args[1] == 'dmv' and theoryPayload() or nil })
      end
    elseif suffix == 'createVehicle' then
      w.createRequests = (w.createRequests or 0) + 1
      w.createReply = function(response)
        if response and response.ok == false then
          return done(response)
        end
        local ticket = w.tickets[args[1]]
        local license
        for _, candidate in ipairs(Config.Licenses) do
          if ticket and candidate.id == ticket.license then
            license = candidate
          end
        end
        if not license then
          return done({ ok = false, error = 'invalid_session' })
        end
        w.spawned, w.exists, w.model, w.pos, w.heading =
          w.spawned + 1, true, license.model, license.spawn, license.spawn.w
        w.stateFuel, w.vehicleSession, w.leaseCompleted = 100.0, args[1], false
        done({ ok = true, netId = 123 })
      end
      if not w.deferCreate then
        w.createReply(w.createFailure and { ok = false, error = w.createFailure } or nil)
      end
    elseif suffix == 'beginPractical' then
      w.began = w.began + 1
      if w.beginNotReady > 0 then
        w.beginNotReady = w.beginNotReady - 1
        done({ ok = false, error = 'vehicle_not_ready' })
      else
        w.bound = true
        done({ ok = true, errors = w.errors, incidents = {} })
      end
    elseif suffix == 'advancePractical' then
      w.advanced[#w.advanced + 1] = args[2]
      if w.advanceNotReady then
        w.advanceNotReady = false
        done({ ok = false, error = 'step_not_ready' })
      else
        done({ ok = true, index = args[2] + 1, errors = w.errors, incidents = {} })
      end
    elseif suffix == 'completePractical' then
      w.completed = w.completed + 1
      w.completeReply = function(response)
        if response.ok and response.passed and response.confirmed then
          w.leaseCompleted = true
        end
        done(response)
      end
      if not w.deferComplete then
        w.completeReply({ ok = true, passed = true, confirmed = true, errors = w.errors, incidents = {} })
      end
    elseif suffix == 'cancelTest' then
      w.cancelled = w.cancelled + 1
      w.leaseCompleted = true
      done({ ok = true, cancelled = true, errors = w.errors, incidents = {} })
    elseif suffix == 'submitTheory' then
      w.submissions = w.submissions + 1
      w.submitted = { session = args[1], answers = args[2] }
      local result = gradeTheory(args[1], args[2])
      w.theoryReply = function(response)
        done(response or result)
      end
      local reply = w.theoryReply
      if not w.deferSubmit then
        queue(function()
          reply(w.submitFailure and { ok = false, error = w.submitFailure } or nil)
        end)
      end
    else
      error('unmocked callback ' .. name)
    end
  end
  assert(load(ClientSource, 'client/main.lua', 't', env))()
  function w.open()
    w.nui.ready()
    w.run(1)
    env.OpenDMVSchoolMenu()
  end
  function w.start(id)
    local answer
    local returned = w.nui.startTest({ license = id }, function(value)
      answer = value
    end)
    return answer or returned
  end
  function w.submit(data)
    w.nuiResponse = nil
    local returned = w.nui.theoryResult(data, function(value)
      w.nuiResponse = value
    end)
    return w.nuiResponse or returned
  end
  function w.place(step, forwardOffset)
    w.heading = step.heading or 0
    local h = math.rad(w.heading)
    local localY = (forwardOffset or 0) - (w.modelCenterY or 0.4) -- model bbox centre offset
    w.pos = { x = step.pos.x - localY * math.sin(h), y = step.pos.y + localY * math.cos(h), z = step.pos.z }
  end
  return w, env
end

local w, env = fixture()
w.beginNotReady = 1
w.open()
check(w.last('dmv:home').school.title == 'Los Santos Driving School', 'school identity payload')
check(w.last('dmv:home').licenses[2].taskCount == 14, 'briefing task count available before purchase')
check(w.start('drive').ok, 'practical purchase acknowledged')
w.run(400)
check(w.createRequests == 1 and w.spawned == 1, 'practical resolves one server-assigned network vehicle')
env.TriggerServerEvent('esx_dmvschool:releaseVehicle', w.vehicleSession)
check(w.deleted == 0 and w.exists, 'active assigned vehicle cannot be released before a terminal result')
check(w.began == 1, 'first bind waits for genuine entry')
check(#w.advanced == 0, 'engine-off does not advance')
check(w.registrations.HasActiveExam(), 'active exam exported')
check(w.autoStartDisabled == false, 'vehicle retains normal GTA auto-start')
check(w.entryFlag == 1 and w.entryRequests == 1, 'genuine normal GTA entry requested once')
check(w.entryFuel == 100 and w.entryState == 100 and w.entryDecorator == 100, 'fuel synchronized before entry')
check(math.type(w.entryFuel) == 'float', 'native fuel receives a Lua float')
check(math.type(w.entryState) == 'float', 'fuel state receives a Lua float')
check(math.type(w.entryDecorator) == 'float', 'registered fuel decorator receives a Lua float')
check(w.preparationMoves == 1, 'initial placement beside vehicle only')
w.advanceNotReady = true
w.run(800)
check(w.began == 2, 'network bind retries replication delay')
check(
  w.engine and w.engineStarts == 1 and not w.startedBeforeBind,
  'one automatic engine request only after driver binding'
)
check(w.undriveable == false, 'prepared examination vehicle is driveable')
check(w.last('dmv:practical').checkpoint == 2, 'engine gate accepted after retry')
check(w.numericBooleans and w.engine, 'numeric native 0/1 engine boundary advances normally')
check(w.examinerCreated, 'car has examiner passenger')
w.deferComplete = true
for index = 2, #Config.Routes.car do
  local step = Config.Routes.car[index]
  if step.requireReverse then
    w.forward, w.speed = -1, 1
    for i = 0, 30 do
      w.place(step, 3 - i * 0.1)
      w.run(100)
    end
  end
  w.forward, w.speed = 0, 0
  w.place(step)
  w.run((step.hold or 0) + 500)
end
check(w.completed == 1, 'one completion requested after all tasks')
check(w.deleted == 0 and w.returned == 0, 'vehicle and player retained until server confirmation')
check(w.last('dmv:practical').taskStatus == 'ready', 'task status propagated')
w.completeReply({ ok = false, error = 'step_not_ready' })
w.run(600)
check(w.completed == 2 and w.deleted == 0, 'finish hold race retries without deleting')
w.completeReply({ ok = true, passed = true, confirmed = true, errors = 0, incidents = {} })
w.run(10)
check(w.deleted == 1 and w.returned == 1, 'confirmed result permits cleanup and safe return')
check(w.last('dmv:result').confirmed and w.last('dmv:result').passed, 'confirmed practical result')
check(not w.registrations.HasActiveExam(), 'attempt cleared after result')
check(w.nui.close({}).ok, 'result closes')
env.OpenDMVSchoolMenu()
w.blocked = true
local before = w.paid
local blocked = w.start('drive_truck')
check(blocked.error == 'spawn_blocked' and w.paid == before, 'blocked spawn rejects before payment')
w.blocked = false
w.deferPay = true
w.start('drive_truck')
check(w.registrations.HasActiveExam(), 'pending payment is busy')
w.nui.close({ abandon = true })
local spawned = w.spawned
w.payReply(true, { session = 'late-ticket' })
check(w.spawned == spawned, 'late paid reply after cancellation never spawns')
check(w.eventsSent[#w.eventsSent].args[2] == 'late-ticket', 'late ticket cancelled by session')
w.deferPay = false
env.OpenDMVSchoolMenu()
w.start('drive_bike')
w.run(300)
w.errors = 5
local session = w.last('dmv:practical').session
w.events['esx_dmvschool:practicalState']({ session = session, errors = 5, incidents = {}, failed = true })
w.run(10)
check(w.last('dmv:result').errors == 5, 'server error count is not doubled')
check(w.last('dmv:result').passed == false, 'server threshold aborts without grant')
check(w.notification == nil, 'faults stay in HUD without duplicate notification')

local theory, tEnv = fixture()
theory.licenses = {}
theory.deferTheoryGrant = true
theory.open()
check(theory.start('dmv').ok, 'theory starts from profile licence')
local theoryData = theory.last('dmv:theory')
local theorySession = theoryData.session
check(
  #theoryData.questions == 10 and theoryData.questions[1].id == 1 and #theoryData.questions[1].answers == 4,
  'theory receives server-assigned question IDs, text and four answers'
)
check(
  theoryData.questions[1].correct == nil and theoryData.correctAnswers == nil,
  'active theory payload contains no answer key'
)
check(
  theory.submit({ session = theorySession, score = 10, total = 10, passed = true }).error == 'invalid_result'
    and theory.submissions == 0,
  'caller grades cannot replace an answer submission'
)
check(
  theory.submit({ session = 'another-session', answers = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 } }).error == 'invalid_session'
    and theory.submissions == 0,
  'a different theory session never reaches server grading'
)
check(
  theory.submit({ session = theorySession, answers = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, score = 0, passed = false })
    == tEnv.xLib.nui.defer,
  'theory result waits for the asynchronous server response'
)
theory.run(1)
check(
  theory.nuiResponse.ok and theory.last('dmv:result').score == 5 and theory.last('dmv:result').passed,
  'server score preserves the original five-of-ten threshold'
)
check(
  theory.submitted.session == theorySession and theory.submitted.answers[1] == 0 and theory.grades == 1,
  'client submits only the current session and zero-based answer choices'
)
check(not theory.last('dmv:result').confirmed, 'theory grant stays pending before owned push')
check(
  theory.submit({ session = theorySession, answers = { 3 } }).duplicate and theory.submissions == 1,
  'completed theory acknowledgement is idempotent'
)
theory.events['esx_dmvschool:loadLicenses']({ { type = 'dmv' } })
check(theory.last('dmv:result').confirmed, 'owned push confirms theory grant')
check(
  theory.submit({ session = theorySession }).result.confirmed and theory.grades == 1,
  'duplicate result retains the confirmed ownership cache'
)
check(#theory.last('dmv:result').correctAnswers == 10, 'answer review is supplied only by the server result')

local rejected = fixture()
rejected.licenses = {}
rejected.open()
rejected.start('dmv')
local rejectedSession = rejected.last('dmv:theory').session
rejected.submit({ session = rejectedSession, answers = { 0, 0, 0, 0, 0, 0, 0, 0, 0 } })
rejected.run(1)
check(
  rejected.nuiResponse.error == 'invalid_result'
    and rejected.registrations.HasActiveExam()
    and rejected.last('dmv:result') == nil,
  'server rejection of an incomplete submission preserves the active exam'
)
rejected.submit({ session = rejectedSession, answers = { 4, 0, 0, 0, 0, 0, 0, 0, 0, 0 } })
rejected.run(1)
check(
  rejected.nuiResponse.error == 'invalid_result' and rejected.grades == 0,
  'out-of-range choices remain a server validation failure'
)
rejected.submit({
  session = rejectedSession,
  answers = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 },
  score = 10,
  total = 10,
  passed = true,
})
rejected.run(1)
check(
  rejected.nuiResponse.ok and rejected.last('dmv:result').score == 0 and not rejected.last('dmv:result').passed,
  'server failure overrides a forged caller score and pass flag'
)

local retry = fixture()
retry.licenses = {}
retry.open()
retry.start('dmv')
retry.deferSubmit = true
local retrySession = retry.last('dmv:theory').session
local retryAnswers = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
retry.submit({ session = retrySession, answers = retryAnswers })
local lateTheoryReply = retry.theoryReply
check(
  retry.submit({ session = retrySession, answers = retryAnswers }).error == 'busy' and retry.submissions == 1,
  'one in-flight theory request blocks concurrent submissions'
)
retry.run(10010)
check(
  retry.nuiResponse.error == 'timeout' and retry.registrations.HasActiveExam(),
  'lost theory response resets pending state for a retry'
)
retry.deferSubmit = false
retry.submit({ session = retrySession, answers = retryAnswers })
retry.run(1)
check(
  retry.nuiResponse.ok and retry.last('dmv:result').confirmed and retry.grades == 1 and retry.submissions == 2,
  'network retry accepts the server cached result without grading twice'
)
lateTheoryReply({ ok = false, error = 'invalid_session' })
check(
  retry.last('dmv:result').confirmed and retry.nuiResponse.ok,
  'late response from a timed-out request cannot replace a confirmed result'
)
check(
  retry.submit({ session = 'different-session', answers = retryAnswers }).error == 'invalid_session'
    and retry.submissions == 2,
  'completed result cache cannot be replayed across sessions'
)

local mismatched = fixture()
mismatched.licenses = {}
mismatched.open()
mismatched.start('dmv')
mismatched.deferSubmit = true
local matchedSession = mismatched.last('dmv:theory').session
mismatched.submit({ session = matchedSession, answers = retryAnswers })
mismatched.theoryReply({
  ok = true,
  kind = 'theory',
  session = 'wrong-session',
  license = 'dmv',
  score = 10,
  total = 10,
  passed = true,
  confirmed = true,
})
check(
  mismatched.nuiResponse.error == 'unavailable'
    and mismatched.last('dmv:result') == nil
    and mismatched.registrations.HasActiveExam(),
  'a result for another session does not complete the current theory'
)
mismatched.deferSubmit = false
mismatched.submit({ session = matchedSession, answers = retryAnswers })
mismatched.run(1)
check(
  mismatched.last('dmv:result').score == 5 and mismatched.grades == 1,
  'current-session retry recovers the authoritative cached grade'
)

local cancelled = fixture()
cancelled.licenses = {}
cancelled.open()
cancelled.start('dmv')
cancelled.deferSubmit = true
local cancelledSession = cancelled.last('dmv:theory').session
cancelled.submit({ session = cancelledSession, answers = retryAnswers })
cancelled.nui.close({ abandon = true })
check(
  cancelled.last('dmv:result').cancelled and cancelled.last('dmv:result').score == nil,
  'theory cancellation reports an ungraded cancelled result'
)
cancelled.theoryReply()
check(
  cancelled.nuiResponse.error == 'invalid_session' and cancelled.last('dmv:result').cancelled,
  'late theory success cannot replace a cancelled attempt'
)

local timeout, tEnv2 = fixture()
timeout.open()
timeout.deferPay = true
timeout.start('drive')
timeout.run(8100)
check(not timeout.registrations.HasActiveExam(), 'payment timeout clears busy state')
local deaths, dEnv = fixture()
deaths.open()
deaths.start('drive')
deaths.run(100)
deaths.dead = true
deaths.run(100)
check(deaths.completed == 0 and deaths.last('dmv:result').passed == false, 'death cancels without completion')
check(deaths.returned == 0, 'dead player is never teleported')
local stop, sEnv = fixture()
stop.open()
stop.start('drive')
stop.run(100)
stop.events.onResourceStop('esx_dmvschool')
check(stop.deleted == 1 and stop.focus[1] == false, 'resource stop clears vehicle and focus')
check(not stop.registrations.HasActiveExam(), 'resource stop clears local session')
check(stop.interactionDisposed, 'resource stop disposes school interaction')
local fuel, fEnv = fixture()
fuel.decorRegistered = false
fuel.open()
fuel.start('drive')
fuel.run(300)
check(fuel.decoratorFuel == nil and fuel.stateFuel == 100, 'unregistered decorators are not written')
local remote, rEnv = fixture()
remote.owns = false
remote.open()
remote.start('drive')
remote.run(400)
check(
  remote.stateFuel == 100.0 and math.type(remote.stateFuel) == 'float' and remote.stateWrites == 0,
  'server fuel survives entry while this client does not own the entity'
)
check(
  remote.fuel == 100.0 and remote.decoratorFuel == 100.0 and remote.engine,
  'local native fuel and engine preparation tolerate pending ownership'
)
local rejectedVehicle = fixture()
rejectedVehicle.createFailure = 'spawn_blocked'
rejectedVehicle.open()
rejectedVehicle.start('drive')
rejectedVehicle.run(100)
check(
  rejectedVehicle.spawned == 0 and rejectedVehicle.began == 0 and rejectedVehicle.entryRequests == nil,
  'server spawn rejection never creates or enters a local replacement vehicle'
)
check(
  rejectedVehicle.last('dmv:result').passed == false and rejectedVehicle.last('dmv:result').reason == 'spawn_blocked',
  'server creation error becomes the practical cancellation reason'
)
local replication = fixture()
replication.networkMissing = true
replication.open()
replication.start('drive')
replication.run(200)
check(
  replication.began == 0 and replication.entryRequests == nil,
  'client waits for its assigned network entity to replicate'
)
replication.networkMissing = false
replication.run(400)
check(
  replication.bound and replication.entryRequests == 1 and replication.spawned == 1,
  'replication recovery enters the same server-assigned vehicle once'
)
local fallback, fallbackEnv = fixture()
fallback.stallEntry = true
fallback.open()
fallback.start('drive')
fallback.run(8500)
check(fallback.bound and fallback.inside and fallback.engine, 'stalled normal entry safely falls back to assigned seat')
check(fallback.engineStarts == 1, 'entry fallback still requests engine once')
local booleans, bEnv = fixture()
booleans.numericBooleans = false
booleans.open()
booleans.start('drive')
booleans.run(400)
check(booleans.last('dmv:practical').checkpoint == 2, 'boolean native false/true engine boundary advances normally')
local truck, truckEnv = fixture()
truckEnv.ESXDMVMarkers = {
  SetTarget = function() end,
  Clear = function() end,
  Draw = function() end,
  RouteDistance = function()
    return 999
  end,
}
truck.open()
truck.start('drive_truck')
truck.run(1200)
truck.deferComplete = true
local parkedOrigin
for index = 2, #Config.Routes.truck do
  local step = Config.Routes.truck[index]
  if step.requireReverse then
    truck.place(step)
    truck.heading = (step.heading + 20) % 360
    truck.forward, truck.speed = 0, 0
    truck.run(200)
    check(
      truck.last('dmv:practical').parkingHint == 'parking_turn_right',
      'truck HUD coaches the actual alignment direction'
    )
    truck.forward, truck.speed = -1, 1
    for i = 0, 30 do
      truck.place(step, 3 - i * 0.1)
      truck.run(100)
    end
  end
  truck.forward, truck.speed = 0, 0
  truck.place(step)
  truck.pos.z = truck.pos.z + 1.23
  if step.type == 'park' then
    truck.run(400)
    check(
      truck.last('dmv:practical').distance == 0,
      'parking HUD uses horizontal distance, not stale GPS or vehicle height'
    )
    parkedOrigin = { x = truck.pos.x, y = truck.pos.y, z = truck.pos.z }
  elseif step.type == 'finish' then
    check(
      parkedOrigin and ESXDMVEvaluation.Distance(parkedOrigin, truck.pos) < 0.001,
      'truck confirmation retains exactly the parked model origin'
    )
  end
  truck.run((step.hold or 0) + 500)
end
check(
  truck.completed == 1 and truck.deleted == 0,
  'truck completes ordered tasks once and waits for server confirmation'
)
truck.completeReply({ ok = true, passed = true, confirmed = true, errors = 0, incidents = {} })
truck.run(10)
check(truck.deleted == 1 and truck.last('dmv:result').confirmed, 'truck cleanup follows confirmed license result')
local originalLocale = Config.Locale
Config.Locale = 'es'
local spanish = fixture()
spanish.open()
local home = spanish.last('dmv:home')
check(
  home.locale == 'es' and home.school.title == 'Autoescuela Los Santos',
  'client resolves configured school through Translate'
)
check(
  home.licenses[2].label == 'Coche' and home.ui.common_next == 'Siguiente',
  'client sends translated labels and NUI dictionary'
)
check(home.owned.dmv == true and home.owned.drive == false, 'official license refresh updates local ownership')
spanish.events['esx_dmvschool:loadLicenses']({ { type = 'drive' } })
check(
  spanish.last('dmv:licenses').owned.drive and not spanish.last('dmv:licenses').owned.dmv,
  'loadLicenses replaces the character license cache'
)
Config.Locale = originalLocale
print(('client lifecycle: %d assertions passed'):format(checks))
return checks
