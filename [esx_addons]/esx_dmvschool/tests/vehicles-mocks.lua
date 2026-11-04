-- Server vehicle lifecycle checks using mocked OneSync boundaries.
local checks = 0
local function check(value, label)
  checks = checks + 1
  assert(value, label)
end

local function fixture()
  local world = {
    entities = {},
    requests = {},
    responses = {},
    timers = {},
    deleted = {},
    bucketWrites = 0,
    players = { [1] = { bucket = 0, health = 200 }, [2] = { bucket = 0, health = 200 } },
  }
  local env = setmetatable({}, { __index = _G })
  env.GetCurrentResourceName = function()
    return 'esx_dmvschool'
  end
  env.GetPlayerPed = function(id)
    return world.players[id] and 9000 + id or 0
  end
  env.GetPlayerRoutingBucket = function(id)
    return world.players[id] and world.players[id].bucket
  end
  env.GetEntityHealth = function(entity)
    local player = world.players[entity - 9000]
    return player and player.health or world.entities[entity] and world.entities[entity].health or 0
  end
  env.DoesEntityExist = function(entity)
    return world.entities[entity] ~= nil
  end
  env.GetEntityType = function(entity)
    return world.entities[entity] and world.entities[entity].type
  end
  env.GetEntityModel = function(entity)
    return world.entities[entity] and world.entities[entity].model
  end
  env.GetEntityCoords = function(entity)
    return world.entities[entity].pos
  end
  env.GetEntityRoutingBucket = function(entity)
    return world.entities[entity].bucket
  end
  env.SetEntityRoutingBucket = function(entity, bucket)
    world.bucketWrites = world.bucketWrites + 1
    if not world.failBucket then
      world.entities[entity].bucket = bucket
    end
  end
  env.NetworkGetEntityFromNetworkId = function(netId)
    for entity, value in pairs(world.entities) do
      if value.netId == netId then
        return entity
      end
    end
    return 0
  end
  env.GetAllVehicles = function()
    local result = {}
    for entity in pairs(world.entities) do
      result[#result + 1] = entity
    end
    table.sort(result)
    return result
  end
  env.DeleteEntity = function(entity)
    world.deleted[#world.deleted + 1] = entity
    world.entities[entity] = nil
  end
  env.joaat = function(model)
    return ({ blista = 123, sanchez = 456, mule3 = 789 })[model] or 999
  end
  env.vector3 = function(x, y, z)
    return { x = x, y = y, z = z }
  end
  env.SetTimeout = function(ms, callback)
    world.timers[#world.timers + 1] = { ms = ms, callback = callback }
  end
  env.Entity = function(entity)
    return {
      state = setmetatable({
        set = function(_, key, value, replicated)
          if world.failIdentity and key == 'esx_dmvschool:vehicleLease' then
            error('identity state unavailable')
          end
          if world.failFuel and key == 'fuel' then
            error('fuel state unavailable')
          end
          world.entities[entity].state[key] = value
          world.entities[entity].replication[key] = replicated
        end,
      }, {
        __index = function(_, key)
          return world.entities[entity].state[key]
        end,
      }),
    }
  end
  env.ESX = {
    OneSync = {
      SpawnVehicle = function(model, coords, heading, props, callback, kind)
        if world.throwSpawn then
          error('spawn provider failure')
        end
        world.requests[#world.requests + 1] = {
          model = model,
          coords = coords,
          heading = heading,
          props = props,
          callback = callback,
          kind = kind,
        }
      end,
    },
  }
  function world.vehicle(entity, netId, options)
    options = options or {}
    world.entities[entity] = {
      netId = netId,
      model = options.model or 123,
      bucket = options.bucket or 0,
      pos = options.pos or { x = 0, y = 0, z = 0 },
      health = options.health or 1000,
      type = options.type or 2,
      occupied = options.occupied,
      state = {},
      replication = {},
    }
    return entity
  end
  function world.resolve(index, options)
    local request = world.requests[index]
    options = options or {}
    if options.failed then
      request.callback(false)
      return
    end
    local entity, netId = options.entity or 500 + index, options.netId or 100 + index
    options.model = options.model or env.joaat(request.model)
    options.pos = options.pos or request.coords
    world.vehicle(entity, netId, options)
    request.callback(netId)
    return entity, netId
  end
  function world.reply(netId, value)
    world.responses[#world.responses + 1] = { netId = netId, value = value }
  end
  function world.timeout()
    local timers = world.timers
    world.timers = {}
    for _, timer in ipairs(timers) do
      timer.callback()
    end
  end
  assert(load(VehiclesSource, '@server/vehicles.lua', 't', env))()
  world.api = env.ESXDMVVehicles
  return world
end

local function license(model, id)
  return {
    id = id or 'drive',
    model = model or 'blista',
    spawn = { x = 0, y = 0, z = 0, w = 317 },
    dimensions = { width = 1.76, length = 4.11 },
  }
end

local world = fixture()
world.api.Create(1, license(), 'one', world.reply)
check(#world.requests == 1 and #world.responses == 0, 'creation is asynchronous and requested once')
check(
  world.requests[1].heading == 317 and world.requests[1].kind == 'automobile',
  'spawn heading and vehicle type match config'
)
check(world.requests[1].props.plate == 'EXAM', 'server initializes examination plate')
local entity, netId = world.resolve(1)
check(
  world.responses[1].netId == netId and world.responses[1].value == entity,
  'callback reports only the created entity'
)
check(
  world.entities[entity].replication['esx_dmvschool:vehicleLease'] == false
    and type(world.entities[entity].state['esx_dmvschool:vehicleLease']) == 'string',
  'entity identity remains a non-replicated server value'
)
check(
  world.entities[entity].state.fuel == 100.0 and math.type(world.entities[entity].state.fuel) == 'float',
  'server initializes fuel as a Lua float before returning the vehicle'
)
check(world.entities[entity].replication.fuel == true, 'fuel state is replicated to the eventual owner before entry')
local valid, matched = world.api.Matches('one', 1, netId)
check(valid and matched == entity, 'assigned session and player match the exact entity')
check(not world.api.Matches('one', 2, netId), 'another player cannot use the lease')
check(
  not world.api.Matches('two', 1, netId) and not world.api.Matches('one', 1, netId + 1),
  'session and network identity are checked'
)
world.api.Create(1, license(), 'one', world.reply)
check(
  #world.requests == 1 and world.responses[2].netId == netId,
  'ready duplicate returns the original lease without another spawn'
)
world.timeout()
check(world.api.Matches('one', 1, netId) and #world.responses == 2, 'resolved lease ignores the pending-spawn timeout')
check(world.api.Remove('one') and world.entities[entity] == nil, 'cleanup removes the assigned server entity')
check(not world.api.Remove('one') and #world.deleted == 1, 'cleanup is idempotent')

world = fixture()
world.vehicle(60, 600, { occupied = true })
world.api.Create(1, license(), 'blocked', world.reply)
check(
  #world.requests == 0 and world.responses[1].value == 'spawn_blocked',
  'occupied spawn area blocks before creation'
)
check(world.entities[60] and #world.deleted == 0, 'blocking non-assigned vehicle is never removed')
world.entities[60].bucket = 8
world.api.Create(1, license(), 'clear-other-bucket', world.reply)
check(#world.requests == 1, 'a vehicle in another bucket does not block the departure')

world = fixture()
world.api.Create(1, license(), 'pending', world.reply)
world.api.Create(1, license(), 'pending', world.reply)
check(#world.requests == 1 and world.responses[1].value == 'busy', 'pending duplicate never creates a second vehicle')
world.api.Create(2, license(), 'collision', world.reply)
check(
  #world.requests == 1 and world.responses[2].value == 'spawn_blocked',
  'pending spawn reservation avoids concurrent overlap'
)
world.players[2].bucket = 8
world.api.Create(2, license('sanchez', 'drive_bike'), 'separate', world.reply)
check(
  #world.requests == 2 and world.requests[2].kind == 'bike',
  'motorcycle and separate bucket get an independent spawn'
)
local separateEntity, separateId = world.resolve(2)
check(
  world.entities[separateEntity].bucket == 8 and world.api.Matches('separate', 2, separateId),
  'created vehicle enters the captured player bucket'
)

world = fixture()
world.api.Create(1, license(), 'cancelled', world.reply)
world.api.Cancel('cancelled')
check(#world.responses == 1 and world.responses[1].value == 'invalid_session', 'pending cancellation answers once')
entity = world.resolve(1)
check(
  not world.entities[entity] and #world.deleted == 1 and #world.responses == 1,
  'late spawn after cancellation is removed without a second response'
)

world = fixture()
world.api.Create(1, license(), 'slow', world.reply)
world.timeout()
check(
  #world.responses == 1 and world.responses[1].value == 'spawn_failed',
  'unresolved provider is bounded by a timeout'
)
entity = world.resolve(1)
check(
  not world.entities[entity] and #world.responses == 1,
  'timed-out late vehicle is cleaned and cannot revive its lease'
)

world = fixture()
world.api.Create(1, license(), 'dead', world.reply)
world.players[1].health = 0
entity = world.resolve(1)
check(
  world.responses[1].value == 'invalid_session' and not world.entities[entity],
  'death during creation invalidates the late spawn'
)
world.api.Create(1, license(), 'dead-request', world.reply)
check(
  #world.requests == 1 and world.responses[2].value == 'invalid_session',
  'an incapacitated player cannot request a new vehicle'
)

world = fixture()
world.api.Create(1, license(), 'bucket-change', world.reply)
world.players[1].bucket = 7
entity = world.resolve(1)
check(
  world.responses[1].value == 'invalid_session' and not world.entities[entity],
  'bucket switch while pending cancels the original spawn'
)
world = fixture()
world.api.Create(1, license(), 'bucket-bound', world.reply)
entity, netId = world.resolve(1)
world.players[1].bucket = 7
check(not world.api.Matches('bucket-bound', 1, netId), 'a live lease cannot move between player buckets')
world.players[1].bucket = 0
world.entities[entity].bucket = 7
check(not world.api.Matches('bucket-bound', 1, netId), 'the vehicle must also remain in the assigned bucket')

world = fixture()
world.api.Create(1, license(), 'reuse', world.reply)
entity, netId = world.resolve(1)
world.vehicle(entity, netId, { occupied = true })
check(
  not world.api.Matches('reuse', 1, netId),
  'fresh entity with recycled handle/network ID has no matching server identity'
)
check(
  not world.api.Remove('reuse') and world.entities[entity] and #world.deleted == 0,
  'cleanup never removes the occupied replacement entity'
)

world = fixture()
world.api.Create(1, license(), 'mapping', world.reply)
entity, netId = world.resolve(1)
world.entities[entity].netId = 700
check(
  not world.api.Matches('mapping', 1, netId) and not world.api.Remove('mapping'),
  'changed network mapping is rejected without deletion'
)
world = fixture()
world.api.Create(1, license(), 'model', world.reply)
entity, netId = world.resolve(1)
world.entities[entity].model = 456
check(
  not world.api.Matches('model', 1, netId) and not world.api.Remove('model'),
  'model replacement cannot become a cleanup target'
)

world = fixture()
world.api.Create(1, license(), 'arriving-blocker', world.reply)
world.vehicle(80, 800, { occupied = true })
entity = world.resolve(1)
check(
  world.responses[1].value == 'spawn_blocked' and not world.entities[entity],
  'arrival collision rejects and removes only the new examination vehicle'
)
check(
  world.entities[80] and #world.deleted == 1 and world.deleted[1] == entity,
  'late blocking vehicle remains untouched'
)

world = fixture()
world.api.Create(1, license(), 'failed', world.reply)
world.resolve(1, { failed = true })
check(
  world.responses[1].value == 'spawn_failed' and #world.deleted == 0,
  'failed provider returns a failure without deleting anything'
)
world.api.Create(1, license(), 'failed', world.reply)
check(#world.requests == 2, 'provider failure releases the reservation')
world.throwSpawn = true
world.api.Create(2, { model = 'blista', spawn = { x = 100, y = 0, z = 0, w = 0 } }, 'throw', world.reply)
check(world.responses[2].value == 'spawn_failed', 'synchronous provider failure is handled')

world = fixture()
world.api.Create(1, license(), 'wrong-type', world.reply)
entity = world.resolve(1, { type = 1, occupied = true })
check(
  world.responses[1].value == 'spawn_failed' and world.entities[entity] and #world.deleted == 0,
  'invalid provider identity is rejected and never adopted for deletion'
)
world = fixture()
world.api.Create(1, { model = 'blista', spawn = { x = 0 / 0, y = 0, z = 0 } }, 'invalid', world.reply)
check(
  #world.requests == 0 and world.responses[1].value == 'invalid_session',
  'invalid coordinate data fails before provider call'
)

world = fixture()
world.players[1].bucket = 8
world.failBucket = true
world.api.Create(1, license(), 'bucket-failure', world.reply)
entity = world.resolve(1)
check(
  not world.entities[entity] and world.responses[1].value == 'spawn_failed',
  'failed bucket assignment cannot return a ready vehicle'
)
world = fixture()
world.failFuel = true
world.api.Create(1, license(), 'fuel-failure', world.reply)
entity = world.resolve(1)
check(
  not world.entities[entity] and world.responses[1].value == 'spawn_failed',
  'unavailable initial fuel state cleans the assigned entity and fails preparation'
)
world = fixture()
world.failIdentity = true
world.api.Create(1, license(), 'identity-failure', world.reply)
entity = world.resolve(1)
check(
  not world.entities[entity] and world.responses[1].value == 'spawn_failed',
  'initial identity-state failure removes only the just-created entity'
)

world = fixture()
world.api.Create(1, license(), 'disconnect', world.reply)
world.players[1] = nil
entity = world.resolve(1)
check(
  not world.entities[entity] and world.responses[1].value == 'invalid_session',
  'disconnect while awaiting spawn cannot leave an adopted vehicle'
)
world = fixture()
world.api.Create(1, license(), 'reused-session', world.reply)
world.api.Cancel('reused-session')
world.api.Create(1, license(), 'reused-session', world.reply)
local replacement, replacementId = world.resolve(2)
entity = world.resolve(1)
check(
  not world.entities[entity] and world.entities[replacement] and world.api.Matches('reused-session', 1, replacementId),
  'late cancelled request cannot remove a later lease that reused the session string'
)

print(('server vehicle leases: %d assertions passed'):format(checks))
return checks
