local checks = 0
local function check(value, label)
  checks = checks + 1
  assert(value, label)
end
local evaluation = ESXDMVEvaluation
local function car(overrides)
  local s = {x = 0, y = 0, z = 0, heading = 0, speed = 0, driving = true,
    engine = true, onGround = true, airborne = false, vehicleWidth = 2, vehicleLength = 4, forwardSpeed = 0}
  for k,v in pairs(overrides or {}) do s[k] = v end
  return s
end
local park = {type = 'park', pos = {x = 0,y = 0,z = 0}, width = 4,length = 8,heading = 0,headingTolerance = 10,hold = 2000}
check(evaluation.HeadingDelta(359, 1) == 2, 'heading wraps north')
check(evaluation.FootprintFits(park, car()), 'centred car fits')
check(not evaluation.FootprintFits(park, car({x = 1.1})), 'whole width must fit')
check(not evaluation.FootprintFits(park, car({y = 2.1})), 'whole length must fit')
check(not evaluation.FootprintFits(park, car({x = 0.5, heading = 90})), 'rotated corners are checked')
check(not evaluation.FootprintFits(park, car({footprintOffset = {x = 1.1, y = 0}})), 'off-centre model rejected at boundary')
check(evaluation.FootprintFits(park, car({x = -1.1, footprintOffset = {x = 1.1, y = 0}})), 'off-centre model corrected')
check(not evaluation.FootprintFits(park, car({heading = 90, footprintOffset = {x = 0, y = -2}})), 'offset follows vehicle rotation')
local tracking = {}
local passed, progress = evaluation.Evaluate(park, car(), tracking, 1000)
check(not passed and progress == 0, 'hold begins at zero')
passed, progress = evaluation.Evaluate(park, car(), tracking, 2000)
check(not passed and progress == .5, 'hold progresses continuously')
passed = evaluation.Evaluate(park, car({speed = 2}), tracking, 2500)
check(not passed and tracking.holdSince == nil, 'moving resets hold')
evaluation.Evaluate(park, car(), tracking, 3000)
passed = evaluation.Evaluate(park, car(), tracking, 4999)
check(not passed, 'interrupted hold cannot resume old timer')
passed = evaluation.Evaluate(park, car(), tracking, 5000)
check(passed, 'full continuous hold passes')
check(not evaluation.Evaluate(park, car({heading = 30}), {}, 0), 'heading enforced')
check(not evaluation.Evaluate(park, car({driving = false}), {}, 0), 'passenger cannot park')
local reverse = {type = 'park',pos = {x = 0,y = 0,z = 0},width = 4,length = 10,heading = 0,hold = 0,requireReverse = true}
tracking = {}
for i = 0, 30 do evaluation.Evaluate(reverse, car({y = 3-i*.1, forwardSpeed = -1, driving = false}), tracking, i*100) end
check((tracking.reverseDistance or 0) == 0, 'passenger reverse never credited')
tracking = {}
for i = 0, 30 do passed = evaluation.Evaluate(reverse, car({y = 3-i*.1, forwardSpeed = -1}), tracking, i*100) end
check(passed and tracking.reverseDistance >= 2, 'two metres of actual reverse credited')
tracking = {}
evaluation.Evaluate(reverse, car({y = 1,forwardSpeed = -1}), tracking, 0)
evaluation.Evaluate(reverse, car({y = -1,forwardSpeed = -1}), tracking, 60000)
check((tracking.reverseDistance or 0) <= .5, 'long timestep cannot fabricate reverse distance')
tracking = {}
evaluation.Evaluate(reverse, car({y = 0,forwardSpeed = -1}), tracking, 0)
evaluation.Evaluate(reverse, car({y = 8,forwardSpeed = -1}), tracking, 100)
check((tracking.reverseDistance or 0) == 0, 'warp is not reverse travel')
tracking = {}
for i = 0,30 do evaluation.Evaluate(reverse, car({y = 3-i*.1,forwardSpeed = -50}),tracking,i*100) end
check((tracking.reverseDistance or 0) == 0, 'high-speed motion is not parking')
tracking = {}
for i = 0,30 do evaluation.Evaluate(reverse, car({y = 10-i*.1,forwardSpeed = -1}),tracking,i*100) end
passed = evaluation.Evaluate(reverse,car(),tracking,3200)
check(not passed, 'reversing outside then entering forwards is not reverse parking')
tracking = {}
for i = 0,30 do evaluation.Evaluate(reverse, car({y = 3-i*.1,forwardSpeed = -1}),tracking,i*100) end
evaluation.Evaluate(reverse,car({y = 4,forwardSpeed = 1}),tracking,3200)
passed = evaluation.Evaluate(reverse,car(),tracking,3300)
check(not passed, 'leaving forwards resets reverse entry evidence')
tracking = {}
for i = 0, 25 do evaluation.Evaluate(reverse, car({y = -5-i*.1, forwardSpeed = -1}), tracking, i*100) end
check(tracking.reverseDistance >= 2 and not tracking.reverseEntry, 'reverse approach has distance but no bay entry')
for i = 1, 75 do evaluation.Evaluate(reverse, car({y = -7.5+i*.1, forwardSpeed = 1}), tracking, 2500+i*100) end
evaluation.Evaluate(reverse, car({y = -.05, forwardSpeed = -.5}), tracking, 10100)
check(not evaluation.Evaluate(reverse, car({y = -.05}), tracking, 10200),
  'a reverse tap after forward entry cannot reuse earlier reverse travel')
