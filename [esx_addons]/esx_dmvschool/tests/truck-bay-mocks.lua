-- SPDX-License-Identifier: GPL-3.0-only
-- Stock Mule3 pose captured in FiveM. This fixture does not run the game.
local E, checks = ESXDMVEvaluation, 0
local function check(value,label) checks=checks+1;assert(value,label) end
local license
for _,entry in ipairs(Config.Licenses) do if entry.id=='drive_truck' then license=entry end end
local route=Config.Routes[license.route]
local park,finish,approach=route[#route-1],route[#route],route[#route-2]
local function copy(value) local out={};for k,v in pairs(value) do out[k]=v end;return out end
local current={x=243.730712890625,y=-1415.682861328125,z=30.8192634583,heading=326.572631836,
    vehicleWidth=2.718561411,vehicleLength=8.077481747,driving=true,speed=0.0,forwardSpeed=0.0}
local server=copy(current)
server.x,server.y,server.z=243.8515319824,-1415.4998779297,30.8193740845
server.vehicleWidth,server.vehicleLength=license.dimensions.width,license.dimensions.length
server.footprintOffset=license.dimensions.offset
check(E.FootprintFits(park,current),'captured client Mule footprint fits the selected location')
check(E.FootprintFits(park,server),'captured server Mule footprint includes the real model-centre offset')
check(E.Distance(park.pos,finish.pos)==0 and park.heading==finish.heading,'confirmation does not move the target or heading')
check(park.width==finish.width and park.length==finish.length and park.mapBay and finish.mapBay,'park and confirmation share the same map area')
local tracking={reverseDistance=2.1,reverseEntry=true}
E.Evaluate(park,server,tracking,0)
check(E.Evaluate(park,server,tracking,3000),'real parked server pose completes the hold after valid reverse entry')
tracking={};E.Evaluate(finish,server,tracking,0)
check(E.Evaluate(finish,server,tracking,2000),'confirmation accepts the identical unmoved server pose')
local wrong=copy(server);wrong.heading=(park.heading+180)%360
local passed,_,detail=E.Evaluate(park,wrong,{},0)
check(not passed and detail.reason=='heading','wrong-way cab orientation cannot pass')
local angle=math.rad(park.heading)
local side=copy(current);side.x=park.pos.x+math.cos(angle)*.6;side.y=park.pos.y+math.sin(angle)*.6
check(not E.FootprintFits(park,side),'crossing the lateral parking envelope is rejected')
local endOver=copy(current);endOver.x=park.pos.x-math.sin(angle)*.8;endOver.y=park.pos.y+math.cos(angle)*.8
check(not E.FootprintFits(park,endOver),'a bumper beyond the longitudinal envelope is rejected')
local edge=copy(server);edge.heading=park.heading
edge.x=park.pos.x-math.sin(angle)*.66;edge.y=park.pos.y+math.cos(angle)*.66
local without=copy(edge);without.footprintOffset=nil
check(E.FootprintFits(park,edge) and not E.FootprintFits(park,without),'negative model-centre offset prevents a false boundary rejection')
local dx,dy=approach.pos.x-park.pos.x,approach.pos.y-park.pos.y
check(-dx*math.sin(angle)+dy*math.cos(angle)>7,'approach is ahead of the cab in the aisle')
check(math.abs(dx*math.cos(angle)+dy*math.sin(angle))<.5,'approach aligns with the selected parking space')
check(E.Distance(approach.pos,{x=244,y=-1424,z=29.1})>10 and approach.radius<=5,'old sidewalk-corner approach is replaced by a precise aisle target')
local noReverse=copy(server)
passed,_,detail=E.Evaluate(park,noReverse,{},0)
check(not passed and detail.reason=='reverse','calibration does not bypass the reverse manoeuvre')
print(('truck bay calibration: %d assertions passed'):format(checks))
return checks
