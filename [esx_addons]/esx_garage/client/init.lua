local blips = {}
local pedSpawns = {}
local points = {}
local markers = {}

---@type table<string, Impound>
local impoundsById = {}

---@alias GarageAction 'garage' | 'withdraw' | 'store' | 'impound'

---@type { id: string, spawns: vector4[], garage: table, action: GarageAction, coords: vector3 }?
local currentLocation = nil

---@type table<number, { id: string, spawns: vector4[], garage: table, action: GarageAction, coords: vector3 }>
local activeLocations = {}

local PED_DECOR <const> = "esx_garage_ped"
local HUD_RESOURCE_NAME <const> = "esx_hud"
local MILES_TO_KILOMETERS <const> = 1.61

local DEFAULT_MARKER_COLOR <const> = { 65, 130, 255, 120 }
local PED_SPAWN_DISTANCE <const> = 80.0
local PED_DESPAWN_DISTANCE <const> = 120.0

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

xLib.points.startLoop()

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

---@param pound any
---@return string?
local function activePound(pound)
    return type(pound) == "string" and pound ~= "" and pound or nil
end

---@param value any
---@return boolean
local function dbBool(value)
    return value == true or value == 1 or value == "1"
end

---@return boolean
local function hudUsesKmh()
    if type(GetResourceState) ~= "function" or GetResourceState(HUD_RESOURCE_NAME) ~= "started" then
        return false
    end

    local ok, _, kmh = pcall(function()
        return exports[HUD_RESOURCE_NAME]:GetCurrentMileage()
    end)

    return ok and kmh == true
end

local function sweepGaragePeds()
    for _, ped in ipairs(GetGamePool("CPed")) do
        if not IsPedAPlayer(ped) and DecorExistOn(ped, PED_DECOR) then
            SetEntityAsMissionEntity(ped, true, true)
            DeleteEntity(ped)
        end
    end
end

---@param spawn table
local function deleteGaragePed(spawn)
    if spawn.ped and DoesEntityExist(spawn.ped) then
        SetEntityAsMissionEntity(spawn.ped, true, true)
        DeleteEntity(spawn.ped)
    end

    spawn.ped = nil
end

local function clearWorld()
    for i = 1, #blips do
        RemoveBlip(blips[i])
    end

    for i = 1, #pedSpawns do
        deleteGaragePed(pedSpawns[i])
    end

    for i = 1, #points do
        local point = points[i]
        if point and xLib.point and xLib.point.delete then
            xLib.point.delete(point)
        end
    end

    blips, pedSpawns, points, markers = {}, {}, {}, {}
    activeLocations = {}
    currentLocation = nil

    if ESX.HideUI then
        ESX.HideUI()
    end
end

---@param action GarageAction
---@param ped number
---@return boolean
local function isInteractionVisible(action, ped)
    return action ~= "store"
        or not Config.Settings.storeMarkerOnlyInVehicle
        or IsPedInAnyVehicle(xLib.cache.ped, false)
end

---@return nil
local function updateCurrentLocation()
    local coords = GetEntityCoords(xLib.cache.ped)
    local best, bestDistance

    for _, entry in pairs(activeLocations) do
        if isInteractionVisible(entry.action, xLib.cache.ped) then
            local distance = #(coords - entry.coords)

            if not bestDistance or distance < bestDistance then
                best, bestDistance = entry, distance
            end
        end
    end

    if currentLocation == best then
        return
    end

    currentLocation = best

    if not best then
        return ESX.HideUI()
    end

    ESX.TextUI(TranslateCap(INTERACTION_STYLES[best.action].locale))
end

