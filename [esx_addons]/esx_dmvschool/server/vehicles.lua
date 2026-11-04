-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

ESXDMVVehicles = {}
local vehicles = ESXDMVVehicles
local leases = {}
local LEASE_KEY = GetCurrentResourceName() .. ':vehicleLease'
local SPAWN_TIMEOUT = 10000

local function finite(value)
  return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end

local function validLicense(license)
  local spawn = type(license) == 'table' and license.spawn
  return spawn
    and finite(spawn.x)
    and finite(spawn.y)
    and finite(spawn.z)
    and (spawn.w == nil or finite(spawn.w))
    and (type(license.model) == 'string' or finite(license.model))
end

local function radius(license)
  local length = license.dimensions and license.dimensions.length
  return finite(length) and math.max(4.0, length / 2 + 1.5) or 4.0
end

local function distanceSquared(first, second)
  return (first.x - second.x) ^ 2 + (first.y - second.y) ^ 2 + (first.z - second.z) ^ 2
end

local function spawnClear(spawn, bucket, clearance, exclude)
  for _, entity in ipairs(GetAllVehicles()) do
    if
      entity ~= exclude
      and DoesEntityExist(entity)
      and GetEntityRoutingBucket(entity) == bucket
      and distanceSquared(GetEntityCoords(entity), spawn) <= clearance ^ 2
    then
      return false
    end
  end
  for _, lease in pairs(leases) do
    if
      not lease.entity
      and lease.bucket == bucket
      and distanceSquared(lease.spawn, spawn) <= (lease.clearance + clearance) ^ 2
    then
      return false
    end
  end
  return true
end

local function playerAvailable(lease)
  local ped = GetPlayerPed(lease.playerId)
  return ped and ped > 0 and GetEntityHealth(ped) > 0 and GetPlayerRoutingBucket(lease.playerId) == lease.bucket
end

local function sameHandle(lease)
  if
    not lease.entity
    or not lease.netId
    or not DoesEntityExist(lease.entity)
    or NetworkGetEntityFromNetworkId(lease.netId) ~= lease.entity
    or GetEntityType(lease.entity) ~= 2
    or GetEntityModel(lease.entity) ~= lease.model
  then
    return false
  end
  return true
end

local function sameEntity(lease)
  if not sameHandle(lease) then
    return false
  end
  -- Keep the identity local to the server so recycled handles cannot become cleanup targets.
  local ok, identity = pcall(function()
    return Entity(lease.entity).state[LEASE_KEY]
  end)
  return ok and identity == lease.identity
end

local function removeEntity(lease)
  if not sameEntity(lease) then
    return false
  end
  DeleteEntity(lease.entity)
  return true
end

local function finish(lease, netId, entityOrError)
  if lease.finished then
    return
  end
  lease.finished = true
  lease.callback(netId, entityOrError)
end

local function invalidate(session, reason)
  local lease = leases[session]
  if not lease then
    return false
  end
  leases[session], lease.cancelled = nil, true
  local deleted = removeEntity(lease)
  finish(lease, nil, reason or 'invalid_session')
  return deleted
end

---@param playerId number
---@param license table
---@param session string
---@param callback fun(netId: number|nil, entityOrError: number|string)
function vehicles.Create(playerId, license, session, callback)
  if type(callback) ~= 'function' then
    return
  end
  if
    not finite(playerId)
    or playerId <= 0
    or playerId ~= math.floor(playerId)
    or type(session) ~= 'string'
    or session == ''
    or not validLicense(license)
  then
    return callback(nil, 'invalid_session')
  end
  local current = leases[session]
  if current then
    if current.playerId ~= playerId then
      return callback(nil, 'invalid_session')
    end
    local valid, entity = vehicles.Matches(session, playerId, current.netId)
    if valid then
      return callback(current.netId, entity)
    end
    return callback(nil, current.entity and 'invalid_vehicle' or 'busy')
  end
  local lease = {
    playerId = playerId,
    bucket = GetPlayerRoutingBucket(playerId),
    spawn = { x = license.spawn.x, y = license.spawn.y, z = license.spawn.z },
    clearance = radius(license),
    model = type(license.model) == 'number' and license.model or joaat(license.model),
    callback = callback,
    identity = ('%08x%08x'):format(math.random(0, 2147483647), math.random(0, 2147483647)),
  }
  if not playerAvailable(lease) then
    return callback(nil, 'invalid_session')
  end
  if not spawnClear(lease.spawn, lease.bucket, lease.clearance) then
    return callback(nil, 'spawn_blocked')
  end
  leases[session] = lease
  SetTimeout(SPAWN_TIMEOUT, function()
    if leases[session] == lease and not lease.finished then
      invalidate(session, 'spawn_failed')
    end
  end)
  local ok = pcall(
    ESX.OneSync.SpawnVehicle,
    license.model,
    vector3(lease.spawn.x, lease.spawn.y, lease.spawn.z),
    license.spawn.w or 0,
    { plate = 'EXAM' },
    function(netId)
      local entity = finite(netId) and netId > 0 and NetworkGetEntityFromNetworkId(netId) or 0
      if
        not entity
        or entity == 0
        or not DoesEntityExist(entity)
        or GetEntityType(entity) ~= 2
        or GetEntityModel(entity) ~= lease.model
      then
        if leases[session] == lease then
          leases[session] = nil
        end
        return finish(lease, nil, 'spawn_failed')
      end
      lease.entity, lease.netId = entity, netId
      local identified = pcall(function()
        Entity(entity).state:set(LEASE_KEY, lease.identity, false)
      end)
      if not identified then
        if leases[session] == lease then
          leases[session] = nil
        end
        if sameHandle(lease) then
          DeleteEntity(entity)
        end
        return finish(lease, nil, 'spawn_failed')
      end
      if leases[session] ~= lease or lease.cancelled or not playerAvailable(lease) then
        if leases[session] == lease then
          leases[session] = nil
        end
        removeEntity(lease)
        return finish(lease, nil, 'invalid_session')
      end
      SetEntityRoutingBucket(entity, lease.bucket)
      if not sameEntity(lease) or GetEntityRoutingBucket(entity) ~= lease.bucket then
        leases[session] = nil
        removeEntity(lease)
        return finish(lease, nil, 'spawn_failed')
      end
      if not spawnClear(lease.spawn, lease.bucket, lease.clearance, entity) then
        leases[session] = nil
        removeEntity(lease)
        return finish(lease, nil, 'spawn_blocked')
      end
      local fuelReady = pcall(function()
        Entity(entity).state:set('fuel', 100.0, true)
      end)
      if not fuelReady then
        leases[session] = nil
        removeEntity(lease)
        return finish(lease, nil, 'spawn_failed')
      end
      finish(lease, netId, entity)
    end,
    license.vehicleType or (license.id == 'drive_bike' and 'bike' or 'automobile')
  )
  if not ok and leases[session] == lease then
    invalidate(session, 'spawn_failed')
  end
end

---@return boolean valid, number? entity
function vehicles.Matches(session, playerId, netId)
  local lease = leases[session]
  if
    not lease
    or lease.cancelled
    or lease.playerId ~= playerId
    or lease.netId ~= netId
    or GetPlayerRoutingBucket(playerId) ~= lease.bucket
    or not sameEntity(lease)
    or GetEntityRoutingBucket(lease.entity) ~= lease.bucket
  then
    return false
  end
  return true, lease.entity
end

function vehicles.Cancel(session)
  return invalidate(session, 'invalid_session')
end

function vehicles.Remove(session)
  return invalidate(session, 'invalid_session')
end
