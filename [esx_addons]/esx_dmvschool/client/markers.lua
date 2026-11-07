-- SPDX-License-Identifier: GPL-3.0-only
-- Native objective markers for the current driving task.
ESXDMVMarkers = {}
local markers = ESXDMVMarkers
local options = type(Config.Markers) == 'table' and Config.Markers or {}
local function finite(v)
  return type(v) == 'number' and v == v and v > -math.huge and v < math.huge
end
local function nativeBoolean(v)
  return v == true or v == 1
end
local function clamp(v, a, b)
  return math.max(a, math.min(b, v))
end
local function setting(name, default, minimum, maximum)
  local value = options[name]
  return finite(value) and clamp(value, minimum, maximum) or default
end
local MARKER_SETTINGS = {
  enabled = Config.Markers ~= false and options.enabled ~= false,
  drawDistance = setting('drawDistance', 250.0, 50.0, 500.0),
  detailDistance = setting('detailDistance', 65.0, 10.0, 150.0),
  fadeDistance = setting('fadeDistance', 35.0, 5.0, 100.0),
  groundInterval = setting('groundInterval', 1000, 500, 5000),
}
local target, targetReference, licenseReference
local groundZ, nextGroundAt = nil, 0
local cachedDistance, nextDistanceAt = nil, 0
local function vector(value)
  if value == nil then
    return nil
  end
  local ok, x, y, z = pcall(function()
    return value.x, value.y, value.z
  end)
  if not ok or not finite(x) or not finite(y) or not finite(z) then
    return nil
  end
  return { x = x + 0.0, y = y + 0.0, z = z + 0.0 }
end
local function smooth(v)
  v = clamp(v, 0.0, 1.0)
  return v * v * (3.0 - 2.0 * v)
end
local function ground(now)
  if groundZ ~= nil then
    return groundZ
  end
  if now >= nextGroundAt then
    nextGroundAt = now + MARKER_SETTINGS.groundInterval
    local p = target.pos
    local ok, found, z = pcall(GetGroundZFor_3dCoord, p.x + 0.0, p.y + 0.0, p.z + 3.0, false)
    if ok and nativeBoolean(found) and finite(z) and math.abs(z - p.z) <= 4.0 then
      groundZ = z + 0.0
    end
  end
  return groundZ or target.pos.z
end
local function marker(kind, p, z, sx, sy, sz, alpha, faceCamera)
  alpha = math.floor(clamp(alpha, 0, 255))
  if alpha <= 0 then
    return false
  end
  DrawMarker(
    kind,
    p.x + 0.0,
    p.y + 0.0,
    z + 0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    sx + 0.0,
    sy + 0.0,
    sz + 0.0,
    251,
    155,
    4,
    alpha,
    false,
    faceCamera == true,
    2,
    false,
    nil,
    nil,
    false
  )
  return true
end
local function licenseMarker(license)
  local id = type(license) == 'table' and license.id or license
  local icon = type(license) == 'table' and license.icon or nil
  if id == 'drive_bike' or icon == 'motorbike' or icon == 'bike' then
    return 37
  end
  if id == 'drive_truck' or icon == 'truck' then
    return 39
  end
  return 36
end
function markers.SetTarget(step, license)
  if targetReference == step and licenseReference == license then
    return
  end
  targetReference, licenseReference = step, license
  local pos = type(step) == 'table' and vector(step.pos)
  target = pos
      and {
        id = step.id,
        type = step.type,
        pos = pos,
        radius = step.radius,
        mapBay = step.mapBay == true,
        visual = step.visual,
        symbol = licenseMarker(license),
      }
    or nil
  groundZ, nextGroundAt, cachedDistance, nextDistanceAt = nil, 0, nil, 0
end
function markers.Clear()
  target, targetReference, licenseReference = nil, nil, nil
  groundZ, nextGroundAt, cachedDistance, nextDistanceAt = nil, 0, nil, 0
end
function markers.RouteDistance()
  if not target or target.type == 'engine' then
    return nil
  end
  local now = GetGameTimer()
  if now >= nextDistanceAt then
    nextDistanceAt = now + 500
    local available, found = pcall(GetGpsBlipRouteFound)
    if not available or not nativeBoolean(found) then
      cachedDistance = nil
    else
      local ok, value = pcall(GetGpsBlipRouteLength)
      cachedDistance = ok and finite(value) and value > 0 and value + 0.0 or nil
    end
  end
  return cachedDistance
end
function markers.Draw(vehicle, status, holdProgress, taskStatus)
  -- The HUD displays hold progress while the world marker remains stationary.
  if type(status) == 'table' then
    status = status.status
  end
  if
    not MARKER_SETTINGS.enabled
    or not target
    or target.type == 'engine'
    or (status ~= 'active' and status ~= 'finishing')
  then
    return false
  end
  if not finite(vehicle) or vehicle <= 0 or not nativeBoolean(DoesEntityExist(vehicle)) then
    return false
  end
  local ok, coords = pcall(GetEntityCoords, vehicle)
  local position = ok and vector(coords)
  if not position then
    return false
  end
  local p = target.pos
  local distance = math.sqrt((position.x - p.x) ^ 2 + (position.y - p.y) ^ 2 + (position.z - p.z) ^ 2)
  if distance >= MARKER_SETTINGS.drawDistance then
    return false
  end
  local far = smooth((MARKER_SETTINGS.drawDistance - distance) / MARKER_SETTINGS.fadeDistance)
  local alpha = 210 * far
  local scale = 2.0 + 1.5 * clamp(distance / MARKER_SETTINGS.drawDistance, 0.0, 1.0)
  local z = ground(GetGameTimer())
  local mapBay = target.mapBay and (target.type == 'park' or target.type == 'finish')
  local stop = target.type == 'stop' or target.type == 'finish'
  local near = (mapBay or stop) and smooth((distance - 2.0) / 6.0) or 1.0
  if mapBay then
    -- The map's actual painted bay remains visible and unobstructed.
    return marker(target.symbol, p, z + 3.0, scale, scale, scale, alpha * near, true)
  end
  local drawn = marker(0, p, z + 3.0, scale, scale, scale, alpha * near, false)
  if distance <= MARKER_SETTINGS.detailDistance and target.visual ~= false then
    if stop then
      local radius = finite(target.radius) and math.max(0.1, target.radius) or 5.0
      drawn = marker(25, p, z + 0.04, radius * 2.0, radius * 2.0, 0.12, 170 * far, false) or drawn
    elseif target.type == 'navigate' then
      -- This small cue denotes the target point, not the assessment boundary.
      drawn = marker(1, p, z + 0.03, 1.5, 1.5, 0.12, 145 * far, false) or drawn
    end
  end
  return drawn
end
