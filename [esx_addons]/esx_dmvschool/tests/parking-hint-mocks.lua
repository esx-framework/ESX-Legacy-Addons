-- SPDX-License-Identifier: GPL-3.0-only
-- Pure presentation hints. The evaluator itself remains authoritative.
local E=ESXDMVEvaluation
local checks=0
local function check(value,label) checks=checks+1;assert(value,label) end
local function snapshot(values)
    local result={x=0.0,y=0.0,z=0.0,heading=0.0,driving=true,vehicleWidth=2.72,vehicleLength=8.08}
    for k,v in pairs(values or {}) do result[k]=v end
    return result
end
local bay={type='park',pos={x=0.0,y=0.0,z=0.0},width=3.6,length=9.2,heading=0.0,headingTolerance=14}
check(E.ParkingHint(bay,snapshot({heading=340.0}),'heading')=='parking_turn_left','positive GTA heading change turns left')
check(E.ParkingHint(bay,snapshot({heading=20.0}),'heading')=='parking_turn_right','negative GTA heading change turns right')
check(E.ParkingHint(bay,snapshot({heading=359.0}),'heading')=='parking_turn_left','left hint wraps north')
check(E.ParkingHint(bay,snapshot({heading=1.0}),'heading')=='parking_turn_right','right hint wraps north')
check(E.ParkingHint(bay,snapshot(),'heading')==nil,'no hint for zero heading error')
local angled=snapshot({heading=20.0})
check(not E.FootprintFits(bay,angled),'long truck footprint fails before heading')
check(E.ParkingHint(bay,angled,'footprint')=='parking_turn_right','misaligned footprint gives a useful turn hint')
check(angled.heading==20.0 and angled.x==0.0 and angled.y==0.0,'hint never mutates the input snapshot')
check(E.ParkingHint(bay,snapshot({heading=340.0}),'footprint')=='parking_turn_left','footprint hint uses signed left turn')
check(E.ParkingHint(bay,snapshot({x=4.0,heading=20.0}),'footprint')==nil,'rotation cannot solve a vehicle outside the bay')
check(E.ParkingHint(bay,snapshot({heading=2.0}),'footprint')==nil,'small two-degree footprint error gets no turn coaching')
check(E.ParkingHint(bay,snapshot({heading=20.0,x=13.0}),'heading')==nil,'far vehicle gets no parking hint')
check(E.ParkingHint(bay,snapshot({heading=20.0,driving=false}),'heading')==nil,'passenger gets no hint')
for _,reason in ipairs({'ready','speed','reverse','driver','position'}) do
    check(E.ParkingHint(bay,snapshot({heading=20.0}),reason)==nil,'existing feedback retained for '..reason)
end
local finish={type='finish',pos=bay.pos,width=3.6,length=9.2,heading=0.0}
check(E.ParkingHint(finish,angled,'footprint')=='parking_turn_right','finish supports the same parking geometry')
local stop={type='stop',pos=bay.pos,width=3.6,length=9.2,heading=0.0}
check(E.ParkingHint(stop,angled,'heading')==nil,'ordinary stop never receives parking coaching')
check(E.ParkingHint({type='park',pos=bay.pos,width=3.6,length=9.2},angled,'heading')==nil,'missing heading disables hint')
check(E.ParkingHint({type='park',pos=bay.pos,heading=0.0},angled,'heading')==nil,'missing bay dimensions disable hint')
check(E.ParkingHint(bay,snapshot({heading=0/0}),'heading')==nil,'invalid heading is rejected')
local nested=snapshot({pos={x=0.0,y=0.0,z=0.0},heading=20.0})
check(E.ParkingHint(bay,nested,'footprint')=='parking_turn_right' and nested.pos.x==0.0,'nested positions remain unchanged')
local offset=snapshot({heading=20.0,footprintOffset={x=0.0,y=-.2193}})
check(E.ParkingHint(bay,offset,'footprint')=='parking_turn_right' and offset.footprintOffset.y==-.2193,'footprint offset is reused without mutation')
local mule={type='park',pos={x=243.731,y=-1415.683,z=29.586},width=3.6,length=9.2,heading=326.57}
local parked=snapshot({x=243.7307,y=-1415.6829,z=30.8193,heading=326.5726,vehicleWidth=2.718561,vehicleLength=8.077482})
check(E.ParkingHint(mule,parked,'ready')==nil,'measured parked Mule keeps existing ready feedback')
local before={}
for key,value in pairs(bay) do before[key]=value end
E.ParkingHint(bay,angled,'footprint')
local unchanged=true
for key,value in pairs(before) do unchanged=unchanged and bay[key]==value end
check(unchanged,'configuration remains immutable')
print(('parking hints: %d functional assertions passed'):format(checks))
return checks
