-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

---@type table<string, Garage>
Garages = {}

---@type table<string, Impound>
Impounds = {}

local CALLBACK_COOLDOWNS <const> = {
    ["esx_garage:getGarages"] = 1500,
    ["esx_garage:getVehicles"] = 1500,
    ["esx_garage:retrieveVehicle"] = 1500,
    ["esx_garage:storeVehicle"] = 1500,
    ["esx_garage:toggleFavorite"] = 1000,
    ["esx_garage:renameVehicle"] = 1000,
    ["esx_garage:transferVehicle"] = 1500,
    ["esx_garage:giveKeys"] = 1000,
}

local callbackLimiters = {}

---@return integer
local function defaultImpoundFee()
    local fee = tonumber(Config.Settings.defaultImpoundFee) or 0
    return math.max(0, math.floor(fee))
end

---@param impound Impound
---@return integer
local function configuredImpoundCost(impound)
    local cost = tonumber(impound.cost)
    if cost == nil then
        return defaultImpoundFee()
    end

    return math.max(0, math.floor(cost))
end

---@param source integer
---@param cb function
---@param callbackName string
---@return boolean
function rejectRateLimited(source, cb, callbackName)
    local cooldown = CALLBACK_COOLDOWNS[callbackName]
    if not cooldown then
        return false
    end

    local limiter = callbackLimiters[callbackName]
    if not limiter then
        limiter = xLib.rateLimiter({
            capacity = 1,
            refill = 1,
            interval = cooldown,
            staleMs = math.max(60000, cooldown * 4)
        })
        callbackLimiters[callbackName] = limiter
    end

    if not limiter:consume(source) then
        cb({ success = false, error = "rate_limited" })
        return true
    end

    return false
end

for i = 1, #Config.Garages do
    local garage = Config.Garages[i]
    Garages[garage.id] = garage
end

for i = 1, #Config.Impounds do
    local impound = Config.Impounds[i]
    impound.cost = configuredImpoundCost(impound)
    Impounds[impound.id] = impound
end

---@param source integer
---@param garage Garage
---@return boolean
function CanAccessGarage(source, garage)
    local access = garage.access
    if not access then
        return true
    end
    
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return false
    end

    if access.jobs then
        local minGrade = access.jobs[xPlayer.job.name]
        if minGrade and xPlayer.job.grade >= minGrade then
            return true
        end
    end

    if access.authorize then
        local ok, result = pcall(access.authorize, source, garage)
        if not ok then
            print(("[esx_garage] garage %s: access.authorize errored: %s"):format(tostring(garage.id), tostring(result)))
            return false
        end

        return result == true
    end

    return false
end

---@param v any
---@return boolean
local function hasXYZ(v)
    local t = type(v)
    if t ~= "table" and t ~= "vector3" and t ~= "vector4" then
        return false
    end

    return tonumber(v.x) ~= nil and tonumber(v.y) ~= nil and tonumber(v.z) ~= nil
end

---@param v vector3 | vector4
---@return table
local function vec3t(v)
    return { x = v.x, y = v.y, z = v.z }
end

---@param v vector4
---@return table
local function vec4t(v)
    return { x = v.x, y = v.y, z = v.z, w = v.w }
end

---@param spawns vector4[]
---@return table[]
local function spawnsT(spawns)
    local out = {}
    for i = 1, #spawns do
        out[i] = vec4t(spawns[i])
    end
    return out
end

---@param ped GaragePed?
---@return table?
local function pedT(ped)
    if not ped then
        return nil
    end
    return { model = ped.model, z = ped.z, heading = ped.heading, snapToGround = ped.snapToGround }
end

---@param garage Garage
---@return table
local function garagePayload(garage)
    return {
        id = garage.id,
        label = garage.label,
        type = garage.type,
        entryPoint = vec3t(garage.entryPoint),
        storePoint = garage.storePoint and vec3t(garage.storePoint) or nil,
        spawns = spawnsT(garage.spawns),
        blip = garage.blip,
        ped = pedT(garage.ped),
        logo = garage.logo,
        color = garage.color,
        pound = garage.pound,
    }
end

---@param impound Impound
---@return table
local function impoundPayload(impound)
    return {
        id = impound.id,
        label = impound.label,
        getOutPoint = vec3t(impound.getOutPoint),
        spawns = spawnsT(impound.spawns),
        blip = impound.blip,
        ped = pedT(impound.ped),
        cost = impound.cost,
    }
end

---@param source integer
---@return { garages: table[], impounds: table[] }
local function accessiblePayload(source)
    local garages = {}

    for _, garage in pairs(Garages) do
        if CanAccessGarage(source, garage) then
            garages[#garages + 1] = garagePayload(garage)
        end
    end

    local impounds = {}

    for _, impound in pairs(Impounds) do
        impounds[#impounds + 1] = impoundPayload(impound)
    end

    return { garages = garages, impounds = impounds }
end

xLib.callback.registerCompat("esx_garage:getGarages", function(source, cb)
    if rejectRateLimited(source, cb, "esx_garage:getGarages") then
        return
    end

    local payload = accessiblePayload(source)

    cb(payload)
end)

---@param def Garage
local function registerGarage(def)
    assert(type(def) == "table" and type(def.id) == "string", "registerGarage: a garage table with a string id is required")
    assert(hasXYZ(def.entryPoint), ("registerGarage: garage %s needs a valid entryPoint (x, y, z)"):format(def.id))

    if def.storePoint ~= nil then
        assert(hasXYZ(def.storePoint), ("registerGarage: garage %s has an invalid storePoint (x, y, z)"):format(def.id))
    end

    assert(type(def.spawns) == "table" and #def.spawns > 0, ("registerGarage: garage %s needs at least one spawn"):format(def.id))

    for i = 1, #def.spawns do
        assert(hasXYZ(def.spawns[i]), ("registerGarage: garage %s spawn #%d is not a valid coordinate"):format(def.id, i))
    end

    Garages[def.id] = def
    TriggerClientEvent("esx_garage:refresh", -1)
end

---@param registry table<string, table>
---@return table[]
local function asList(registry)
    local out = {}
    for _, entry in pairs(registry) do
        out[#out + 1] = entry
    end
    return out
end

exports("getGarages", function()
    return asList(Garages)
end)

exports("getImpounds", function()
    return asList(Impounds)
end)

exports("registerGarage", registerGarage)

exports("registerGarages", function(list)
    assert(type(list) == "table", "registerGarages: expected a list of garages")
    for i = 1, #list do
        registerGarage(list[i])
    end
end)

exports("unregisterGarage", function(id)
    Garages[id] = nil
    TriggerClientEvent("esx_garage:refresh", -1)
end)
