-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local cruiseControlStatus = false
local isPassenger = false
local isSeatbeltOn = false
local p = promise:new()

local function SetCruiseControlState(state)
    cruiseControlStatus = state
end

local function SetSeatbeltState(state)
    isSeatbeltOn = state
end

exports("CruiseControlState", SetCruiseControlState)
exports("SeatbeltState", SetSeatbeltState)

if not Config.Disable.Vehicle then
    local vehicleType, playerPos
    local currentMileage = 0
    local currentMileageLoaded = false

    HUD.Data.Driver = false

    local values = {
        show = false,
        defaultIndicators = {},
    }

    local function driverCheck(currentVehicle)
        return DoesEntityExist(currentVehicle) and (GetPedInVehicleSeat(currentVehicle, -1) == ESX.PlayerData.ped)
    end

    exports("GetCurrentMileage", function()
        if not currentMileageLoaded then
            return nil, Config.Default.Kmh, false
        end

        return currentMileage, Config.Default.Kmh, true
    end)

    CreateThread(function()
        while true do
            local currentVehicle = Citizen.Await(p)
            if currentVehicle then
                HUD.Data.Driver = driverCheck(currentVehicle)
                playerPos = GetEntityCoords(ESX.PlayerData.ped).xy

                if not Config.Default.PassengerSpeedo then
                    if HUD.Data.Driver then
                        isPassenger = false
                    else
                        xLib.nui.send({ type = "VEH_HUD", value = { show = false } })
                        isPassenger = true
                    end
                end
            end
            Wait(1000)
        end
    end)

    CreateThread(function()
        local oldPos
        while true do
            local currentVehicle = Citizen.Await(p)
            if currentVehicle and DoesEntityExist(currentVehicle) then
                local engineHealth = math.floor(GetVehicleEngineHealth(currentVehicle) / 10)
                local _, lowBeam, highBeam = GetVehicleLightsState(currentVehicle)
                local indicator = GetVehicleIndicatorLights(currentVehicle)
                local tempDoorLockStatus = GetVehicleDoorLockStatus(currentVehicle)

                if engineHealth < 0 then
                    engineHealth = 0
                end

                local lightState = lowBeam == 1 or highBeam == 1
                local indicatorLeft = indicator == 1 or indicator == 3
                local indicatorRight = indicator == 2 or indicator == 3
                local doorLockStatus = tempDoorLockStatus == 2 or tempDoorLockStatus == 3

                if IsVehicleOnAllWheels(currentVehicle) then
                    if oldPos then
                        local distance = #(oldPos - playerPos)
                        if distance >= 10 then
                            currentMileage += Config.Default.Kmh and distance / 1000 or distance / 1620
                            currentMileage = ESX.Math.Round(currentMileage, 2)
                            oldPos = playerPos
                        end
                    else
                        oldPos = playerPos
                    end
                end

                values.fuel = { level = HUD:FuelExport() or 100, maxLevel = 100 }
                values.mileage = currentMileage
                values.kmh = Config.Default.Kmh
                values.damage = engineHealth
                values.vehType = vehicleType
                values.driver = HUD.Data.Driver
                values.defaultIndicators.seatbelt = isSeatbeltOn
                values.defaultIndicators.tempomat = cruiseControlStatus
                values.defaultIndicators.door = doorLockStatus
                values.defaultIndicators.light = lightState
                values.defaultIndicators.leftIndex = indicatorLeft
                values.defaultIndicators.rightIndex = indicatorRight
            end
            Wait(200)
        end
    end)

    CreateThread(function()
        while true do
            local currentVehicle = Citizen.Await(p)
            if currentVehicle and DoesEntityExist(currentVehicle) then
                local currentSpeed = GetEntitySpeed(currentVehicle)
                local engineRunning = GetIsVehicleEngineRunning(currentVehicle)
                local rpm

                if vehicleType == "LAND" or vehicleType == "MOTO" then
                    rpm = engineRunning and (GetVehicleCurrentRpm(currentVehicle) * 450) or 0
                else
                    rpm = math.ceil(ESX.PlayerData.coords.z)
                end

                values.speed = math.floor(currentSpeed * (Config.Default.Kmh and 3.6 or 2.236936))
                values.rpm = rpm
                values.gear = GetVehicleCurrentGear(currentVehicle)
                values.defaultIndicators.engine = engineRunning

                if not isPassenger then
                    xLib.nui.send({ type = "VEH_HUD", value = values })
                end
            end
            Wait(50)
        end
    end)

    AddEventHandler("esx:enteredVehicle", function(currentVehicle, currentPlate, currentSeat, displayName, netId)
        local vehicleClass = GetVehicleClass(currentVehicle)
        if vehicleClass == 13 then
            return
        end

        HUD.Data.Driver = currentSeat == -1 or false
        HUD.Data.Vehicle = currentVehicle
        vehicleType = "LAND"

        if vehicleClass == 15 or vehicleClass == 16 then
            vehicleType = "AIR"
        elseif vehicleClass == 14 then
            vehicleType = "BOAT"
        elseif vehicleClass == 8 then
            vehicleType = "MOTO"
        end

        HUD:UpdateRadar()

        if HUD.Data.Driver then
            currentMileageLoaded = false
            TriggerServerEvent("esx_hud:EnteredVehicle", currentPlate, Config.Default.Kmh)
        end
        HUD.Data.VehicleType = vehicleType
        isPassenger = not HUD.Data.Driver and not Config.Default.PassengerSpeedo
        values.show = true
        p:resolve(currentVehicle)
    end)

    AddEventHandler("esx:exitedVehicle", function(currentVehicle, currentPlate, currentSeat, displayName, netId)
        p = promise:new()
        HUD.Data.Driver = false
        HUD.Data.Vehicle = nil
        vehicleType = nil
        HUD.Data.VehicleType = nil

        values = {
            show = false,
            defaultIndicators = {},
        }

        xLib.nui.send({ type = "VEH_HUD", value = { show = false } })

        HUD:UpdateRadar()

        if currentSeat == -1 then
            TriggerServerEvent("esx_hud:ExitedVehicle", currentPlate, currentMileage, Config.Default.Kmh)
        end
        currentMileage = 0
        currentMileageLoaded = false
        isPassenger = false
    end)

    RegisterNetEvent("esx_hud:UpdateMileage", function(mileage)
        currentMileage = tonumber(mileage) or 0
        currentMileageLoaded = true
    end)

    AddEventHandler("esx_hud:UnitChanged", function(state)
        if state then
            currentMileage = currentMileage * 1.61
        else
            currentMileage = currentMileage / 1.61
        end
        currentMileage = ESX.Math.Round(currentMileage, 2)
    end)
end
