local blips = {}
local peds = {}
local points = {}
local markers = {}

---@type table<string, Impound>
local impoundsById = {}

---@alias GarageAction 'garage' | 'withdraw' | 'store' | 'impound'

---@type { id: string, spawns: vector4[], garage: table, action: GarageAction }?
local currentLocation = nil

local PED_DECOR <const> = "esx_garage_ped"

local DEFAULT_MARKER_COLOR <const> = { 65, 130, 255, 120 }

local WITHDRAW_INTERACTION <const> = {
    locale = "access_parking",
    color = DEFAULT_MARKER_COLOR,
}

---@type table<GarageAction, { locale: string, color: integer[] }>
local INTERACTION_STYLES <const> = {
    garage = WITHDRAW_INTERACTION,
    withdraw = WITHDRAW_INTERACTION,
    store = { locale = "park_veh", color = { 70, 200, 100, 120 } },
    impound = { locale = "access_Impound", color = DEFAULT_MARKER_COLOR },
}

if not DecorIsRegisteredAsType(PED_DECOR, 2) then
    DecorRegister(PED_DECOR, 2)
end

---@type table<string, boolean>
local NUI_VEHICLE_TYPES <const> = {
    car = true, motorcycle = true, boat = true, aircraft = true,
    bicycle = true, truck = true, emergency = true,
}

---Maps the raw game vocabulary (ESX.GetVehicleTypeClient, owned_vehicles.type)
---to the NUI enum; anything unknown falls back to "car" so the zod schema
---never rejects the payload.
---@type table<string, string>
local NUI_TYPE_MAP <const> = {
    automobile = "car",
    quadbike = "car",
    amphibious_automobile = "car",
    amphibious_quadbike = "car",
    bike = "motorcycle",
    heli = "aircraft",
    plane = "aircraft",
    blimp = "aircraft",
    submarine = "boat",
    trailer = "truck",
    train = "truck",
}

---@param raw any
---@return string
local function nuiVehicleType(raw)
    if type(raw) ~= "string" then
        return "car"
    end

    if NUI_VEHICLE_TYPES[raw] then
        return raw
    end

    return NUI_TYPE_MAP[raw] or "car"
end

local function sweepGaragePeds()
    for _, ped in ipairs(GetGamePool("CPed")) do
        if not IsPedAPlayer(ped) and DecorExistOn(ped, PED_DECOR) then
            SetEntityAsMissionEntity(ped, true, true)
            DeleteEntity(ped)
        end
    end
end

local function clearWorld()
    for i = 1, #blips do
        RemoveBlip(blips[i])
    end

    for i = 1, #peds do
        if DoesEntityExist(peds[i]) then
            SetEntityAsMissionEntity(peds[i], true, true)
            DeleteEntity(peds[i])
        end
    end

    for i = 1, #points do
        local point = points[i]
        if point and ESX.Point and ESX.Point.delete then
            ESX.Point.delete(point)
        end
    end

    blips, peds, points, markers = {}, {}, {}, {}
    currentLocation = nil

    if ESX.HideUI then
        ESX.HideUI()
    end
end

---@param location table
---@param raw vector3 | table
---@param action GarageAction
local function addInteractionPoint(location, raw, action)
    local coords = vector3(raw.x, raw.y, raw.z)

    local style = INTERACTION_STYLES[action]

    markers[#markers + 1] = {
        coords = coords,
        style = style,
    }

    points[#points + 1] = ESX.Point:new({
        coords = coords,
        distance = Config.Settings.interactionDistance,
        enter = function()
            currentLocation = {
                id = location.id,
                spawns = location.spawns,
                garage = location,
                action = action,
            }

            ESX.TextUI(TranslateCap(style.locale))
        end,
        leave = function()
            currentLocation = nil
            ESX.HideUI()
        end
    })
end