---@param location table
---@param raw vector3 | table
---@param action GarageAction
local function addInteractionPoint(location, raw, action)
    local coords = vector3(raw.x, raw.y, raw.z)

    local style = INTERACTION_STYLES[action]

    if Config.Settings.showMarker then
        markers[#markers + 1] = {
            coords = coords,
            style = style,
            action = action
        }
    end

    local index = #points + 1
    local entry = {
        id = location.id,
        spawns = location.spawns,
        garage = location,
        action = action,
        coords = coords,
    }

    points[index] = xLib.point:new({
        coords = coords,
        distance = Config.Settings.interactionDistance,
        enter = function()
            activeLocations[index] = entry
            updateCurrentLocation()
        end,
        leave = function()
            activeLocations[index] = nil
            updateCurrentLocation()
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
        local z = location.ped.z or coords.z
        pedSpawns[#pedSpawns + 1] = {
            model = location.ped.model,
            coords = vector4(coords.x, coords.y, z, location.ped.heading or 0.0),
            anchor = coords,
            snapToGround = location.ped.snapToGround ~= false,
        }
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

    local ok, data = pcall(xLib.callback.await, "esx_garage:getGarages", false)
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

---@param raw any
---@return table
local function vehicleProps(raw)
    if type(raw) ~= "string" then
        return {}
    end

    local ok, props = pcall(json.decode, raw)
    if not ok or type(props) ~= "table" then
        return {}
    end

    return props
end

---@param row OwnedVehicleRow
---@param currentLot Impound? lot the player is standing at, when the menu is an impound
---@param useKmh boolean
---@return GarageVehicle
local function wrap(row, currentLot, useKmh)
    local props = vehicleProps(row.vehicle)
    local model = props.model
    local displayName = model and GetDisplayNameFromVehicleModel(model) or "VEHICLE"
    local pound = activePound(row.pound)
    local impounded = pound ~= nil
    local stored = dbBool(row.stored)
    local outOfSync = not stored and not impounded
    local mileage = tonumber(row.mileage) or 0
    mileage = useKmh and mileage * MILES_TO_KILOMETERS or mileage

    local fee
    if impounded or outOfSync then
        local lot = (pound and impoundsById[pound]) or currentLot
        fee = (lot and lot.cost) or Config.Settings.defaultImpoundFee
    end

    return {
        id = row.plate,
        plate = row.plate,
        model = displayName:lower(),
        name = displayName,
        type = nuiVehicleType(row.type or (model and ESX.GetVehicleTypeClient(model))),
        stored = stored and not impounded,
        impounded = impounded,
        garage = row.parking,
        impoundFee = fee,
        mileage = mileage,
        mileageUnit = useKmh and "km" or "mi",
        fuel = props.fuelLevel,
        engine = props.engineHealth and props.engineHealth / 10.0 or nil,
        body = props.bodyHealth and props.bodyHealth / 10.0 or nil,
        isFavorite = dbBool(row.is_favorite),
        customName = row.custom_name,
        lastUsed = row.last_used,
        props = props,
    }
end

---@param name string
---@param payload any
---@return any
local function serverCall(name, payload)
    local ok, result = pcall(xLib.callback.await, name, false, payload)
    if not ok then
        return nil
    end

    return result
end

---@param data table?
---@return table?, string?
local function fetchVehiclePage(data)
    local loc = currentLocation

    if not loc then
        return nil, "no_location"
    end

    local page = tonumber(data and data.page) or 1
    local pageSize = tonumber(data and data.pageSize)
    local result = serverCall("esx_garage:getVehicles", {
        garageId = loc.id,
        page = page,
        pageSize = pageSize,
        filter = data and data.filter or nil,
    })

    if currentLocation ~= loc then
        return nil, "no_location"
    end

    if type(result) == "table" and result.success == false then
        return nil, result.error or "error"
    end

    if type(result) ~= "table" or type(result.vehicles) ~= "table" then
        return nil, "error"
    end

    local currentLot = impoundsById[loc.id]
    local vehicles = {}
    local useKmh = hudUsesKmh()

    for i = 1, #result.vehicles do
        vehicles[#vehicles + 1] = wrap(result.vehicles[i], currentLot, useKmh)
    end

    local resultPage = tonumber(result.page) or page
    local resultPageSize = tonumber(result.pageSize) or #vehicles

    return {
        vehicles = vehicles,
        mileageUnit = useKmh and "km" or "mi",
        pagination = {
            page = resultPage,
            pageSize = resultPageSize,
            hasNext = result.hasNext == true,
            hasPrevious = resultPage > 1,
        },
    }
end

local function openMenu()
    local loc = currentLocation
    
    if not loc then
        return
    end

    local page, err = fetchVehiclePage({ page = 1 })
    
    if not page then
        if err == "no_location" then
            return
        end

        return ESX.ShowNotification(TranslateCap("cannot_access_garage"), "error")
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
            vehicles = page.vehicles,
            mileageUnit = page.mileageUnit,
            pagination = page.pagination,
        }
    })

    SetNuiFocus(true, true)
