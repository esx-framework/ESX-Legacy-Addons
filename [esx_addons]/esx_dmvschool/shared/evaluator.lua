-- SPDX-License-Identifier: GPL-3.0-only
-- Driving manoeuvre geometry and conditions shared by client and server.
ESXDMVEvaluation = {}
local evaluation = ESXDMVEvaluation

local function position(value)
  if type(value) == 'table' and value.pos then
    return value.pos
  end
  return value
end
function evaluation.Distance(a, b)
  a, b = position(a), position(b)
  return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
end
function evaluation.HeadingDelta(a, b)
  return math.abs(((a - b + 180) % 360) - 180)
end

function evaluation.FootprintFits(step, snapshot)
  local currentPos, targetPos = position(snapshot), step.pos
  local offset = snapshot.footprintOffset
  if offset then
    local headingRadians = math.rad(snapshot.heading or 0)
    currentPos = {
      x = currentPos.x + (offset.x or 0) * math.cos(headingRadians) - (offset.y or 0) * math.sin(headingRadians),
      y = currentPos.y + (offset.x or 0) * math.sin(headingRadians) + (offset.y or 0) * math.cos(headingRadians),
      z = currentPos.z,
    }
  end
  local radians = math.rad(step.heading or snapshot.heading or 0)
  local dx, dy = currentPos.x - targetPos.x, currentPos.y - targetPos.y
  local lateral = dx * math.cos(radians) + dy * math.sin(radians)
  local longitudinal = -dx * math.sin(radians) + dy * math.cos(radians)
  local relative = math.rad((snapshot.heading or 0) - (step.heading or snapshot.heading or 0))
  local halfWidth, halfLength = (snapshot.vehicleWidth or 2.0) / 2, (snapshot.vehicleLength or 4.5) / 2
  local lateralExtent = math.abs(math.cos(relative)) * halfWidth + math.abs(math.sin(relative)) * halfLength
  local longitudinalExtent = math.abs(math.sin(relative)) * halfWidth + math.abs(math.cos(relative)) * halfLength
  return math.abs(lateral) + lateralExtent <= (step.width or 4.0) / 2
    and math.abs(longitudinal) + longitudinalExtent <= (step.length or 7.0) / 2
    and math.abs(currentPos.z - targetPos.z) <= (step.verticalTolerance or 2.5)
end

-- Presentation-only hint. Never changes the snapshot, tracking or grading.
function evaluation.ParkingHint(step, snapshot, reason)
  if type(step) ~= 'table' or type(snapshot) ~= 'table' or snapshot.driving ~= true then
    return nil
  end
  if step.type ~= 'park' and step.type ~= 'finish' then
    return nil
  end
  if reason ~= 'heading' and reason ~= 'footprint' then
    return nil
  end
  local function isFinite(value)
    return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
  end
  if
    not isFinite(step.width)
    or step.width <= 0
    or not isFinite(step.length)
    or step.length <= 0
    or not isFinite(step.heading)
    or not isFinite(snapshot.heading)
    or not step.pos
  then
    return nil
  end
  local currentPos = position(snapshot)
  if not isFinite(currentPos.x) or not isFinite(currentPos.y) or not isFinite(currentPos.z) then
    return nil
  end
  if evaluation.Distance(currentPos, step.pos) > math.max(step.width, step.length) + 3.0 then
    return nil
  end
  local delta = ((step.heading - snapshot.heading + 180.0) % 360.0) - 180.0
  if reason == 'footprint' then
    if math.abs(delta) <= 2.0 then
      return nil
    end
    local aligned = {}
    for key, value in pairs(snapshot) do
      aligned[key] = value
    end
    aligned.heading = step.heading
    if not evaluation.FootprintFits(step, aligned) then
      return nil
    end
  end
  if delta > 0 then
    return 'parking_turn_left'
  end
  if delta < 0 then
    return 'parking_turn_right'
  end
end

