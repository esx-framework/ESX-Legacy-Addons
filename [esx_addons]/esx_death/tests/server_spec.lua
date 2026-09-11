-- Run from the resource directory: lua tests/server_spec.lua
-- Exercises the real server handlers with deterministic ESX / database doubles.
local events, callbacks, api, commands, clients, bags, rows, players = {}, {}, {}, {}, {}, {}, {}, {}
local now, invoked, nested = 100000, 'monitor', nil
os.time = function() return now end
function vector3(x,y,z)
    return setmetatable({x=x,y=y,z=z}, {__sub=function(a,b) return vector3(a.x-b.x,a.y-b.y,a.z-b.z) end,
        __len=function(a) return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z) end})
end
function GetEntityCoords() return vector3(340,-1397,32) end
function GetPlayerPed(src) return src end
function GetPlayerName(src) return players[src] and 'Player' end
function GetConvar(_, fallback) return fallback end
function GetCurrentResourceName() return 'esx_death' end
function LoadResourceFile(_, path)
    local file = assert(io.open(path))
    local contents = file:read('*a')
    file:close()
    return contents
end
function GetGameTimer() return now*1000 end
function GetInvokingResource() return invoked end
function Player(src)
    bags[src] = bags[src] or {}
    return {state={set=function(_,key,value) bags[src][key]=value end}}