end

local function syncHudMileage(plate)
    if type(GetResourceState) ~= "function" or GetResourceState(HUD_RESOURCE_NAME) ~= "started" then
        return
    end

    local ok, mileage, kmh, loaded = pcall(function()
        return exports[HUD_RESOURCE_NAME]:GetCurrentMileage()
    end)

    mileage = tonumber(mileage)
    if ok and loaded == true and mileage then
        TriggerServerEvent("esx_hud:UpdateVehicleMileage", plate, mileage, kmh == true)
    end
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

    local props = xLib.game.getVehicleProperties(vehicle)
    if not props or not props.plate then
        return
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    syncHudMileage(props.plate)

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

xLib.addKeybind({
    name = "esx_garage_interact",
    description = TranslateCap("open_garage"),
    defaultMapper = "keyboard",
    defaultKey = "E",
    onPressed = onInteract,
})

---@param spawns vector4[]
---@return vector4?
local function pickClearSpawn(spawns)
    if not spawns then
        return nil
    end

    for i = 1, #spawns do
        local spawn = spawns[i]
        if xLib.game.isSpawnPointClear(vector3(spawn.x, spawn.y, spawn.z), 2.5) then
            return spawn
        end
    end

    return nil
end

local function closeMenu()
    SetNuiFocus(false, false)
    SendNUIMessage({ type = "closeGarage", payload = {} })
end

RegisterNUICallback("garage:getVehicles", function(data, cb)
    local page, err = fetchVehiclePage(data)
    if not page then
        return cb({ success = false, error = err or "no_location" })
    end

    cb({ success = true, data = page })
end)

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

AddEventHandler("xLib:cache:vehicle", updateCurrentLocation)

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
        if #pedSpawns > 0 then
            local pcoords = xLib.cache.coords or GetEntityCoords(PlayerPedId())

            for i = 1, #pedSpawns do
                local spawn = pedSpawns[i]
                local distance = #(pcoords - spawn.anchor)

                if spawn.ped and not DoesEntityExist(spawn.ped) then
                    spawn.ped = nil
                end

                if spawn.ped then
                    if distance > PED_DESPAWN_DISTANCE then
                        deleteGaragePed(spawn)
                    end
                elseif distance < PED_SPAWN_DISTANCE then
                    local ped = Utils.SpawnFrozenPed(spawn.model, spawn.coords, spawn.snapToGround)
                    if ped then
                        DecorSetBool(ped, PED_DECOR, true)
                        spawn.ped = ped
                    end
                end
            end
        end

        Wait(1000)
    end
end)

CreateThread(function()
    while true do
        local sleep = 1000

        if #markers > 0 then
            local pcoords = xLib.cache.coords
            local inVehicle = xLib.cache.vehicle ~= false

            for i = 1, #markers do
                local marker = markers[i]
                local coords = marker.coords

                if #(pcoords - coords) < 20.0 then
                    local visible = isInteractionVisible(marker.action, xLib.cache.ped)

                    if visible then
                        sleep = 0
                        local color = marker.style.color

                        ---@diagnostic disable-next-line: missing-parameter
                        DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5, 1.5, 1.0, color[1], color[2], color[3], color[4], false, false, 2, false)
                    end
                end
            end
        end

        Wait(sleep)
    end
end)