---@param location table
---@param isImpound boolean
local function addLocation(location, isImpound)
    local raw = isImpound and location.getOutPoint or location.entryPoint
    local coords = vector3(raw.x, raw.y, raw.z)

    if location.blip then
        blips[#blips + 1] = Utils.CreateBlip(coords, location.blip.sprite, location.blip.scale, location.blip.color, location.label)
    end

    if location.ped then
        local pc = location.ped.coords
        local ped = Utils.SpawnFrozenPed(location.ped.model, vector4(pc.x, pc.y, pc.z, pc.w))
        if ped then
            DecorSetBool(ped, PED_DECOR, true)
            peds[#peds + 1] = ped
        end
    end

    if isImpound then
        addInteractionPoint(location, location.getOutPoint, "impound")
        return
    end

    if location.storePoint then
        addInteractionPoint(location, location.entryPoint, "withdraw")
        addInteractionPoint(location, location.storePoint, "store")
        return
    end

    addInteractionPoint(location, location.entryPoint, "garage")
end

local refreshing = false
local refreshPending = false

local function refresh()
    if refreshing then
        refreshPending = true
        return
    end
    refreshing = true

    local ok, data = pcall(ESX.AwaitServerCallback, "esx_garage:getGarages")
    if ok and type(data) == "table" and type(data.garages) == "table" and type(data.impounds) == "table" then
        pcall(function()
            clearWorld()

            impoundsById = {}
            for i = 1, #data.impounds do
                impoundsById[data.impounds[i].id] = data.impounds[i]
            end

            for i = 1, #data.garages do
                addLocation(data.garages[i], false)
            end

            for i = 1, #data.impounds do
                addLocation(data.impounds[i], true)
            end
        end)
    end

    refreshing = false

    if refreshPending then
        refreshPending = false
        refresh()
    end
end

---@param row OwnedVehicleRow
---@param currentLot Impound? lot the player is standing at, when the menu is an impound
---@return GarageVehicle
local function wrap(row, currentLot)
    local props = json.decode(row.vehicle) or {}
    local model = props.model
    local displayName = model and GetDisplayNameFromVehicleModel(model) or "VEHICLE"
    local impounded = row.stored == 1 and row.pound ~= nil
    local outOfSync = row.stored ~= 1

    local fee
    if impounded or outOfSync then
        local lot = (row.pound and impoundsById[row.pound]) or currentLot
        fee = (lot and lot.cost) or Config.Settings.defaultImpoundFee
    end

    return {
        id = row.plate,
        plate = row.plate,
        model = displayName:lower(),
        name = displayName,
        type = nuiVehicleType(row.type or (model and ESX.GetVehicleTypeClient(model))),
        stored = row.stored == 1 and row.pound == nil,
        impounded = impounded,
        garage = row.parking,
        impoundFee = fee,
        mileage = row.mileage or 0,
        fuel = props.fuelLevel,
        engine = props.engineHealth and props.engineHealth / 10.0 or nil,
        body = props.bodyHealth and props.bodyHealth / 10.0 or nil,
        isFavorite = row.is_favorite == 1,
        customName = row.custom_name,
        lastUsed = row.last_used,
        props = props,
    }
end

---@param name string
---@param payload any
---@return any
local function serverCall(name, payload)
    local ok, result = pcall(ESX.AwaitServerCallback, name, payload)
    if not ok then
        return nil
    end

    return result
end

local function openMenu()
    local loc = currentLocation
    
    if not loc then
        return
    end

    local rows = serverCall("esx_garage:getVehicles", loc.id)
    
    if not rows then
        return ESX.ShowNotification(TranslateCap("cannot_access_garage"), "error")
    end

    local currentLot = impoundsById[loc.id]

    local vehicles = {}
    
    for i = 1, #rows do
        vehicles[#vehicles + 1] = wrap(rows[i], currentLot)
    end

    local garage = loc.garage

    SendNUIMessage({ type = "setLocale", payload = Config.Locale })

    SendNUIMessage({
        type = "openGarage",
        payload = {
            garage = {
                id = garage.id,
                name = garage.label,
                type = garage.type or (loc.action == "impound" and "impound" or "public"),
                label = garage.label,
                logo = garage.logo,
                color = garage.color,
                keys = Config.Settings.vehicleKeys,
            },
            vehicles = vehicles,
        }
    })

    SetNuiFocus(true, true)
end

local function storeCurrentVehicle()
    if not currentLocation then
        return
    end

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then
        return ESX.ShowNotification(TranslateCap("not_in_vehicle"), "error")
    end

    local props = ESX.Game.GetVehicleProperties(vehicle)
    if not props or not props.plate then
        return
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    local result = serverCall("esx_garage:storeVehicle", {
        plate = props.plate,
        garageId = currentLocation.id,
        props = props,
        netId = netId,
    })

    if result and result.success then
        ESX.ShowNotification(TranslateCap("veh_stored"), "success")
    else
        ESX.ShowNotification(TranslateCap("cannot_store"), "error")
    end
end

local function onInteract()
    if not currentLocation then
        return
    end

    local action = currentLocation.action

    if action == "store" then
        storeCurrentVehicle()
        return
    end

    if action == "garage" and IsPedInAnyVehicle(PlayerPedId(), false) then
        storeCurrentVehicle()
        return
    end

    openMenu()
end

ESX.RegisterInput("esx_garage_interact", TranslateCap("open_garage"), "keyboard", "E", onInteract)

---@param spawns vector4[]
---@return vector4?
local function pickClearSpawn(spawns)
    if not spawns then
        return nil
    end

    for i = 1, #spawns do
        local spawn = spawns[i]
        if ESX.Game.IsSpawnPointClear(vector3(spawn.x, spawn.y, spawn.z), 2.5) then
            return spawn
        end
    end

    return nil
end

local function closeMenu()
    SetNuiFocus(false, false)
    SendNUIMessage({ type = "closeGarage", payload = {} })
end

RegisterNUICallback("garage:retrieveVehicle", function(data, cb)
    if not currentLocation then
        return cb({ success = false, error = "no_location" })
    end

    local spawn = pickClearSpawn(currentLocation.spawns)

    if not spawn then
        return cb({ success = false, error = "blocked" })
    end

    local result = serverCall("esx_garage:retrieveVehicle", {
        plate = data.vehicleId,
        garageId = currentLocation.id,
        spawn = { x = spawn.x, y = spawn.y, z = spawn.z, w = spawn.w },
    })

    if result and result.success and result.data and result.data.netId then
        local vehicle = NetworkGetEntityFromNetworkId(result.data.netId)
        local tries = 0

        while not DoesEntityExist(vehicle) and tries < 50 do
            Wait(10)
            vehicle = NetworkGetEntityFromNetworkId(result.data.netId)
            tries = tries + 1
        end

        if DoesEntityExist(vehicle) then
            TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
        end

        closeMenu()
    end

    cb(result or { success = false })
end)

RegisterNUICallback("garage:toggleFavorite", function(data, cb)
    local result = serverCall("esx_garage:toggleFavorite", { plate = data.vehicleId, isFavorite = data.isFavorite })
    cb(result or { success = false })
end)

RegisterNUICallback("garage:renameVehicle", function(data, cb)
    local result = serverCall("esx_garage:renameVehicle", { plate = data.vehicleId, name = data.newName or data.name })
    cb(result or { success = false })
end)

RegisterNUICallback("garage:transferVehicle", function(data, cb)
    local result = serverCall("esx_garage:transferVehicle", { plate = data.vehicleId, targetId = data.targetId })
    cb(result or { success = false })
end)

RegisterNUICallback("garage:giveKeys", function(data, cb)
    local result = serverCall("esx_garage:giveKeys", { plate = data.vehicleId })
    cb(result or { success = false })
end)

RegisterNUICallback("garage:closeUI", function(_, cb)
    closeMenu()
    cb({ success = true })
end)

RegisterNUICallback("SetNuiFocus", function(data, cb)
    SetNuiFocus(data.hasFocus, data.hasCursor)
    cb({ success = true })
end)

RegisterNetEvent("esx_garage:refresh", refresh)
RegisterNetEvent("esx:playerLoaded", refresh)
RegisterNetEvent("esx:setJob", refresh)

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        clearWorld()
        sweepGaragePeds()
    end
end)

CreateThread(function()
    sweepGaragePeds()

    while not ESX.IsPlayerLoaded() do
        Wait(500)
    end

    refresh()
end)

CreateThread(function()
    while true do
        local sleep = 1000

        if #markers > 0 then
            local pcoords = GetEntityCoords(PlayerPedId())

            for i = 1, #markers do
                local marker = markers[i]
                local coords = marker.coords

                if #(pcoords - coords) < 20.0 then
                    sleep = 0
                    local color = marker.style.color

                    ---@diagnostic disable-next-line: missing-parameter
                    DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5, 1.5, 1.0, color[1], color[2], color[3], color[4], false, false, 2, false)
                end
            end
        end
        
        Wait(sleep)
    end
end)
