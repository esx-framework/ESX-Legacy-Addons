-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework
local S = VehicleShopClient
local points, blips, active = {}, {}, {}
local refreshing, pending, generation = false, false, 0

xLib.points.startLoop()

local function clear()
    for _, point in ipairs(points) do
        xLib.point.delete(point)
    end

    for _, blip in ipairs(blips) do
        RemoveBlip(blip)
    end

    points, blips, active = {}, {}, {}
    ESX.HideUI()
end

local function add(shop, coords, action)
    if not coords then
        return
    end

    local location = { shop = shop, coords = vector3(coords.x, coords.y, coords.z), action = action }
    local point = xLib.point:new({
        coords = location.coords,
        distance = 3.0,
        enter = function()
            active[location] = true
            ESX.TextUI('[E] ' .. shop.name)
        end,
        leave = function()
            active[location] = nil

            if not next(active) then
                ESX.HideUI()
            end
        end,
    })
    point.marker = shop.marker or {}
    points[#points + 1] = point
end

local function refresh()
    if refreshing then
        pending = true
        return
    end

    refreshing = true

    local epoch = generation
    local shops = S.request('getDealerships')

    if epoch == generation and shops then
        clear()
        S.shops = {}

        for _, shop in ipairs(shops) do
            S.shops[shop.id] = shop

            if not shop.existingInteraction then
                add(shop, shop.coords, 'shop')
            end

            if shop.employee then
                add(shop, shop.managementPoint, 'shop')
            end

            if shop.resale then
                add(shop, shop.resalePoint, 'resale')
            end

            add(shop, shop.returnPoint, 'return')

            if shop.blip and shop.blip.enabled ~= false then
                blips[#blips + 1] = xLib.blips.create({
                    coords = shop.coords,
                    sprite = shop.blip.sprite,
                    scale = shop.blip.scale or 0.8,
                    color = shop.blip.color or 3,
                    shortRange = true,
                    label = shop.name,
                })
            end
        end

        if S.shop and not S.shops[S.shop.id] then
            S.close()
        end
    elseif not shops then
        SetTimeout(1500, function()
            if epoch == generation then
                refresh()
            end
        end)
    end

    refreshing = false

    if pending then
        pending = false
        refresh()
    end
end

local function invalidate()
    generation = generation + 1
    S.close()
    clear()
end

RegisterNetEvent('esx_vehicleshop:dealershipsChanged', refresh)
RegisterNetEvent('esx:playerLoaded', function()
    invalidate()
    refresh()
end)

RegisterNetEvent('esx:setJob', function()
    invalidate()
    refresh()
end)

ESX.SecureNetEvent('esx:onPlayerLogout', function()
    S.pending = nil
    invalidate()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        clear()
    end
end)

xLib.addKeybind({
    name = 'esx_vehicleshop_interact',
    description = S.translate('dealership_interact'),
    defaultMapper = 'keyboard',
    defaultKey = 'E',
    onPressed = function()
        if S.open then
            return
        end

        local nearest, distance

        for location in pairs(active) do
            local current = #(GetEntityCoords(PlayerPedId()) - location.coords)

            if not distance or current < distance then
                nearest, distance = location, current
            end
        end

        if not nearest then
            return
        end

        if nearest.action == 'shop' then
            S.openShop(nearest.shop.id)
        else
            local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)

            if vehicle == 0 then
                return ESX.ShowNotification(S.translate('dealership_vehicle_required'), 'error')
            end

            S.openShop(nearest.shop.id, nil, nearest.action, GetVehicleNumberPlateText(vehicle))
        end
    end,
})

CreateThread(function()
    local interiorID = 7170

    RequestIpl('shr_int')
    PinInteriorInMemory(interiorID)
    ActivateInteriorEntitySet(interiorID, 'csr_beforeMission')
    RefreshInterior(interiorID)
end)

CreateThread(function()
    while not ESX.IsPlayerLoaded() do
        Wait(100)
    end

    refresh()
end)

CreateThread(function()
    while true do
        local sleep, coords = 1000, GetEntityCoords(PlayerPedId())

        for _, point in ipairs(points) do
            -- Point drawing is intentionally separate from the shared NUI and server rules.
            if point.marker.enabled ~= false and point.coords and #(coords - point.coords) < (Config.DrawDistance or 10) then
                local marker = point.marker
                local color, size = marker.color or Config.MarkerColor or {}, marker.size or {}

                sleep = 0
                DrawMarker(marker.type or 1, point.coords.x, point.coords.y, point.coords.z - (marker.offsetZ or 0.9), 0, 0, 0, 0, 0, 0, size.x or 1.2, size.y or 1.2, size.z or 0.25, color.r or 255, color.g or 172, color.b or 0, color.a or 110, false, false, 2, false, nil, nil, false)
            end
        end

        Wait(sleep)
    end
end)

-- Temporary client contract for resources opening the default dealership.
function OpenShopMenu()
    return S.openShop(Config.LegacyDealershipId)
end
