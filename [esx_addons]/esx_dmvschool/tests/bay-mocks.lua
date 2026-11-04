-- SPDX-License-Identifier: GPL-3.0-only
-- Offline calibration checks for the surveyed native car/motorcycle bay.
-- Load the current DMV Config and shared evaluator before this file.
-- No natives, entity placement or license grants are performed.
local E, checks = assert(ESXDMVEvaluation), 0
local function check(value, label) checks = checks + 1; assert(value, label) end
local function close(a,b,epsilon) return math.abs(a-b) <= (epsilon or 0.001) end
local function find(items, predicate)
    for _, value in ipairs(items) do if predicate(value) then return value end end
    error('Required DMV calibration fixture not found')
end
local car = find(Config.Licenses, function(value) return value.id == 'drive' end)
local bike = find(Config.Licenses, function(value) return value.id == 'drive_bike' end)
local carRoute, bikeRoute = Config.Routes[car.route], Config.Routes[bike.route]
local park = find(carRoute, function(value) return value.type == 'park' end)
local finish = carRoute[#carRoute]
local bikePark = find(bikeRoute, function(value) return value.type == 'park' end)
local bikeFinish = bikeRoute[#bikeRoute]
local h = math.rad(park.heading)
local forward, right = {x=-math.sin(h),y=math.cos(h)}, {x=math.cos(h),y=math.sin(h)}
local function point(lateral, longitudinal)
    return {x=park.pos.x+right.x*lateral+forward.x*longitudinal,
            y=park.pos.y+right.y*lateral+forward.y*longitudinal,z=park.pos.z}
end
local function baseSnapshot(position, heading, width, length)
    return {x=position.x,y=position.y,z=position.z,heading=heading,speed=0,
        driving=true,engine=true,onGround=true,airborne=false,forwardSpeed=0,
        vehicleWidth=width,vehicleLength=length}
end
local function paired(lateral, longitudinal, heading)
    heading = heading or park.heading
    local centre = point(lateral or 0,longitudinal or 0)
    -- Client already projects GetModelDimensions' centre into world space.
    local client = baseSnapshot(centre,heading,1.7587,4.1014)
    -- Server sees the entity origin and applies the configured local XY offset.
    local offset, angle = car.dimensions.offset, math.rad(heading)
    local origin = {x=centre.x-offset.x*math.cos(angle)+offset.y*math.sin(angle),
        y=centre.y-offset.x*math.sin(angle)-offset.y*math.cos(angle),z=centre.z}
    local server = baseSnapshot(origin,heading,car.dimensions.width,car.dimensions.length)
    server.footprintOffset = offset
    return client,server
end
local function sameBox(a,b)
    return close(a.pos.x,b.pos.x) and close(a.pos.y,b.pos.y) and close(a.pos.z,b.pos.z)
        and close(a.width,b.width) and close(a.length,b.length) and close(a.heading,b.heading)
end
check(close(park.pos.x,237.577) and close(park.pos.y,-1411.856) and close(park.pos.z,29.586)
    and close(park.heading,326.43) and close(park.width,3.2) and close(park.length,4.6)
    and close(car.dimensions.offset.x,0) and close(car.dimensions.offset.y,0.088),
    'surveyed native bay and Blista centre offset remain calibrated')
local client,server = paired(0,0)
check(E.FootprintFits(park,client) and E.FootprintFits(park,server),
    'centred stock Blista fits both real client bounds and server origin plus offset')
-- If the entity origin is 0.22 m ahead, its box centre is 0.308 m ahead.
-- Omitting the 0.088 m model offset would incorrectly accept this case.
local tooFarCentre = 0.22 + car.dimensions.offset.y
client,server = paired(0,tooFarCentre)
check(not E.FootprintFits(park,client) and not E.FootprintFits(park,server),
    'forward model-centre offset prevents accepting a body over the painted end')
client,server = paired(0.9,0)
check(not E.FootprintFits(park,client) and not E.FootprintFits(park,server),
    'body beyond the painted side is rejected by client and server')
client,server = paired(0,0.4)
check(not E.FootprintFits(park,client) and not E.FootprintFits(park,server),
    'body beyond the common painted line ends is rejected')
client,server = paired(0,0,park.heading+50)
check(not E.FootprintFits(park,client) and not E.FootprintFits(park,server),
    'rotated Blista crossing a painted side fails footprint geometry')
local captured = baseSnapshot({x=237.8272,y=-1411.3193,z=29.5856838},326.2767,
    car.dimensions.width,car.dimensions.length)
captured.footprintOffset = car.dimensions.offset
local ahead = (captured.x-park.pos.x)*forward.x+(captured.y-park.pos.y)*forward.y
check(close(ahead,0.585,0.005) and not E.FootprintFits(park,captured),
    'captured Blista 0.585 m ahead is outside the longitudinal bay limit')
check(sameBox(park,finish) and sameBox(park,bikePark) and sameBox(park,bikeFinish)
    and park.mapBay and finish.mapBay and bikePark.mapBay and bikeFinish.mapBay,
    'car and motorcycle park/finish share the surveyed box without a relocation')
client = paired(0,0)
-- Reverse-entry evidence is a prior-step fixture: generic motion/reverse
-- accumulation has separate evaluator tests. This test isolates bay holds.
local tracking = {reverseDistance=2.1,reverseEntry=true}
E.Evaluate(park,client,tracking,1000)
local parked = E.Evaluate(park,client,tracking,1000+park.hold)
local finishTracking = {}
E.Evaluate(finish,client,finishTracking,5000)
local completed = E.Evaluate(finish,client,finishTracking,5000+finish.hold)
check(parked and completed and close(client.x,park.pos.x) and close(client.y,park.pos.y),
    'car can complete park and finish holds at exactly the same fixed position')
local motorcycle = baseSnapshot(park.pos,bikePark.heading,bike.dimensions.width,bike.dimensions.length)
tracking = {}
E.Evaluate(bikePark,motorcycle,tracking,1000)
parked = E.Evaluate(bikePark,motorcycle,tracking,1000+bikePark.hold)
finishTracking = {}
E.Evaluate(bikeFinish,motorcycle,finishTracking,5000)
completed = E.Evaluate(bikeFinish,motorcycle,finishTracking,5000+bikeFinish.hold)
check(parked and completed and close(motorcycle.x,bikeFinish.pos.x) and close(motorcycle.y,bikeFinish.pos.y),
    'motorcycle can complete both holds in the same painted bay without moving')
print(('native bay calibration: %d assertions passed'):format(checks))
return checks