end
function RegisterNetEvent(name, fn) if fn then events[name]=fn end end
function AddEventHandler(name, fn) events[name]=fn end
function TriggerEvent() end
function TriggerClientEvent(name,src,data) clients[#clients+1]={name=name,src=src,data=data} end
function CreateThread() end -- startup loop is covered via getState hydration
function Wait() end
exports=setmetatable({ox_inventory={ClearInventory=function(_,src) players[src].cleared=true end}}, {__call=function(_,name,fn) api[name]=fn end})
ESX={GetConfig=function() return {OxInventory=false} end,
    GetPlayerFromId=function(src) return players[src] end,
    GetExtendedPlayers=function() return players end,
    RegisterServerCallback=function(name,fn) callbacks[name]=fn end,
    RegisterCommand=function(name,group,fn) commands[name]={group=group,fn=fn} end}
MySQL={ready=function(fn) fn() end,
    query={await=function(query) if query:find('SHOW COLUMNS') then return {{Field='is_dead'},{Field='death_time'}} end return {} end},
    single={await=function(_,params) return rows[params[1]] end},
    update={await=function(query,params)
        if nested then local fn=nested; nested=nil; fn() end
        if query:find('is_dead = 1') then rows[params[2]]={is_dead=1,death_time=params[1]}
        elseif query:find('is_dead = 0') then rows[params[1]]={is_dead=0}
        else rows[params[2]].death_time=params[1] end
        return 1
    end}}
local function player(src,identifier)
    local p={source=src,identifier=identifier,loadout={{name='A',ammo=5},{name='B',ammo=10}},
        inventory={{name='bread',count=3}}, cash=200,bank=6000,dirty=50,meta={}}
    p.getMeta=function() return p.meta end
    p.setMeta=function(key,value) p.meta[key]=value end
    p.clearMeta=function(key) p.meta[key]=nil end
    p.getLoadout=function() return p.loadout end
    p.getMoney=function() return p.cash end
    p.removeMoney=function(amount) p.cash=p.cash-amount end
    p.getAccount=function(name) return {money=name=='bank' and p.bank or p.dirty} end
    p.removeAccountMoney=function(_,amount) p.bank=p.bank-amount end
    p.setAccountMoney=function(_,amount) p.dirty=amount end
    p.setInventoryItem=function(name,count) for _,item in pairs(p.inventory) do if item.name==name then item.count=count end end end
    p.removeWeapon=function(name) for i,w in ipairs(p.loadout) do if w.name==name then table.remove(p.loadout,i);return end end end
    players[src]=p; rows[identifier]=rows[identifier] or {is_dead=0}
    return p
end
local function call(name,src)
    local result
    callbacks['esx_death:'..name](src,function(data) result=data end)
    assert(result,'callback did not respond')
    return result
end
local passed=0
local function test(name,fn) fn(); passed=passed+1; print('PASS '..name) end

dofile('../../../esx_core/[core]/es_extended/locale.lua')
dofile('config.lua')
dofile('server/main.lua')
local p=player(1,'char1:one')
test('alive player cannot pay or lose possessions through respawn',function()
    assert(call('respawn',1).error=='not_dead'); assert(p.cash==200 and #p.loadout==2)
end)
test('death persists once; duplicate events cannot reset deadline',function()
    source=1; events['esx:onPlayerDeath'](); local timestamp=rows[p.identifier].death_time
    now=now+10; events['esx:onPlayerDeath']()
    assert(rows[p.identifier].death_time==timestamp and bags[1].isDead and api.IsDead(1))
end)
test('server rejects early respawn without charging',function()
    assert(call('respawn',1).error=='too_early' and p.bank==6000)
end)
test('distress is restricted to dead players and rate limited',function()
    assert(call('distress',1).ok); assert(call('distress',1).error=='cooldown')
    assert(api.GetDeadPlayers()[1]=='distress'); assert(api.GetDeadPlayerLocations()[1].x==340)
end)
test('fine and penalties execute once with concurrent requests blocked',function()
    now=now+50; Config.EarlyRespawnFine=true
    nested=function() assert(call('respawn',1).error=='busy') end
    local result=call('respawn',1)
    assert(result.ok and result.point.x==341 and p.bank==1000)
    assert(p.cash==0 and p.dirty==0 and p.inventory[1].count==0 and #p.loadout==0)
    assert(not bags[1].isDead and rows[p.identifier].is_dead==0)
    assert(call('respawn',1).error=='not_dead' and p.bank==1000)
end)
test('insufficient bank balance rejects early respawn; automatic is free',function()
    api.SetDead(1); now=now+60
    assert(call('respawn',1).error=='insufficient_funds' and api.IsDead(1))
    now=now+600
    assert(call('respawn',1).ok and p.bank==1000)
end)
test('reconnection restores the original death time',function()
    api.SetDead(1); local started=rows[p.identifier].death_time
    events['esx:playerDropped'](1); assert(not api.IsDead(1))
    now=now+200; p=player(1,'char1:one')
    local result=call('getState',1)
    assert(result.dead and result.elapsed==200 and rows[p.identifier].death_time==started)
end)
test('revive clears database, state bag and metadata without inventory loss',function()
    assert(api.Revive(1,'ems')); assert(not api.IsDead(1) and not bags[1].isDead)
    assert(rows[p.identifier].is_dead==0 and not p.meta.deathTime and p.cash==200 and #p.loadout==2)
    assert(clients[#clients].name=='esx_death:recover')
end)
test('disabled penalties preserve loadout and inventory',function()
    Config.RemoveWeaponsAfterRPDeath=false; Config.RemoveItemsAfterRPDeath=false; Config.RemoveCashAfterRPDeath=false
    api.SetDead(1); now=now+660
    local result=call('respawn',1)
    assert(result.ok and #result.loadout==2 and p.cash==200 and p.inventory[1].count==3)
end)
test('character change cannot inherit another character death',function()
    api.SetDead(1); events['esx:playerLogout'](1); p=player(1,'char2:one')
    assert(not call('getState',1).dead and rows['char1:one'].is_dead==1)
end)
test('legacy deathTime metadata migrates without resetting elapsed time',function()
    p=player(2,'char1:two'); rows[p.identifier].is_dead=1; p.meta.deathTime=now-90
    assert(call('getState',2).elapsed==90 and rows[p.identifier].death_time==now-90)
end)
test('txAdmin rejects other resources and handles revive all',function()
    invoked='other'; events['txAdmin:events:healedPlayer']({id=2}); assert(api.IsDead(2))
    invoked='monitor'; events['txAdmin:events:healedPlayer']({id=-1}); assert(not api.IsDead(2))
end)
test('admin commands restricted; old client penalty endpoints removed',function()
    assert(commands.revive.group=='admin' and commands.reviveall.group=='admin')
    assert(not events['esx_ambulancejob:payFine'] and not events['esx:onPlayerSpawn'])
end)
test('ox inventory clearing also applies configured cash penalties',function()
    Config.OxInventory=true; Config.RemoveItemsAfterRPDeath=true; Config.RemoveCashAfterRPDeath=true
    api.SetDead(2); now=now+660
    assert(call('respawn',2).ok and p.cleared and p.cash==0 and p.dirty==0)
end)
test('resource restart hydrates persisted death and deadline',function()
    api.SetDead(2); local timestamp=rows[p.identifier].death_time
    dofile('server/main.lua'); now=now+70
    assert(call('getState',2).elapsed==70 and rows[p.identifier].death_time==timestamp)
end)
print(('%d server scenarios passed'):format(passed))
