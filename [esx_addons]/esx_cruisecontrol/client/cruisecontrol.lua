-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local speedStep = 10 / 2.236936
local maximumSpeed = 120 / 2.236936

CC = {
    cruiseActive = false,
    vehicle = nil,
    generation = 0,
    lastEngineHealth = 0,
    currentCCSpeed = 0,
    lastIdealPedalPressure = 0.0,
    Reset = function(self)
        local wasActive = self.cruiseActive

        self.cruiseActive = false
        self.vehicle = nil
        self.generation = self.generation + 1
        self.currentCCSpeed = 0
        self.lastEngineHealth = 0
        self.lastIdealPedalPressure = 0.0

        if wasActive then
            Utils:SetHudState(false)
        end
    end,
    ApplyIdealPedalPressure = function(self, currentSpeed)
        local difference = self.currentCCSpeed - currentSpeed
        local frameTime = math.max(0.0, math.min(GetFrameTime(), 0.1))
        local pressureLimit = Utils:IsSteering() and 0.4 or 1.0
        local correction = difference * 0.35
        local pressure = self.lastIdealPedalPressure + correction

        if
            (pressure > 0.0 or difference > 0.0)
            and (pressure < pressureLimit or difference < 0.0)
        then
            self.lastIdealPedalPressure = math.max(
                0.0,
                math.min(1.0, self.lastIdealPedalPressure + difference * frameTime * 0.1)
            )
        end

        pressure = math.max(0.0, math.min(pressureLimit, self.lastIdealPedalPressure + correction))

        SetControlNormal(0, 71, pressure)
    end,
    ChangeSpeed = function(self, increase)
        if not self.cruiseActive then
            return
        end

        if not Utils:DriverCheck() or Utils.vehicle ~= self.vehicle then
            return
        end

        if increase then
            if self.currentCCSpeed >= maximumSpeed then
                return
            end

            self.currentCCSpeed = math.min(maximumSpeed, self.currentCCSpeed + speedStep)
        else
            self.currentCCSpeed = math.max(0.0, self.currentCCSpeed - speedStep)

            if self.currentCCSpeed == 0.0 then
                self:Reset()
            end
        end
    end,
    Enable = function(self)
        if not Config.Cruise.Enable or self.cruiseActive then
            return
        end

        Utils:RefreshVehicle()

        if not Utils:DriverCheck() then
            return
        end

        local vehicle = Utils.vehicle
        local speed = Utils:GetSpeed()

        if
            not speed
            or speed <= 0.0
            or not GetIsVehicleEngineRunning(vehicle)
            or GetEntitySpeedVector(vehicle, true).y <= 0.0
        then
            return
        end

        self.generation = self.generation + 1

        local generation = self.generation

        self.vehicle = vehicle
        self.currentCCSpeed = speed
        self.lastEngineHealth = GetVehicleEngineHealth(vehicle)
        self.lastIdealPedalPressure = math.max(0.1, math.min(0.5, GetControlNormal(0, 71)))
        self.cruiseActive = true

        Utils:SetHudState(true)

        CreateThread(function()
            while self.cruiseActive and self.generation == generation do
                if
                    Utils.vehicle ~= vehicle
                    or not Utils:DriverCheck()
                    or not GetIsVehicleEngineRunning(vehicle)
                    or not IsControlEnabled(0, 71)
                    or IsControlPressed(0, 72)
                    or IsControlPressed(0, 76)
                    or IsDisabledControlPressed(0, 72)
                    or IsDisabledControlPressed(0, 76)
                then
                    self:Reset()
                    break
                end

                local engineHealth = GetVehicleEngineHealth(vehicle)
                local currentSpeed = Utils:GetSpeed()

                if
                    self.lastEngineHealth - engineHealth > 10
                    or not currentSpeed
                    or currentSpeed <= 0.0
                    or GetEntitySpeedVector(vehicle, true).y <= 0.0
                then
                    self:Reset()
                    break
                end

                self.lastEngineHealth = engineHealth
                self:ApplyIdealPedalPressure(currentSpeed)

                Wait(0)
            end
        end)
    end,
}

--Handlers
AddEventHandler('esx:playerPedChanged', function(newPed)
    CC:Reset()
    Utils.ped = newPed
    if Config.Seatbelt.Enable then
        SetPedConfigFlag(newPed, 32, not SB.seatbelt)
    end
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer, isNew, skin)
    CC:Reset()
    Utils:RefreshVehicle()
end)

AddEventHandler('esx:enteredVehicle', function(vehicle, plate, seat, displayName, netId)
    if Utils.vehicle ~= vehicle then
        CC:Reset()
    end

    Utils.vehicle = vehicle
    if not Config.Seatbelt.Enable then
        return
    end
    SB:Thread()
end)

AddEventHandler('esx:exitedVehicle', function(vehicle, plate, seat, displayName, netId)
    CC:Reset()
    Utils.vehicle = nil
    SB:SetState(false)
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    CC:Reset()

    if Config.Seatbelt.Enable then
        SetPedConfigFlag(Utils.ped, 32, true)
    end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end
    Utils:RefreshVehicle()
end)
