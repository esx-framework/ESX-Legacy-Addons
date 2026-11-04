-- Functional native-marker contract fixture. Supply MarkerSource externally.
local checks=0
local function check(value,label) checks=checks+1;assert(value,label) end
local function fixture(settings)
    local w={time=0,position={x=100.0,y=100.0,z=20.0},markers={},groundCalls=0,lengthCalls=0,
        groundFound=1,groundHeight=20.0,exists=1,length=1200.0,routeFound=1}
    local env=setmetatable({Config={Markers=settings or {}}},{__index=_G})
    env.GetGameTimer=function() return w.time end
    env.DoesEntityExist=function() return w.exists end
    env.GetEntityCoords=function() return w.position end
    env.GetGroundZFor_3dCoord=function(x,y,z)
        w.groundCalls=w.groundCalls+1
        w.groundArguments={x,y,z}
        return w.groundFound,w.groundHeight
    end
    env.GetGpsBlipRouteLength=function()
        w.lengthCalls=w.lengthCalls+1
        if w.lengthError then error('GPS length unavailable') end
        return w.length
    end
    env.GetGpsBlipRouteFound=function()
        if w.routeFoundError then error('GPS route unavailable') end
        return w.routeFound
    end
    env.DrawMarker=function(...) w.markers[#w.markers+1]=table.pack(...) end
    for _,name in ipairs({'CreateThread','CreateVehicle','CreateObject','DrawPoly','DrawLine',
        'GetPosAlongGpsTypeRoute','GetGpsWaypointRouteEnd'}) do
        env[name]=function() error('forbidden marker dependency: '..name) end
    end
    assert(load(MarkerSource,'client/markers.lua','t',env))()
    w.api=env.ESXDMVMarkers
    function w.draw(time,status)
        w.time=time or w.time;w.markers={}
        return w.api.Draw(100,status or 'active',.5,'ready')
    end
    return w,env
end
local function nativeContract(args)
    local floats,integers=true,true
    for i=2,13 do floats=floats and math.type(args[i])=='float' end
    for i=14,17 do integers=integers and math.type(args[i])=='integer' end
    return args.n==24 and floats and integers and args[14]==251 and args[15]==155 and args[16]==4
        and args[18]==false and type(args[19])=='boolean' and args[20]==2 and args[21]==false
        and args[22]==nil and args[23]==nil and args[24]==false
end
local nav={id='route',type='navigate',pos={x=200.0,y=100.0,z=20.0},radius=20}
local stop={id='stop',type='stop',pos={x=200.0,y=100.0,z=20.0},radius=7,visual=true}
local bay={id='park',type='park',pos={x=200.0,y=100.0,z=20.0},width=4.2,length=8.0,mapBay=true}
local w=fixture();w.api.SetTarget(nav,{id='drive'})
check(w.draw(0) and #w.markers==1 and w.markers[1][1]==0,'far target uses exactly one native cone')
check(nativeContract(w.markers[1]),'cone ABI uses float coordinates/scales and stable native flags')
check(w.markers[1][4]==23.0 and w.markers[1][11]>2.0 and w.markers[1][11]<3.5,'cone sits three metres above ground and scales with distance')
check(w.markers[1][17]==210 and w.markers[1][19]==false,'cone is matte orange with no camera rotation or temporal animation')
w.position={x=160.0,y=100.0,z=20.0};w.draw(16)
check(#w.markers==2 and w.markers[2][1]==1 and w.markers[2][11]==1.5,'near navigation adds only a small low cue')
check(nativeContract(w.markers[2]) and math.abs(w.markers[2][4]-20.03)<1e-9,'navigation cue preserves float native contract')
check(w.groundCalls==1,'valid ground remains cached across frames')
w.draw(5000)
check(w.groundCalls==1,'valid ground does not resample over time')
w.position={x=-30.0,y=100.0,z=20.0};w.draw(5010)
check(#w.markers==1 and w.markers[1][17]>0 and w.markers[1][17]<210,'last thirty-five metres fade the far cone')
w.position={x=-50.0,y=100.0,z=20.0}
check(not w.draw(5020) and #w.markers==0,'draw-distance cutoff is enforced')
w.position={x=160.0,y=100.0,z=20.0};w.api.SetTarget(stop,'drive');w.draw(5030)
check(#w.markers==2 and w.markers[2][1]==25,'stop uses a native horizontal ring')
check(w.markers[2][11]==14.0 and w.markers[2][12]==14.0 and math.abs(w.markers[2][4]-20.04)<1e-9,'ring diameter matches evaluated circular radius exactly')
check(nativeContract(w.markers[2]),'stop ring has no rotation, bobbing or texture')
w.position={x=199.0,y=100.0,z=20.0};w.draw(5040)
check(#w.markers==1 and w.markers[1][1]==25,'near stop hides elevated cone without hiding its assessment ring')
for _,license in ipairs({{id='drive',type=36},{id='drive_bike',type=37},{id='drive_truck',type=39}}) do
    w.position={x=160.0,y=100.0,z=20.0};w.api.SetTarget(bay,license);w.draw(5050)
    check(#w.markers==1 and w.markers[1][1]==license.type and nativeContract(w.markers[1]),'map bay shows only its correct vehicle symbol: '..license.id)
end
w.position={x=195.0,y=100.0,z=20.0};w.draw(5060)
check(#w.markers==1 and w.markers[1][17]>0 and w.markers[1][17]<210,'bay icon fades near the driver')
w.position={x=199.0,y=100.0,z=20.0}
check(not w.draw(5070) and #w.markers==0,'bay icon disappears inside two metres')
local finish={id='finish',type='finish',pos=bay.pos,mapBay=true,radius=8}
w.position={x=160.0,y=100.0,z=20.0};w.api.SetTarget(finish,'drive');w.draw(5080)
check(#w.markers==1 and w.markers[1][1]==36,'map-bay finish adds no ground graphics')
check(not w.draw(5090,'spawning') and not w.draw(5100,'cancelling'),'preparation/cancellation render no target')
check(w.draw(5110,'finishing'),'server-confirmation phase can retain the target')
local retry=fixture();retry.groundFound=0;retry.api.SetTarget(nav,'drive');retry.draw(0)
check(retry.markers[1][4]==23.0,'unavailable ground uses the authored target height')
retry.draw(999);check(retry.groundCalls==1,'ground failure retries no faster than one second')
retry.groundFound=true;retry.groundHeight=21.0;retry.draw(1000)
check(retry.groundCalls==2 and retry.markers[1][4]==24.0,'ground retry accepts Lua true and caches the valid result')
retry.draw(9000);check(retry.groundCalls==2,'successful retry stays stable')
local levels=fixture();levels.groundHeight=80.0;levels.api.SetTarget(nav,'drive');levels.draw(0)
check(levels.markers[1][4]==23.0,'a different bridge level cannot replace the authored height')
local boolean=fixture();boolean.exists=true;boolean.groundFound=true;boolean.api.SetTarget(nav,'drive')
check(boolean.draw(0),'native true works alongside numeric one')
local gps=fixture();gps.api.SetTarget(nav,'drive')
check(gps.api.RouteDistance()==1200.0 and gps.lengthCalls==1,'HUD route distance reads only GPS length')
gps.time=499;gps.api.RouteDistance();check(gps.lengthCalls==1,'GPS length is cached for five hundred milliseconds')
gps.time=500;gps.length=1100.0
check(gps.api.RouteDistance()==1100.0 and gps.lengthCalls==2,'GPS length refreshes after cache expiry')
gps.time=1000;gps.length=0/0;check(gps.api.RouteDistance()==nil,'NaN length is rejected')
gps.time=1500;gps.length=math.huge;check(gps.api.RouteDistance()==nil,'infinite length is rejected')
gps.time=2000;gps.lengthError=true;check(gps.api.RouteDistance()==nil,'unavailable GPS length is optional')
gps.api.Clear();check(not gps.draw(2010) and gps.api.RouteDistance()==nil,'clear removes target and GPS distance')
for _,found in ipairs({0,false}) do
    local unavailable=fixture();unavailable.api.SetTarget(nav,'drive')
    check(unavailable.api.RouteDistance()==1200.0,'initial valid route is cached before recalculation')
    unavailable.routeFound=found;unavailable.time=500
    check(unavailable.api.RouteDistance()==nil and unavailable.lengthCalls==1,'false or zero route availability clears stale length without reading it')
    unavailable.routeFound=true;unavailable.time=1000
    check(unavailable.api.RouteDistance()==1200.0 and unavailable.lengthCalls==2,'boolean true route availability permits a fresh length')
end
local missingRoute,missingEnv=fixture();missingRoute.api.SetTarget(nav,'drive');missingEnv.GetGpsBlipRouteFound=nil
check(missingRoute.api.RouteDistance()==nil and missingRoute.lengthCalls==0,'missing availability native fails closed before reading length')
local blockedRoute=fixture();blockedRoute.api.SetTarget(nav,'drive');blockedRoute.routeFoundError=true
check(blockedRoute.api.RouteDistance()==nil and blockedRoute.lengthCalls==0,'failing availability native never reads stale length')
local disabled=fixture({enabled=false});disabled.api.SetTarget(nav,'drive')
check(not disabled.draw(0) and disabled.groundCalls==0,'disabled markers do not draw or query ground')
local engine=fixture();engine.api.SetTarget({id='prepare',type='engine',pos=nav.pos},'drive')
check(not engine.draw(0) and engine.api.RouteDistance()==nil,'engine preparation has no world marker or GPS query')
print(('native markers: %d functional assertions passed'):format(checks))
return checks