-- snapshot={x,y,z OR pos,heading,speed(display units),driving,engine,
-- vehicleWidth,vehicleLength,forwardSpeed(m/s)}.
-- tracking belongs to exactly one step; never reuse between steps/attempts.
-- Returns passed:boolean, holdProgress:0..1, detail:{distance,reason,reverseDistance}.
function evaluation.Evaluate(step, snapshot, tracking, now)
  tracking = tracking or {}
  local currentPos = position(snapshot)
  local distance = evaluation.Distance(currentPos, step.pos)
  local speed = math.abs(snapshot.speed or 0)
  local kind = step.type
  local condition, reason = snapshot.driving == true, 'driver'
  local deltaSeconds = tracking.lastAt and math.max(0, math.min(now - tracking.lastAt, 500)) / 1000 or 0
  tracking.lastAt = now
  local reverseSpeed = -(snapshot.forwardSpeed or 0)
  local travelled = tracking.lastPos and evaluation.Distance(currentPos, tracking.lastPos) or 0
  local fitsBay = (kind == 'park' or step.requireReverse) and evaluation.FootprintFits(step, snapshot)
  if step.requireReverse then
    local inApproach = distance <= math.max(step.length or 7, step.width or 4) + 8
    -- Earlier reverse travel cannot count after a forward approach or after exiting the bay.
    if
      not inApproach
      or (tracking.reverseEntry and not fitsBay)
      or (not tracking.reverseEntry and reverseSpeed < 0 and travelled > 0)
    then
      tracking.reverseDistance, tracking.reverseEntry = nil, nil
    end
    if
      snapshot.driving == true
      and inApproach
      and reverseSpeed > 0
      and reverseSpeed <= (step.maxReverseSpeed or 5)
      and travelled <= math.max(2, reverseSpeed * deltaSeconds * 2)
    then
      -- Both displacement and elapsed time bound accepted reverse travel.
      tracking.reverseDistance = (tracking.reverseDistance or 0) + math.min(reverseSpeed * deltaSeconds, travelled)
      if fitsBay and travelled > 0 and tracking.reverseDistance >= (step.reverseDistance or 2) then
        tracking.reverseEntry = true
      end
    end
  end
  tracking.lastPos = { x = currentPos.x, y = currentPos.y, z = currentPos.z }
  local function requireCondition(ok, why)
    if condition and not ok then
      condition, reason = false, why
    end
  end
  local function requireHeading()
    if step.heading then
      requireCondition(
        evaluation.HeadingDelta(snapshot.heading or 0, step.heading) <= (step.headingTolerance or 18),
        'heading'
      )
    end
  end
  if kind == 'engine' then
    requireCondition(snapshot.engine == true, 'engine')
  elseif kind == 'park' then
    requireCondition(fitsBay, 'footprint')
    requireHeading()
    requireCondition(speed <= (step.maxSpeed or 1), 'speed')
    if step.requireReverse then
      requireCondition(
        (tracking.reverseDistance or 0) >= (step.reverseDistance or 2) and tracking.reverseEntry == true,
        'reverse'
      )
    end
    if step.engineOff then
      requireCondition(snapshot.engine == false, 'engine_off')
    end
  elseif kind == 'stop' or kind == 'finish' then
    requireCondition(distance <= (step.radius or 5), 'position')
    requireCondition(speed <= (step.maxSpeed or 1), 'speed')
    if kind == 'finish' and step.width and step.length then
      requireCondition(evaluation.FootprintFits(step, snapshot), 'footprint')
    end
    requireHeading()
    if step.engineOff then
      requireCondition(snapshot.engine == false, 'engine_off')
    end
  elseif kind == 'navigate' then
    requireCondition(distance <= (step.radius or 12), 'position')
    if step.maxSpeed then
      requireCondition(speed <= step.maxSpeed, 'speed')
    end
    requireHeading()
  else
    requireCondition(false, 'unsupported_step')
  end
  local duration = step.hold
  if duration == nil then
    duration = (kind == 'park' or kind == 'stop' or kind == 'finish') and 2000 or 0
  end
  if not condition then
    tracking.holdSince = nil
    return false, 0, { distance = distance, reason = reason, reverseDistance = tracking.reverseDistance or 0 }
  end
  tracking.holdSince = tracking.holdSince or now
  local progress = duration > 0 and math.min(1, math.max(0, now - tracking.holdSince) / duration) or 1
  return progress >= 1,
    progress,
    { distance = distance, reason = 'ready', reverseDistance = tracking.reverseDistance or 0 }
end
