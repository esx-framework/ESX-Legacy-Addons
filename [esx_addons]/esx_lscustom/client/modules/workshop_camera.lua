-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

WorkshopCamera = {}

local workshopCam, workshopCamVehicle, workshopFreeCam = nil, nil, false
local currentView = 'default'
local orbit = { yaw = 0.0, pitch = 16.0, dist = 4.6, fwd = 0.4, right = 0.4, up = 0.4 }

local CAMERA_VIEWS = {
    front = { yawOff = 0.0, pitch = 8.0, dist = 3.4, fwd = 1.7, right = 0.0, up = 0.40 },
    back = { yawOff = 180.0, pitch = 8.0, dist = 3.6, fwd = -1.9, right = 0.0, up = 0.55 },
    left = { yawOff = 90.0, pitch = 8.0, dist = 3.9, fwd = 0.0, right = -1.4, up = 0.35 },
    right = { yawOff = -90.0, pitch = 8.0, dist = 3.9, fwd = 0.0, right = 1.4, up = 0.35 },
    top = { yawOff = 0.0, pitch = 78.0, dist = 5.2, fwd = 0.0, right = 0.0, up = 0.45 },
    default = { yawOff = -35.0, pitch = 16.0, dist = 4.6, fwd = 0.4, right = 0.4, up = 0.40 }
}

local CAMERA_CATEGORY_VIEW = {
    modFrontBumper = 'front',
    modGrille = 'front',
    modHood = 'front',
    xenonColor = 'front',
    modRearBumper = 'back',
    modSpoilers = 'back',
    modSideSkirt = 'left',
    modFrontWheels = 'left',
    modBackWheels = 'left',
    windowTint = 'left',
    modRoof = 'top'
}

local function shouldRefocusNui()
    return type(IsLSCustomNuiOpen) == 'function' and IsLSCustomNuiOpen()
end

function WorkshopCamera.Update()
    if not workshopCam or not workshopCamVehicle or not DoesEntityExist(workshopCamVehicle) then return end

    local heading = math.rad(GetEntityHeading(workshopCamVehicle))
    local forward = vector3(-math.sin(heading), math.cos(heading), 0.0)
    local right = vector3(math.cos(heading), math.sin(heading), 0.0)
    local center = GetEntityCoords(workshopCamVehicle)
    local focus = center + forward * orbit.fwd + right * orbit.right + vector3(0.0, 0.0, orbit.up)
    local yaw = math.rad(orbit.yaw)
    local pitch = math.rad(orbit.pitch)
    local horizontal = orbit.dist * math.cos(pitch)
    local camPos = vector3(
        focus.x + (-math.sin(yaw)) * horizontal,
        focus.y + (math.cos(yaw)) * horizontal,
        focus.z + orbit.dist * math.sin(pitch)
    )

    SetCamCoord(workshopCam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(workshopCam, focus.x, focus.y, focus.z)
end

function WorkshopCamera.SetView(name)
    if not workshopCamVehicle then return end

    local view = CAMERA_VIEWS[name] or CAMERA_VIEWS.default
    currentView = CAMERA_VIEWS[name] and name or 'default'
    orbit.yaw = (GetEntityHeading(workshopCamVehicle) + view.yawOff) % 360.0
    orbit.pitch = view.pitch
    orbit.dist = view.dist
    orbit.fwd = view.fwd
    orbit.right = view.right
    orbit.up = view.up
    WorkshopCamera.Update()
    SendNUIMessage({ action = 'cameraState', view = currentView })
end

function WorkshopCamera.Focus(modType)
    if currentView == 'orbit' or workshopFreeCam then return end

    local viewName = CAMERA_CATEGORY_VIEW[modType] or 'default'
    if viewName == currentView then return end

    WorkshopCamera.SetView(viewName)
end

function WorkshopCamera.Rotate(dir)
    currentView = 'orbit'
    orbit.yaw = (orbit.yaw + (tonumber(dir) or 1) * 15.0) % 360.0
    WorkshopCamera.Update()
    SendNUIMessage({ action = 'cameraState', view = currentView })
end

function WorkshopCamera.Zoom(dir)
    orbit.dist = math.max(1.8, math.min(9.0, orbit.dist + (tonumber(dir) or 1) * 0.6))
    WorkshopCamera.Update()
end

function WorkshopCamera.ExitFree()
    if not workshopFreeCam then return end

    workshopFreeCam = false
    SendNUIMessage({ action = 'controlGuide', visible = false })
    SendNUIMessage({ action = 'cameraState', view = currentView })
    if shouldRefocusNui() then
        SetNuiFocus(true, true)
    end
end

function WorkshopCamera.EnterFree()
    if workshopFreeCam or not workshopCam then return end

    workshopFreeCam = true
    currentView = 'orbit'
    SendNUIMessage({ action = 'controlGuide', visible = true, message = TranslateCap('free_camera_help') })
    SendNUIMessage({ action = 'cameraState', view = 'free' })
    SetNuiFocus(false, false)

    CreateThread(function()
        while workshopFreeCam do
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 75, true)
            DisableControlAction(0, 23, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)

            local dx = GetDisabledControlNormal(0, 1)
            local dy = GetDisabledControlNormal(0, 2)
            orbit.yaw = (orbit.yaw + dx * 10.0) % 360.0
            orbit.pitch = math.max(-25.0, math.min(85.0, orbit.pitch - dy * 8.0))

            if IsControlPressed(0, 241) then
                orbit.dist = math.max(1.8, orbit.dist - 0.12)
            end

            if IsControlPressed(0, 242) then
                orbit.dist = math.min(9.0, orbit.dist + 0.12)
            end

            WorkshopCamera.Update()

            if IsControlJustReleased(0, 38) then
                WorkshopCamera.ExitFree()
            end

            Wait(0)
        end
    end)
end

function WorkshopCamera.ToggleFree()
    if workshopFreeCam then
        WorkshopCamera.ExitFree()
    else
        WorkshopCamera.EnterFree()
    end
end

function WorkshopCamera.Start(vehicle)
    if not Config.Workshop or not Config.Workshop.EnableCamera then return end
    if workshopCam then WorkshopCamera.Stop() end
    if not vehicle or not DoesEntityExist(vehicle) then return end

    workshopCamVehicle = vehicle
    workshopCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 55.0, false, 0)
    SetCamActive(workshopCam, true)
    RenderScriptCams(true, true, 500, true, true)
    WorkshopCamera.SetView('default')
end

function WorkshopCamera.Stop()
    workshopFreeCam = false
    SendNUIMessage({ action = 'controlGuide', visible = false })
    RenderScriptCams(false, false, 500, true, true)
    if workshopCam then
        DestroyCam(workshopCam, false)
        workshopCam = nil
    end
    workshopCamVehicle = nil
end
