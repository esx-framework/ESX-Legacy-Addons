-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

HUD.Data.hudHidden = false
RegisterCommand("hud", function()
    HUD:Toggle(HUD.Data.hudHidden)
    HUD.Data.hudHidden = not HUD.Data.hudHidden
end, false)

RegisterCommand("togglehud", function()
    HUD:Toggle(HUD.Data.hudHidden)
    HUD.Data.hudHidden = not HUD.Data.hudHidden
end, false)

RegisterCommand("hudsettings", function()
    xLib.nui.open({ type = "OPEN_SETTINGS" })
end, false)

if not Config.Disable.VehicleHandlers and not Config.Disable.Vehicle then
    local leftSignal, rightSignal = false, false

    xLib.addKeybind({
    name = "esx_hud:indicator:left",
    description = Translate("indicatorLeft"),
    defaultMapper = "keyboard",
    defaultKey = "LEFT",
    onPressed = function()
        if not HUD.Data.Vehicle then
            return
        end
        if HUD.Data.VehicleType == "AIR" then
            return
        end
        leftSignal = not leftSignal
        SetVehicleIndicatorLights(HUD.Data.Vehicle, 1, leftSignal)

        local isAttached, trailer = GetVehicleTrailerVehicle(HUD.Data.Vehicle)
        if isAttached and DoesEntityExist(trailer) then
            SetVehicleIndicatorLights(trailer, 1, leftSignal)
        end
    end,
})

    xLib.addKeybind({
    name = "esx_hud:indicator:right",
    description = Translate("indicatorRight"),
    defaultMapper = "keyboard",
    defaultKey = "RIGHT",
    onPressed = function()
        if not HUD.Data.Vehicle then
            return
        end
        if HUD.Data.VehicleType == "AIR" then
            return
        end
        rightSignal = not rightSignal
        SetVehicleIndicatorLights(HUD.Data.Vehicle, 0, rightSignal)

        local isAttached, trailer = GetVehicleTrailerVehicle(HUD.Data.Vehicle)
        if isAttached and DoesEntityExist(trailer) then
            SetVehicleIndicatorLights(trailer, 0, rightSignal)
        end
    end,
})

    xLib.addKeybind({
    name = "esx_hud:indicator:Hazard",
    description = Translate("indicatorHazard"),
    defaultMapper = "keyboard",
    defaultKey = "UP",
    onPressed = function()
        if not HUD.Data.Vehicle then
            return
        end
        if HUD.Data.VehicleType == "AIR" then
            return
        end
        if leftSignal ~= rightSignal then
            leftSignal = true
            rightSignal = true
        else
            leftSignal = not leftSignal
            rightSignal = not rightSignal
        end
        SetVehicleIndicatorLights(HUD.Data.Vehicle, 0, rightSignal)
        SetVehicleIndicatorLights(HUD.Data.Vehicle, 1, leftSignal)

        local isAttached, trailer = GetVehicleTrailerVehicle(HUD.Data.Vehicle)
        if isAttached and DoesEntityExist(trailer) then
            SetVehicleIndicatorLights(trailer, 0, rightSignal)
            SetVehicleIndicatorLights(trailer, 1, leftSignal)
        end
    end,
})

    xLib.addKeybind({
    name = "esx_hud:toggleEngine",
    description = Translate("toggleEngine"),
    defaultMapper = "keyboard",
    defaultKey = "N",
    onPressed = function()
        if not HUD.Data.Vehicle then
            return
        end
        local engineState = GetIsVehicleEngineRunning(HUD.Data.Vehicle)
        engineState = not engineState
        SetVehicleEngineOn(HUD.Data.Vehicle, engineState, false, true)
    end,
})
end
