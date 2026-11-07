// SPDX-License-Identifier: GPL-3.0-only
const fs=require('fs'),path=require('path');
const f=require('fengari');
const resourceRoot=path.resolve(process.env.ESX_QA_RESOURCE_ROOT || path.join(__dirname,'..'));
const source=fs.readFileSync(path.join(resourceRoot,'server/main.lua'),'utf8');
const evaluator=fs.readFileSync(path.join(resourceRoot,'shared/evaluator.lua'),'utf8');
const theory=fs.readFileSync(path.join(resourceRoot,'server/theory.lua'),'utf8');
function luaLiteral(value) {
 let marker='=';
 while(value.includes(']'+marker+']'))marker+='=';
 return '['+marker+'['+value+']'+marker+']';
}
const questionSources='QuestionSources={'+fs.readdirSync(path.join(resourceRoot,'server/questions'))
 .filter(name=>name.endsWith('.lua')).map(name=>'[ '+luaLiteral(name.slice(0,-4))+' ]='+luaLiteral(fs.readFileSync(path.join(resourceRoot,'server/questions',name),'utf8'))).join(',')+'}\n';
const limiterPath=process.env.ESX_QA_RATE_LIMITER;
const limiterSource=limiterPath?fs.readFileSync(limiterPath,'utf8'):null;
const results=[];
function run(name, tests, {fallback=false,rateLimiter=false}={}) {
 const L=f.lauxlib.luaL_newstate();f.lualib.luaL_openlibs(L);
 const program=mock+questionSources+(fallback?'\nxLib.callback=nil;ESXCatalog=nil\n':'\n')+
  (rateLimiter?'\nxLib.rateLimiter=assert(load('+luaLiteral(limiterSource)+'))()\n':'')+theory+evaluator+source+'\n'+tests+'\nreturn Checks';
 let status=f.lauxlib.luaL_loadstring(L,f.to_luastring(program));
 if(status===0)status=f.lua.lua_pcall(L,0,f.lua.LUA_MULTRET,0);
 if(status!==0)throw Error(name+': '+f.to_jsstring(f.lua.lua_tostring(L,-1)));
 const count=f.lua.lua_tonumber(L,-1);results.push({name,assertions:count,passed:true});console.log(name+': PASS ('+count+')');
}
const mock=`
Checks=0
function check(value,message) Checks=Checks+1;assert(value,message) end
Clock=1000
function GetGameTimer() return Clock end
function GetCurrentResourceName() return 'esx_dmvschool' end
function GetConvar() return 'es' end
function GetConvarInt(_,fallback) return fallback end
function Translate(key,...) return key end
TheoryBanksAvailable=true
function LoadResourceFile(resource,name)
 assert(resource=='esx_dmvschool')
 if not TheoryBanksAvailable then return nil end
 local locale=name:match('^server/questions/([a-z0-9%-]+)%.lua$')
 return locale and QuestionSources[locale]
end
Timers,Threads,Handlers,Callbacks,ClientEvents,Queries,Catalog={}, {}, {}, {}, {}, {}, {}
function SetTimeout(ms,fn) Timers[#Timers+1]={ms=ms,fn=fn} end
function runTimer(ms) for i=#Timers,1,-1 do if Timers[i].ms==ms then local t=table.remove(Timers,i);t.fn();return end end error('missing timer '..ms) end
CatalogRows,CatalogRefreshes,SuppressCatalogRefresh={},0,false
function CreateThread(fn)
 Threads[#Threads+1]=coroutine.create(fn)
 if #Threads>1 then local ok,err=coroutine.resume(Threads[#Threads]);assert(ok,err) end
end
function Wait(ms) coroutine.yield(ms) end
function stepThread(index)
 local thread=index==2 and Threads[#Threads] or Threads[index]
 if not thread or (index==2 and #Threads<2) or coroutine.status(thread)=='dead' then return end
 local ok,err=coroutine.resume(thread);assert(ok,err)
end
function AddEventHandler(name,fn) Handlers[name]=Handlers[name] or {};table.insert(Handlers[name],fn) end
function RegisterNetEvent(name,fn) if fn then AddEventHandler(name,fn) end end
function fire(name,...) for _,fn in ipairs(Handlers[name] or {}) do fn(...) end end
function net(name,...) source=1;fire('esx_dmvschool:'..name,...);source=nil end
function TriggerClientEvent(name,id,data) ClientEvents[#ClientEvents+1]={name=name,id=id,data=data} end
PeerActive,PeerStarted=false,false
Exported={}
exports=setmetatable({}, {__call=function(_,name,fn) Exported[name]=fn end,__index=function() return {IsExamActive=function() return PeerActive end} end})
function GetResourceState() return PeerStarted and 'started' or 'missing' end
function joaat(model) return model=='blista' and 1234 or 9999 end
Pos={x=0,y=0,z=0};Velocity={x=0,y=0,z=0};Heading=0
PedHealth,BodyHealth,EngineHealth,EngineRunning=200,1000,1000,true
EntityExists,InVehicle,Driver,Model,EntityType=true,true,true,1234,2
Identifier,Present,Money,RemovedMoney,GrantCount='char1:account',true,50000,0,0
Owned={};DeferLicenses,DeferGrant,GrantFailure=false,false,false
PendingLicenseQueries,PendingGrantQueries={},{}
function GetPlayerPed(id) return Present and id or 0 end
function GetEntityCoords() return Pos end
function GetEntityHeading() return Heading end
function GetEntityVelocity() return Velocity end
function GetEntityHealth() return PedHealth end
function DoesEntityExist(id) return EntityExists and (id==100 or id==101) end
function NetworkGetEntityFromNetworkId(id) return id==10 and 100 or id==11 and 101 or 0 end
function GetEntityType() return EntityType end
function GetEntityModel() return Model end
function GetVehiclePedIsIn() return InVehicle and 100 or 0 end
function GetPedInVehicleSeat() return Driver and 1 or 2 end
function GetVehicleBodyHealth() return BodyHealth end
function GetVehicleEngineHealth() return EngineHealth end
function GetIsVehicleEngineRunning() return EngineRunning end
Deleted,DeletedEntities=0,{}
function DeleteEntity(entity) Deleted=Deleted+1;DeletedEntities[#DeletedEntities+1]=entity;EntityExists=false end
PlayerBucket,VehicleBucket=0,0
VehicleLeases,VehicleRequested,CancelledVehicleSessions={}, {}, {}
VehicleSpawnCount,DeferVehicle,SpawnBlocked=0,false,false
PendingVehicleCallbacks={}
ESXDMVVehicles={
 Create=function(playerId,license,session,cb)
  local current=VehicleLeases[session]
  if current then return cb(current.netId,current.entity) end
  if SpawnBlocked then return cb(nil,'spawn_blocked') end
  VehicleSpawnCount=VehicleSpawnCount+1
  local function spawn()
   if CancelledVehicleSessions[session] then return cb(nil,'invalid_session') end
   EntityExists=true
   VehicleLeases[session]={playerId=playerId,netId=10,entity=100,bucket=PlayerBucket}
   VehicleBucket=PlayerBucket
   cb(10,100)
  end
  if DeferVehicle then PendingVehicleCallbacks[#PendingVehicleCallbacks+1]=spawn else spawn() end
 end,
 Matches=function(session,playerId,netId)
  local lease=VehicleLeases[session]
  if not lease or lease.playerId~=playerId or lease.netId~=netId or not EntityExists
   or NetworkGetEntityFromNetworkId(netId)~=lease.entity or PlayerBucket~=lease.bucket or VehicleBucket~=lease.bucket then return false end
  return true,lease.entity
 end,
 Remove=function(session)
  CancelledVehicleSessions[session]=true
  local lease=VehicleLeases[session]
  VehicleLeases[session]=nil
  if lease and EntityExists and NetworkGetEntityFromNetworkId(lease.netId)==lease.entity then DeleteEntity(lease.entity);return true end
  return false
 end
}
ESXDMVVehicles.Cancel=ESXDMVVehicles.Remove
RejectDebit,DebitCalls,RefundedMoney=false,0,0
local xPlayer={
 getIdentifier=function() return Identifier end,
 getMoney=function() return Money end,
 removeMoney=function(amount)
  assert(amount>0,'zero debit is invalid in ESX')
  DebitCalls=DebitCalls+1
  if RejectDebit then return false end
  Money=Money-amount;RemovedMoney=RemovedMoney+amount
  return true
 end,
 addMoney=function(amount)
  Money=Money+amount;RefundedMoney=RefundedMoney+amount
  return true
 end
}
ESX={Player=function(id) if Present and id==1 then return xPlayer end end,GetPlayerFromId=function(id) if Present and id==1 then return xPlayer end end,RegisterServerCallback=function(name,fn) Callbacks[name]=fn end}
xLib={
 callback={registerCompat=ESX.RegisterServerCallback},
 rateLimiter=function() return {consume=function() return true end,reset=function() end} end,
}
ESXCatalog={awaitReady=function() end}
MySQL={ready=function(fn) fn() end,query={await=function(query,params) Queries[#Queries+1]=query;CatalogRows[#CatalogRows+1]={type=params[1],label=params[2]} end}}
function licenseList() local t={};for name,exists in pairs(Owned) do if exists then t[#t+1]={type=name} end end;return t end
function TriggerEvent(name,id,licenseType,cb)
 if name=='esx_license:getLicenses' then local fn=function() licenseType(licenseList()) end;if DeferLicenses then PendingLicenseQueries[#PendingLicenseQueries+1]=fn else fn() end
 elseif name=='esx_license:addLicense' then GrantCount=GrantCount+1;local fn=function() if not GrantFailure then Owned[licenseType]=true end;cb(not GrantFailure) end;if DeferGrant then PendingGrantQueries[#PendingGrantQueries+1]=fn else fn() end
 elseif name=='esx_license:getLicensesList' then id(Catalog)
 elseif name=='esx:sqlCatalogReady' then
  CatalogRefreshes=CatalogRefreshes+1
  if not SuppressCatalogRefresh then Catalog=CatalogRows end
 else fire(name,id,licenseType,cb) end
end
function call(name,...) local response;Callbacks['esx_dmvschool:'..name](1,function(a,b) response={a,b} end,...);return response end
function createVehicle(session) return call('createVehicle',session)[1] end
function begin(session,id)
 if not VehicleRequested[session] then
  local result=createVehicle(session)
  if result and result.ok then VehicleRequested[session]=true end
 end
 return call('beginPractical',session,id or 10)[1]
end
function advance(session,index) return call('advancePractical',session,index)[1] end
function complete(session) return call('completePractical',session)[1] end
function cancelRequest(license,session,request) return call('cancelTest',license,session,request or 'request')[1] end
Purchases={}
function pay(license,request)
 local result=call('canYouPay',license,request or 'request')
 if result and result[1] then Purchases[result[2].session]=result[2].theory end
 return result
end
function submit(session,answers) return call('submitTheory',session,answers)[1] end
function answersFor(session,correctCount)
 local exam=assert(Purchases[session],'missing purchased question payload')
 local bank=assert(load(QuestionSources[exam.locale or Config.Locale]))()
 local answers={}
 for index,question in ipairs(exam.questions) do
  local correct=bank[question.id].correct
  answers[index]=index<=correctCount and correct or (correct+1)%4
 end
 return answers
end
function tick(ms)
 local remaining=ms or 200
 while remaining>0 do
  local elapsed=math.min(remaining,250)
  Clock=Clock+elapsed;stepThread(2);remaining=remaining-elapsed
 end
end
function setpos(x,y,z) Pos={x=x or 0,y=y or 0,z=z or 0} end
function vel(x,y,z) Velocity={x=x or 0,y=y or 0,z=z or 0} end
function driveTo(x,y,z)
 local from=Pos
 local dx,dy,dz=x-from.x,(y or 0)-from.y,(z or 0)-from.z
 local distance=math.sqrt(dx*dx+dy*dy+dz*dz)
 if distance>0 then
  local steps=math.ceil(distance/2)
  vel(dx*5/steps,dy*5/steps,dz*5/steps)
  for step=1,steps do
   setpos(from.x+dx*step/steps,from.y+dy*step/steps,from.z+dz*step/steps)
   tick(200)
  end
 end
 vel()
end
function lastState() for i=#ClientEvents,1,-1 do local e=ClientEvents[i];if e.name=='esx_dmvschool:practicalState' then return e.data end end end
function start(license) setpos(0);Owned.dmv=license~='dmv';local p=pay(license);check(p and p[1],'fixture purchase '..license);return p[2].session end
function stopReady(session) driveTo(10);advance(session,2);tick(500);tick(500);return advance(session,2) end
function parkReady(session)
 driveTo(20,2.25);advance(session,3);vel(0,-1)
 for i=1,9 do setpos(20,2.25-i*0.25);tick(250) end
 vel();advance(session,3);tick(500);tick(500);return advance(session,3)
end
function finishReady(session)
 driveTo(30);check(advance(session,4).ok,'fixture navigation');driveTo(40);EngineRunning=false;advance(session,5);tick(500);tick(500);return advance(session,5)
end
Config={Locale='es',SpeedMultiplier=3.6,MaxErrors=5,ExamTimeout=1200000,SpeedTolerance=5,SpeedingGrace=2500,DamageThreshold=20,DamageCooldown=2000,AbandonTimeout=20000,
 School={menu={x=0,y=0,z=0}},SchoolResources={'esx_dmvschool','esx_boatschool'},
 Licenses={{id='dmv',kind='theory',price=500,label='theory',bank='road',questionCount=10,answersNeeded=5},{id='drive',kind='practical',price=2500,label='car',requires='dmv',model='blista',spawn={x=0,y=0,z=0,w=0},route='car',dimensions={width=2.2,length=4.8}}},
 Routes={car={
 {id='engine',type='engine',pos={x=0,y=0,z=0},label='engine'},
 {id='stop',type='stop',pos={x=10,y=0,z=0},radius=3,hold=1000,limit=50,label='stop'},
 {id='park',type='park',pos={x=20,y=0,z=0},width=5,length=10,heading=0,hold=1000,requireReverse=true,label='park'},
 {id='road',type='navigate',pos={x=30,y=0,z=0},radius=5,limit=50,label='road'},
 {id='finish',type='finish',pos={x=40,y=0,z=0},radius=3,heading=0,hold=1000,engineOff=true,label='return'}}}}
`;
run('purchase, catalog, permissions, refresh',`
check(pay('dmv')[2].error=='unavailable','catalog must be ready')
stepThread(1)
check(#Queries==2,'one additive catalog row per license')
for _,query in ipairs(Queries) do check(query:match('^INSERT IGNORE INTO licenses')~=nil,'catalog never alters or deletes grants') end
check(Exported.IsExamActive(1)==false,'no active exam')
check(pay('bad')[2].error=='invalid_license','unknown license')
check(pay('dmv','')[2].error=='invalid_session','invalid request identity')
setpos(100);check(pay('dmv')[2].error=='not_near_school','school proximity');setpos(0)
Money=200;check(pay('dmv')[2].error=='not_enough_money' and RemovedMoney==0,'real balance');Money=50000
check(pay('drive')[2].error=='theory_required','real prerequisite')
PeerActive,PeerStarted=true,true;check(pay('dmv')[2].error=='busy','other school active');PeerActive=false
DeferLicenses=true
check(pay('dmv','a')==nil and Exported.IsExamActive(1),'pending exported active')
check(pay('dmv','b')[2].error=='busy' and RemovedMoney==0,'single-flight debit')
check(cancelRequest('dmv',nil,'a').ok,'cancel pending purchase')
table.remove(PendingLicenseQueries,1)();check(RemovedMoney==0,'late canceled query cannot debit')
local response;Callbacks['esx_dmvschool:canYouPay'](1,function(a,b) response={a,b} end,'dmv','c');runTimer(7000);table.remove(PendingLicenseQueries,1)()
check(response[2].error=='timeout' and RemovedMoney==0,'payment timeout')
Callbacks['esx_dmvschool:canYouPay'](1,function(a,b) response={a,b} end,'dmv','d');Identifier='char2:account';table.remove(PendingLicenseQueries,1)()
check(response[2].error=='unavailable' and RemovedMoney==0,'same-character purchase recheck');Identifier='char1:account'
DeferLicenses=false
local p=pay('dmv');check(p[1] and RemovedMoney==500,'single real charge')
local noGlobalNotify=true;for _,event in ipairs(ClientEvents) do if event.name=='esx:showNotification' then noGlobalNotify=false end end
check(noGlobalNotify,'payment feedback stays inside the school interface')
local session=p[2].session
check(pay('dmv')[2].error=='busy' and RemovedMoney==500,'active ticket no duplicate charge')
net('addLicense','dmv','wrong');check(GrantCount==0,'wrong session cannot grant')
net('addLicense','drive',session);check(GrantCount==0,'theory ticket cannot grant practical')
net('addLicense','dmv',session);check(GrantCount==0,'legacy event cannot bypass server grading')
check(p[2].theory.correctAnswers==nil and p[2].theory.questions[1].correct==nil,'initial payload hides answer keys')
check(submit(session,{score=10,passed=true,total=10}).error=='invalid_result' and GrantCount==0,'client score cannot grant theory')
setpos(100);check(submit(session,answersFor(session,10)).error=='not_near_school','theory proximity retained');setpos(0)
local graded=submit(session,answersFor(session,10));check(graded.ok and graded.score==10 and graded.passed and graded.confirmed,'server grades the actual paid question set')
check(submit(session,answersFor(session,0)).score==10 and GrantCount==1 and Owned.dmv,'theory grant and grade consumed once')
check(call('getLicenses')[1][1].type=='dmv','actual owned refresh')
check(pay('dmv')[2].error=='already_owned' and RemovedMoney==500,'owned no charge')
check(cancelRequest('drive','forged').ok==false,'forged cancellation rejected')
`);
run('ordered practical and true parking/continuous hold',`
stepThread(1)
local session=start('drive')
check(complete(session).error=='incomplete_route','cannot complete before route')
net('addLicense','drive',session);check(GrantCount==0,'legacy event cannot grant practical')
check(begin('forged').error=='invalid_session','forged begin')
check(begin(session,math.huge).error=='invalid_vehicle','nonfinite network id')
Model=9999;check(begin(session).error=='invalid_vehicle','wrong model');Model=1234
EntityType=1;check(begin(session).error=='invalid_vehicle','ped is not vehicle');EntityType=2
setpos(100);check(begin(session).error=='invalid_vehicle','vehicle must spawn near assigned point');setpos(0)
Driver=false;check(begin(session).error=='vehicle_not_ready','requires assigned driver');Driver=true
check(begin(session).ok,'bind assigned vehicle')
check(begin(session).duplicate,'begin same entity idempotent')
check(begin(session,11).error=='invalid_vehicle','cannot replace bound vehicle')
check(advance(session,2).error=='invalid_step','cannot skip ordered task')
EngineRunning=false;check(advance(session,1).error=='step_not_ready','actual engine required');EngineRunning=true
check(advance(session,1).ok,'engine task accepted')
check(advance(session,1).duplicate,'duplicate task does not advance again')
check(advance(session,2).error=='step_not_ready','cannot pass stop from wrong position')
driveTo(10);vel(2,0);check(advance(session,2).error=='step_not_ready','moving stop rejected')
vel();check(advance(session,2).error=='step_not_ready','hold starts, not instant')
tick(500);setpos(15);tick(200);setpos(10);tick(200);tick(500)
check(advance(session,2).error=='step_not_ready','leaving resets continuous hold');tick(500)
check(advance(session,2).ok,'continuous stationary stop')
driveTo(20);tick(1500);check(advance(session,3).error=='step_not_ready','parking requires actual reverse history')
setpos(20,2.25);advance(session,3);vel(0,-1);for i=1,9 do setpos(20,2.25-i*0.25);tick(250) end;vel();Heading=90;tick(1200)
check(advance(session,3).error=='step_not_ready','parking wrong orientation rejected')
Heading=0;setpos(22);tick(1200);check(advance(session,3).error=='step_not_ready','whole footprint must fit, not center distance')
check(parkReady(session).ok,'parking geometry and hold accepted after a new reverse manoeuvre')
check(complete(session).error=='incomplete_route','remaining road tasks required')
check(finishReady(session).ok,'return stopping task accepted')
driveTo(50);check(complete(session).error=='step_not_ready','cannot leave finish before confirmation');driveTo(40);advance(session,5);tick(1000)
local result=complete(session)
check(result.ok and result.passed and result.confirmed and Owned.drive and result.error==nil,'completion confirmed from actual grant without error')
check(GrantCount==1,'one practical grant')
check(complete(session).confirmed and GrantCount==1,'repeated complete returns prior result')
check(Exported.IsExamActive(1)==false,'completed releases active state')
`);
run('checkpoint jumps cannot earn distance by waiting, callback replay or leaving the seat',`
stepThread(1)
local checkpoint=Config.Routes.car[2]
checkpoint.pos,checkpoint.type,checkpoint.hold={x=100,y=0,z=0},'navigate',0
local session=start('drive');begin(session);advance(session,1)
tick(3000)
setpos(100)
check(advance(session,2).error=='step_not_ready','teleport to the next checkpoint is rejected after an idle period')
for i=1,15 do advance(session,2) end
check(advance(session,2).error=='step_not_ready','same-timestamp callback replay creates no movement credit')
tick(1400)
check(advance(session,2).error=='step_not_ready','waiting at the rejected checkpoint cannot establish a new baseline')
Driver=false;tick(250);Driver=true;tick(250)
check(advance(session,2).error=='step_not_ready' and GrantCount==0,'waiting and changing seat cannot adopt the teleported position')
setpos(0);tick(200)
check(Exported.IsExamActive(1),'a transient jump can recover at the last trusted position')
driveTo(100)
check(advance(session,2).ok,'the recovered session accepts observed travel to the same checkpoint')
`);
run('non-finite and persistent impossible movement fail closed',`
stepThread(1)
local session=start('drive');createVehicle(session)
setpos(0/0)
check(call('beginPractical',session,10)[1].error=='invalid_vehicle','non-finite spawn position cannot initialize the baseline')
setpos(0);vel(math.huge)
check(call('beginPractical',session,10)[1].error=='vehicle_not_ready','non-finite velocity cannot initialize the baseline')
vel(100)
check(call('beginPractical',session,10)[1].error=='vehicle_not_ready','implausible native speed cannot initialize the baseline')
vel();check(begin(session).ok and advance(session,1).ok,'valid native snapshot can bind after an invalid one')
setpos(1000)
check(advance(session,2).error=='step_not_ready','large displacement blocks the current task')
tick(2200);Driver=false;tick(1000);Driver=true
setpos(0/0);tick(1000);setpos(1000);Heading=math.huge;tick(1000)
check(lastState().aborted and lastState().reason=='server_rejected','missing driver and malformed samples cannot reset a persistent rejection')
check(VehicleLeases[session]==nil and Deleted==1 and not Exported.IsExamActive(1) and GrantCount==0,
 'terminal movement rejection removes the leased vehicle without granting')
`);
run('normal batched updates pass and long observation gaps restart a hold',`
stepThread(1)
local session=start('drive');begin(session);advance(session,1)
vel(25,0);tick(200);setpos(10);tick(200);vel()
check(advance(session,2).error=='step_not_ready','a batched position update reaches the stop but does not skip its hold')
tick(400)
Clock=Clock+1300;stepThread(2)
check(advance(session,2).error=='step_not_ready' and Exported.IsExamActive(1),
 'a valid stationary sample after a long observation gap resets the hold without rejecting the attempt')
tick(1000)
check(advance(session,2).ok,'normal hold completes after the observation gap')
`);
run('driver loss clears the current reverse proof',`
stepThread(1)
local session=start('drive');begin(session);advance(session,1);stopReady(session)
driveTo(20,2.25);advance(session,3);vel(0,-1)
for i=1,9 do setpos(20,2.25-i*0.25);tick(250) end
vel();tick(250);Driver=false;tick(250);Driver=true;tick(1250)
check(advance(session,3).error=='step_not_ready','old reverse travel cannot survive losing the driver seat')
check(parkReady(session).ok,'a newly observed reverse manoeuvre can complete the parking task')
`);
run('independent incidents, grace, deduplication and strict threshold',`
stepThread(1);local session=start('drive');begin(session);advance(session,1);driveTo(10);vel(0,20)
tick(200);tick(2000);check((lastState() or {}).errors==nil,'short overspeed grace')
tick(600);check(lastState().errors==1 and lastState().incidents[1].reason=='speeding','sustained speeding recorded')
tick(6000);check(lastState().errors==1,'continuous overspeed is one incident')
local r=call('reportIncident',session,'speeding',2)[1];check(r.errors==1,'client report cannot duplicate sampler')
check(call('reportIncident',session,'invented',2)[1].error=='invalid_incident','reason allowlist')
check(call('reportIncident',session,'damage',4)[1].error=='invalid_incident','incident cannot forge task index')
vel();tick(200);BodyHealth=990;tick(200);check(lastState().errors==1,'small health variation tolerated')
for i=1,3 do BodyHealth=BodyHealth-30;tick(2100) end
check(lastState().errors==4,'three significant damage episodes')
check(call('reportIncident',session,'damage',2)[1].errors==4,'damage notification cannot count twice')
check(stopReady(session).ok,'route can proceed with four errors');check(parkReady(session).ok,'parking after four errors');check(finishReady(session).ok,'finish after four errors')
check(complete(session).passed and GrantCount==1,'four errors passes strict <5')
`);
run('fifth error denies license, binding/identity/timeout cleanup',`
stepThread(1);local session=start('drive');begin(session);advance(session,1);driveTo(10)
for i=1,5 do BodyHealth=BodyHealth-30;tick(2100) end
check(lastState().failed and lastState().errors==5,'fifth error fails')
check(not Exported.IsExamActive(1) and not VehicleLeases[session],'the server ends a failed attempt and removes its lease')
check(coroutine.status(Threads[2])=='dead','terminal failure stops practical monitoring')
check(advance(session,2).error=='invalid_session','failed attempt cannot advance')
local result=complete(session)
check(result.ok and not result.passed and not result.confirmed and result.reason=='damage'
 and result.errors==5 and #result.incidents==5 and GrantCount==0,'terminal failure retains the five incidents without a grant')
EngineRunning=true;EntityExists=true;session=start('drive');begin(session);Identifier='char2:account'
check(advance(session,1).error=='invalid_session','cannot transfer ticket to another character');Identifier='char1:account';cancelRequest('drive',session)
session=start('drive');begin(session);Driver=false;tick(200);tick(20001)
check(lastState().aborted and lastState().reason=='abandoned','driver absence times out')
check(cancelRequest('drive',session).cancelled,'terminal cancel acknowledged for safe return');Driver=true
session=start('drive');begin(session);PedHealth=0;tick(200)
check(lastState().reason=='death' and GrantCount==0,'death abort');PedHealth=200
session=start('drive');begin(session);EntityExists=false;tick(200)
check(lastState().reason=='vehicle_destroyed','missing assigned entity abort');EntityExists=true
session=start('drive');begin(session);tick(1200001)
check(lastState().reason=='timeout','session timeout abort')
check(not complete(session).passed,'timeout cannot complete')
fire('esx:playerDropped',1);check(Deleted>=1 and not Exported.IsExamActive(1),'drop cleans tracked vehicle and locks')
`);
run('grant in flight, confirmed ownership and database failure',`
stepThread(1);local session=start('drive');begin(session);advance(session,1);stopReady(session);parkReady(session);finishReady(session)
DeferGrant=true
local first,second
Callbacks['esx_dmvschool:completePractical'](1,function(r) first=r end,session)
Callbacks['esx_dmvschool:completePractical'](1,function(r) second=r end,session)
check(first==nil and second==nil and GrantCount==1,'duplicate completion joins one pending grant')
setpos(0);check(pay('drive')[2].error=='busy','cannot recharge while grant pending')
table.remove(PendingGrantQueries,1)()
check(first.confirmed and second.confirmed and Owned.drive,'both completions require actual owned grant')
check(GrantCount==1,'grant still once')
`);
run('gradual damage episode baseline and cooldown',`
stepThread(1);local session=start('drive');begin(session);advance(session,1);driveTo(10)
BodyHealth=990;tick(200);check(call('reportIncident',session,'damage',2)[1].errors==0,'10 damage below threshold')
BodyHealth=980;tick(200);check(lastState().errors==1,'two gradual 10-point losses accumulate to incident')
BodyHealth=970;tick(200);BodyHealth=960;tick(200);check(lastState().errors==1,'same impact does not stack during cooldown')
tick(2100);check(call('reportIncident',session,'damage',2)[1].errors==1,'remaining health loss not counted again after cooldown')
BodyHealth=950;tick(200);BodyHealth=940;tick(200);check(lastState().errors==2,'separate later gradual incident accumulates')
`);
run('failed database grant is never optimistic or repeated',`
stepThread(1);local session=start('drive');begin(session);advance(session,1);stopReady(session);parkReady(session);finishReady(session)
GrantFailure=true;local result=complete(session)
check(result.ok==false and result.confirmed==false and not Owned.drive,'failed DB grant never confirms')
check(GrantCount==1 and not Exported.IsExamActive(1),'failed grant consumes ticket and releases busy')
check(complete(session).confirmed==false and GrantCount==1,'failed grant repeat does not insert again')
`);
run('logout and resource stop invalidate late grant callbacks',`
stepThread(1);local session=start('drive');begin(session);advance(session,1);stopReady(session);parkReady(session);finishReady(session)
DeferGrant=true;local response
Callbacks['esx_dmvschool:completePractical'](1,function(r) response=r end,session)
fire('esx:playerLogout',1);table.remove(PendingGrantQueries,1)()
check(response.error=='invalid_session','late logout grant callback rejected')
check(complete(session).error=='invalid_session','logout callback cannot recreate completed state')
check(not Exported.IsExamActive(1) and Deleted==1,'logout cleans pending-grant vehicle')
EntityExists=true;Owned.drive=false;EngineRunning=true;DeferGrant=false;session=start('drive');begin(session);advance(session,1);stopReady(session);parkReady(session);finishReady(session)
DeferGrant=true;Callbacks['esx_dmvschool:completePractical'](1,function(r) response=r end,session)
fire('onResourceStop','esx_dmvschool');table.remove(PendingGrantQueries,1)()
check(response.error=='invalid_session' and not Exported.IsExamActive(1),'stop invalidates late grant and lock')
check(Deleted==2,'stop cleans pending-grant vehicle')
`);
run('driver loss breaks the final continuous hold',`
stepThread(1);local session=start('drive');begin(session);advance(session,1);stopReady(session);parkReady(session);finishReady(session)
Driver=false;tick(200);Driver=true
check(complete(session).error=='step_not_ready','driver loss resets final hold after route acceptance')
tick(500);tick(500)
check(complete(session).confirmed,'returning driver must hold again before grant')
`);
run('numeric native engine booleans stay strict at the boundary',`
stepThread(1);local session=start('drive');begin(session)
EngineRunning=0;check(advance(session,1).error=='step_not_ready','native number 0 means engine stopped')
EngineRunning=2;check(advance(session,1).error=='step_not_ready','other numbers do not mean true')
EngineRunning='1';check(advance(session,1).error=='step_not_ready','native string is not a boolean')
EngineRunning=1;check(advance(session,1).ok,'native number 1 means running and accepts preparation')
stopReady(session);parkReady(session);finishReady(session);EngineRunning=0
check(complete(session).confirmed,'native number 0 satisfies engine-off final condition')
`);
run('server theory thresholds, review and consumed attempts',`
stepThread(1)
local payment=pay('dmv');local session=payment[2].session
check(payment[2].theory.questionCount==10 and payment[2].theory.answersNeeded==5,'server sends configured theory rules')
local seen={}
for _,question in ipairs(payment[2].theory.questions) do
 check(not seen[question.id] and type(question.text)=='string' and #question.answers==4,'assigned public question is unique and complete')
 check(question.correct==nil and question.reponse==nil and question.correctAnswers==nil,'question payload cannot expose its grading key')
 seen[question.id]=true
end
local result=submit(session,answersFor(session,4))
check(result.ok and result.kind=='theory' and result.license=='dmv' and result.score==4 and not result.passed and not result.confirmed,'four correct answers fail on server')
check(#result.correctAnswers==10 and GrantCount==0 and not Owned.dmv,'failed review returns corrections without granting')
check(not Exported.IsExamActive(1),'graded failure releases the exam lock')
check(submit(session,answersFor(session,10)).score==4 and GrantCount==0,'failed attempt cannot be resubmitted with better answers')
payment=pay('dmv','second-attempt');session=payment[2].session
result=submit(session,answersFor(session,5))
check(result.ok and result.score==5 and result.passed and result.confirmed and Owned.dmv,'exactly five correct answers pass after a new payment')
check(GrantCount==1 and RemovedMoney==1000,'two real attempts charge once each and grant once')
`);
run('theory answer validation and legacy-event bypass rejection',`
stepThread(1);local payment=pay('dmv');local session=payment[2].session
net('addLicense','dmv',session);net('addLicense','drive',session)
check(GrantCount==0 and not Owned.dmv,'no legacy event awards a paid but ungraded theory licence')
local malformed={}
local missing=answersFor(session,10);missing[5]=nil;malformed[#malformed+1]=missing
local extra=answersFor(session,10);extra[11]=0;malformed[#malformed+1]=extra
local key=answersFor(session,10);key.passed=true;malformed[#malformed+1]=key
for _,value in ipairs({-1,4,0.5,true,'0',math.huge,0/0}) do
 local answers=answersFor(session,10);answers[1]=value;malformed[#malformed+1]=answers
end
malformed[#malformed+1]={score=10,total=10,passed=true}
for _,answers in ipairs(malformed) do
 local result=submit(session,answers)
 check(result and not result.ok and result.error=='invalid_result' and GrantCount==0,'malformed answers cannot supply a score or grant')
end
check(Exported.IsExamActive(1),'invalid payloads do not consume a legitimate pending attempt')
check(submit('another-session',answersFor(session,10)).error=='invalid_session','a question set is bound to its paid session')
check(submit(session,answersFor(session,5)).confirmed and GrantCount==1,'a corrected valid submission is graded once')
`);
run('concurrent theory grants and database confirmation',`
stepThread(1);local payment=pay('dmv');local session=payment[2].session
DeferGrant=true
local first,second
Callbacks['esx_dmvschool:submitTheory'](1,function(result) first=result end,session,answersFor(session,5))
Callbacks['esx_dmvschool:submitTheory'](1,function(result) second=result end,session,answersFor(session,10))
check(first==nil and second==nil and GrantCount==1,'concurrent submissions join one graded grant')
check(pay('dmv')[2].error=='busy' and RemovedMoney==500,'a pending theory grant cannot cause another charge')
table.remove(PendingGrantQueries,1)()
check(first.confirmed and second.confirmed and first.score==5 and second.score==5,'joined callbacks retain the first server grade')
check(GrantCount==1 and Owned.dmv and not Exported.IsExamActive(1),'actual ownership confirms one theory grant')
check(submit(session,answersFor(session,0)).score==5 and GrantCount==1,'confirmed theory completion is idempotent')
`);
run('theory database failure retains grade without claiming a licence',`
stepThread(1);local payment=pay('dmv');local session=payment[2].session
GrantFailure=true
local result=submit(session,answersFor(session,5))
check(not result.ok and result.passed and not result.confirmed and result.score==5,'failed database grant preserves the actual passing grade')
check(not Owned.dmv and GrantCount==1 and not Exported.IsExamActive(1),'failed insertion never reports ownership or retains the lock')
check(submit(session,answersFor(session,10)).score==5 and GrantCount==1,'replay cannot retry a failed grant or change its grade')
`);
run('theory character, logout, expiry and cancelled-session boundaries',`
stepThread(1);local payment=pay('dmv');local session=payment[2].session
Identifier='char2:account'
check(submit(session,answersFor(session,10)).error=='invalid_session' and GrantCount==0,'another character cannot submit the paid question set')
Identifier='char1:account';cancelRequest('dmv',session)
check(submit(session,answersFor(session,10)).passed==false and GrantCount==0,'a cancelled theory attempt cannot grant')
payment=pay('dmv','logout-attempt');session=payment[2].session
fire('esx:playerLogout',1)
check(submit(session,answersFor(session,10)).error=='invalid_session' and GrantCount==0,'logout invalidates the question set')
payment=pay('dmv','expired-attempt');session=payment[2].session
Clock=Clock+Config.ExamTimeout+1
local result=submit(session,answersFor(session,10))
check(not result.passed and not result.confirmed and GrantCount==0,'expired theory sessions cannot grant')
`);
run('late theory grant callbacks cannot retain another character lock',`
stepThread(1);local payment=pay('dmv');local session=payment[2].session
DeferGrant=true;local response
Callbacks['esx_dmvschool:submitTheory'](1,function(result) response=result end,session,answersFor(session,5))
Identifier='char2:account';table.remove(PendingGrantQueries,1)()
check(response.error=='invalid_session','late grant result is not delivered to another character')
check(not Exported.IsExamActive(1),'a stale grant releases only its old pending lock')
`);
run('unavailable theory bank never charges a player',`
TheoryBanksAvailable=false;stepThread(1)
local result=pay('dmv')
check(result and not result[1] and result[2].error=='unavailable','missing server question files fail closed')
check(RemovedMoney==0 and GrantCount==0 and not Exported.IsExamActive(1),'no debit, grant or retained session for an unavailable bank')
`);
run('only server-assigned vehicles can be bound or removed',`
stepThread(1);local session=start('drive')
check(call('beginPractical',session,10)[1].error=='invalid_vehicle','an existing same-model vehicle is not an exam assignment')
check(Deleted==0 and VehicleSpawnCount==0,'rejecting a borrowed vehicle cannot delete it')
local created=createVehicle(session)
check(created.ok and created.netId==10 and VehicleSpawnCount==1,'server callback assigns one examination vehicle')
check(createVehicle(session).ok and VehicleSpawnCount==1,'vehicle allocation is idempotent for the paid session')
check(call('beginPractical',session,11)[1].error=='invalid_vehicle','another nearby vehicle cannot replace the assignment')
PlayerBucket=7
check(call('beginPractical',session,10)[1].error=='invalid_vehicle','assignment cannot cross player routing buckets')
PlayerBucket=0;VehicleBucket=7
check(call('beginPractical',session,10)[1].error=='invalid_vehicle','assignment cannot cross vehicle routing buckets')
VehicleBucket=0
check(call('beginPractical',session,10)[1].ok,'the assigned driver and vehicle can begin in their own bucket')
fire('esx:playerLogout',1)
check(Deleted==1 and DeletedEntities[1]==100,'logout removes only the server-created exam vehicle')
check(createVehicle(session).error=='invalid_session','old session cannot create another examination vehicle')
`);
run('cancelled asynchronous vehicle allocation cannot bind a later attempt',`
stepThread(1);local session=start('drive');DeferVehicle=true;local response
Callbacks['esx_dmvschool:createVehicle'](1,function(result) response=result end,session)
check(response==nil and VehicleSpawnCount==1,'vehicle allocation can wait for server creation')
cancelRequest('drive',session)
table.remove(PendingVehicleCallbacks,1)()
check(response and not response.ok and not Exported.IsExamActive(1),'cancelled allocation returns no usable session')
check(VehicleLeases[session]==nil and GrantCount==0,'late allocation cannot recreate a lease or licence')
`);
run('expired practical replacement cleans the old lease before sampling',`
stepThread(1);local oldSession=start('drive');begin(oldSession)
check(VehicleLeases[oldSession] and Deleted==0,'old paid attempt has a server-assigned lease')
Clock=Clock+Config.ExamTimeout+1
local payment=pay('drive','replacement-before-sample')
check(payment and payment[1] and payment[2].session~=oldSession,'a fresh attempt can replace the expired ticket')
check(VehicleLeases[oldSession]==nil and CancelledVehicleSessions[oldSession] and Deleted==1,'replacement deletes the exact expired lease before the background sampler runs')
check(RemovedMoney==5000 and Exported.IsExamActive(1),'replacement charges once and retains its own active ticket')
local session=payment[2].session
check(begin(session).ok and VehicleLeases[session] and VehicleSpawnCount==2,'the new paid session can create and bind its own lease')
check(call('createVehicle',oldSession)[1].error=='invalid_session','expired session cannot allocate a replacement vehicle')
tick(200)
check(VehicleLeases[session] and Exported.IsExamActive(1) and Deleted==1,'the next sampler preserves the new active lease')
fire('esx:playerLogout',1)
check(VehicleLeases[session]==nil and Deleted==2,'logout still cleans the replacement lease')
`);
run('free exams and failed ESX debits cannot create unpaid paid attempts',`
stepThread(1)
Config.Licenses[1].price=0
local free=pay('dmv')
check(free[1] and DebitCalls==0 and Money==50000,'free theory does not call the cash adapter')
cancelRequest('dmv',free[2].session)
Config.Licenses[1].price=500
RejectDebit=true
local rejected=pay('dmv')
check(not rejected[1] and rejected[2].error=='not_enough_money','adapter rejection blocks purchase')
check(DebitCalls==1 and Money==50000 and not Exported.IsExamActive(1),'failed debit creates no session')
`);
run('server-confirmed spawn failure refunds one charged fee',`
stepThread(1)
local first=start('drive')
SpawnBlocked=true
check(createVehicle(first).error=='spawn_blocked' and Money==50000 and RefundedMoney==2500,'blocked reservation refunds the charged fee')
check(createVehicle(first).error=='invalid_session' and RefundedMoney==2500,'replay cannot refund twice')
check(cancelRequest('drive',first).cancelled and not Exported.IsExamActive(1),'failed attempt can acknowledge cancellation')
SpawnBlocked=false
local second=start('drive')
check(begin(second).ok,'a later successful attempt binds normally')
check(cancelRequest('drive',second).cancelled and Money==47500 and RefundedMoney==2500,'voluntary cancellation retains the fee')
`);
run('death cleans pending payment, theory, and bound and unbound practical attempts',`
stepThread(1)
local function die()
 PedHealth=0;source=1;fire('esx:onPlayerDeath');source=nil
end
DeferLicenses=true
check(pay('dmv')==nil and Exported.IsExamActive(1),'pending payment fixture')
die();table.remove(PendingLicenseQueries,1)()
check(Money==50000 and not Exported.IsExamActive(1),'death cancels pending payment before debit')
DeferLicenses=false;PedHealth=200
local theory=start('dmv')
source=1;fire('esx:onPlayerDeath');source=nil
check(Exported.IsExamActive(1),'alive player cannot trigger a server death cleanup')
die()
check(not Exported.IsExamActive(1) and submit(theory,{}).reason=='death' and GrantCount==0,'death consumes theory without grant')
check(pay('dmv')[2].error=='not_near_school','dead player cannot buy a new exam')
PedHealth=200
local unbound=start('drive');check(createVehicle(unbound).ok,'unbound vehicle fixture')
die()
check(not VehicleLeases[unbound] and not Exported.IsExamActive(1) and #Threads==1,'death frees unbound vehicle without starting a monitor')
PedHealth=200
local bound=start('drive');check(begin(bound).ok,'bound vehicle fixture')
die();tick(200)
check(not VehicleLeases[bound] and not Exported.IsExamActive(1) and coroutine.status(Threads[2])=='dead','death removes driver and vehicle and stops monitoring')
check(complete(bound).reason=='death' and GrantCount==0,'death result cannot grant')
`);
run('disconnect invalidates old requests, vehicle leases and the practical monitor',`
stepThread(1)
local function drop() source=1;fire('playerDropped');source=nil end
DeferLicenses=true
check(pay('dmv')==nil and Exported.IsExamActive(1),'pending payment fixture')
drop();table.remove(PendingLicenseQueries,1)()
check(Money==50000 and not Exported.IsExamActive(1),'late payment reply cannot charge after disconnect')
DeferLicenses=false;DeferVehicle=true
local unbound=start('drive')
local result
Callbacks['esx_dmvschool:createVehicle'](1,function(reply) result=reply end,unbound)
drop();table.remove(PendingVehicleCallbacks,1)()
check(result.error=='invalid_session' and not VehicleLeases[unbound],'late allocation cannot retain disconnected lease')
DeferVehicle=false
local bound=start('drive');check(begin(bound).ok,'bound vehicle fixture')
drop();tick(200)
check(not VehicleLeases[bound] and not Exported.IsExamActive(1) and coroutine.status(Threads[2])=='dead','disconnect removes bound lease and stops monitor')
check(advance(bound,1).error=='invalid_session','disconnected attempt cannot be resumed')
`);
run('catalog startup waits for provider cache and stops retrying when it cannot load',`
SuppressCatalogRefresh=true
for i=1,10 do stepThread(1) end
check(#CatalogRows==2 and #Catalog==0,'database inserts alone do not mark the catalogue ready')
check(CatalogRefreshes==10 and coroutine.status(Threads[1])=='dead','catalogue retry has a finite lifetime')
check(pay('dmv')[2].error=='unavailable' and RemovedMoney==0,'a failed catalogue refresh never charges')
`);
run('practical monitoring follows driver binding and expires idle tickets independently',`
stepThread(1)
check(#Threads==1,'resource startup has no exam monitor')
local theory=start('dmv')
check(#Threads==1,'theory does not start the practical monitor')
runTimer(Config.ExamTimeout)
check(not Exported.IsExamActive(1),'theory expires without a polling thread')
local unbound=start('drive')
check(createVehicle(unbound).ok and #Threads==1,'vehicle allocation does not start monitoring before binding')
runTimer(30000)
check(not Exported.IsExamActive(1) and VehicleLeases[unbound]==nil,'unbound setup expires and releases its vehicle after 30 seconds')
local first=start('drive')
check(begin(first).ok and #Threads==2,'first bound driver starts one monitor')
runTimer(30000)
check(Exported.IsExamActive(1),'setup timeout leaves a bound driver active')
check(begin(first).ok and #Threads==2,'duplicate binding keeps the same monitor')
check(cancelRequest('drive',first).ok,'bound attempt can cancel')
local second=start('drive')
check(begin(second).ok and #Threads==2,'replacement before worker exits reuses the existing monitor')
tick(200);check(advance(second,1).ok,'monitor continues to observe the new bound attempt')
check(cancelRequest('drive',second).ok,'last driving attempt can cancel')
tick(200)
check(coroutine.status(Threads[2])=='dead','last cancellation stops the monitor')
local third=start('drive')
check(begin(third).ok and #Threads==3,'a later practical restarts the monitor')
fire('esx:playerLogout',1);tick(200)
check(coroutine.status(Threads[3])=='dead','logout removes the last driver and ends the monitor')
`);
run('vehicle binding waits for OneSync health before starting the monitor',`
stepThread(1);local session=start('drive')
check(createVehicle(session).ok,'vehicle allocated')
BodyHealth=0
check(call('beginPractical',session,10)[1].error=='vehicle_not_ready' and Deleted==0 and VehicleLeases[session]~=nil,
 'uninitialized health does not destroy the assigned vehicle')
check(#Threads==1,'uninitialized vehicle is not monitored')
BodyHealth=1000
check(call('beginPractical',session,10)[1].ok and #Threads==2,'replicated vehicle starts monitoring on retry')
`);
if(limiterSource)run('ESX request budget applies before payments, callbacks and network events',`
stepThread(1)
local session=start('drive')
check(createVehicle(session).ok,'normal purchase and vehicle allocation fit the budget')
check(call('beginPractical',session,10)[1].ok,'normal driver binding fits the budget')
for i=1,7 do check(type(call('getLicenses')[1])=='table','read uses one budget token') end
check(call('getLicenses')[1]==false,'exhausted budget denies licence reads')
check(pay('drive')[2].error=='busy' and RemovedMoney==2500,'exhausted budget cannot debit')
check(createVehicle(session).error=='busy' and VehicleSpawnCount==1,'exhausted budget cannot allocate')
check(advance(session,1).error=='busy','exhausted budget cannot advance')
net('cancelTest','drive',session)
check(Exported.IsExamActive(1),'network cancel uses the shared budget')
Clock=Clock+1000
check(cancelRequest('drive',session).ok and not Exported.IsExamActive(1),'refilled budget allows cancellation')
for i=1,5 do check(type(call('getLicenses')[1])=='table','remaining budget can be used') end
check(call('getLicenses')[1]==false,'budget is empty before disconnect')
source=1;fire('playerDropped');source=nil
check(type(call('getLicenses')[1])=='table','disconnect clears the former player budget')
`,{rateLimiter:true});
run('ESX callback fallback without xLib callback registration',`
stepThread(1);check(Callbacks['esx_dmvschool:canYouPay']~=nil,'ESX.RegisterServerCallback fallback');check(pay('dmv')[1],'compatible purchase with server ESX API')
`,{fallback:true});
console.log('Server regression: '+results.reduce((n,r)=>n+r.assertions,0)+' assertions passed.');