tracking = {}
for i = 0, 30 do evaluation.Evaluate(reverse, car({y = 3-i*.1, forwardSpeed = -1}), tracking, i*100) end
evaluation.Evaluate(reverse, car({y = .1, speed = 3.6, forwardSpeed = 1}), tracking, 3100)
check(evaluation.Evaluate(reverse, car({y = .1}), tracking, 3200), 'small forward corrections inside retain valid entry')
for i = 1, 32 do evaluation.Evaluate(reverse, car({y = .1-i*.1, forwardSpeed = -1}), tracking, 3200+i*100) end
check(not tracking.reverseEntry and (tracking.reverseDistance or 0) < 2, 'reversing out of the bay clears prior entry')
local stop = {type = 'stop',pos = {x = 0,y = 0,z = 0},radius = 5,hold = 0}
check(evaluation.Evaluate(stop, car(), {}, 0), 'stopped vehicle passes immediate stop')
check(not evaluation.Evaluate(stop, car({speed = 1.1}), {}, 0), 'stop speed threshold enforced')
check(not evaluation.Evaluate(stop, car({x = 6}), {}, 0), 'stop zone enforced')
local engine = {type = 'engine',pos = {x = 0,y = 0,z = 0}}
check(not evaluation.Evaluate(engine, car({engine = false}), {}, 0), 'engine must run')
check(evaluation.Evaluate(engine, car(), {}, 0), 'driver with engine passes')
local navigate = {type = 'navigate',pos = {x = 0,y = 0,z = 0},radius = 20,maxSpeed = 30}
check(not evaluation.Evaluate(navigate, car({speed = 31}), {}, 0), 'optional navigation speed enforced')
for _, kind in ipairs({'invented', 'dock', 'taxi', 'takeoff', 'airgate', 'land'}) do
  local unsupported = {type = kind, pos = {x = 0, y = 0, z = 0}, hold = 0}
  local accepted, holdProgress, detail = evaluation.Evaluate(unsupported, car(), {}, 0)
  check(not accepted and holdProgress == 0 and detail.reason == 'unsupported_step',
    'foreign or unknown task fails closed: ' .. kind)
end
local seen = {}
for _, license in ipairs(Config.Licenses) do
  check(not seen[license.id], 'unique licence: '..license.id); seen[license.id] = true
  if license.kind == 'practical' then
    local route = Config.Routes[license.route]
    check(#route == 14, 'full road assessment: '..license.id)
    local ids, locations, freeway, reverseTask = {}, {}, false, false
    for index, step in ipairs(route) do
      check(not ids[step.id], 'unique task id: '..step.id); ids[step.id] = true
      local position = ('%.3f,%.3f,%.3f'):format(step.pos.x,step.pos.y,step.pos.z)
      local previous = route[index - 1]
      local parkedConfirmation = index == #route and step.type == 'finish' and step.mapBay == true
        and previous and previous.type == 'park' and previous.mapBay == true
        and evaluation.Distance(previous.pos, step.pos) == 0
      check(not locations[position] or parkedConfirmation, 'unique location or stationary parking confirmation: '..step.id)
      locations[position] = true
      if step.limit == Config.SpeedLimits.freeway then freeway = true end
      if step.requireReverse then reverseTask = true end
    end
    check(freeway, 'licence includes main road')
    check(license.id == 'drive_bike' or reverseTask, 'car/truck includes reverse parking')
    check(route[#route].type == 'finish', 'explicit stopped finish')
    check(evaluation.Distance(license.spawn,Config.School.menu) < 100, 'spawn stays near player')
  end
end
print(('evaluator/profile: %d assertions passed'):format(checks))
return checks
