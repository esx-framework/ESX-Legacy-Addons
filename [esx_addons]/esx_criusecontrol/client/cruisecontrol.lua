CC = {
    cruiseActive = false,
    increasePressure = false,
    lastEngineHealth = 0,
    currentCCSpeed = 0,
    lastIdealPedalPressure = 0.0,
    speedDiffTolerance = (0.5 / 3.6),
    Reset = function(self)
        if not Utils:DriverCheck() then return end
        if not self.cruiseActive then return end

        self.cruiseActive = false
        self.currentCCSpeed = 0
        self.lastEngineHealth = 0
        self.lastIdealPedalPressure = 0.0

        Utils:SetHudState(false)
    end,
    ApplyIdealPedalPressure = function(self)
        if not Utils:DriverCheck() then return end
        if not self.cruiseActive then return end

        if not self.increasePressure then
            self.increasePressure = true
        end
        SetControlNormal(0, 71, self.lastIdealPedalPressure)
    end,
    ChangeSpeed = function(self, state)
        if not Utils:DriverCheck() then return end
        if not self.cruiseActive then return end

        local currentSpeed = Utils:GetSpeed()

        if state then
            if currentSpeed >= 120 then return end
            currentSpeed += 10
            self.currentCCSpeed = currentSpeed
        else
            if currentSpeed == 0 then return end
            currentSpeed += -10
            if currentSpeed < 0 then currentSpeed = 0 end
            self.currentCCSpeed = currentSpeed
        end
    end,
    Enable = function(self)
        if not Config.Cruise.Enable then return end
        if not Utils:DriverCheck() then return end

        self.cruiseActive = true
        self.lastEngineHealth = GetVehicleEngineHealth(Utils.vehicle)

        CreateThread(function()
            self.currentCCSpeed = Utils:GetSpeed() or 0
            if self.currentCCSpeed == 0 then self.cruiseActive = false return end

            Utils:SetHudState(true)

            while self.cruiseActive do
                local engineHealth = GetVehicleEngineHealth(Utils.vehicle)

                if IsControlJustPressed(0, 72) or IsControlJustPressed(0, 76) then
                    self:Reset()
                end

                if self.lastEngineHealth and ((self.lastEngineHealth - engineHealth) > 10) then
                    self:Reset()
                else
                    self.lastEngineHealth = engineHealth
                end

                local curSpeed = Utils:GetSpeed() or 0
                if curSpeed == 0 then self:Reset() return end

                local diff = self.currentCCSpeed - curSpeed

                if diff > self.speedDiffTolerance then
                    local pedalPressure = 0.8

                    if Utils:IsSteering() then
                        pedalPressure = 0.4
                    end

                    if self.increasePressure then
                        self.lastIdealPedalPressure = self.lastIdealPedalPressure + 0.025
                        self.increasePressure = false
                    end

                    SetControlNormal(0, 71, pedalPressure)
                elseif diff > - (4 * self.speedDiffTolerance) then
                    self:ApplyIdealPedalPressure()
                else
                    self.lastIdealPedalPressure = 0.2
                end

                Wait(0)
            end
        end)
    end
}

--Handlers
AddEventHandler('esx:playerPedChanged', function(newPed)
    Utils.ped = newPed
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded',function(xPlayer, isNew, skin)
    Utils.ped = PlayerPedId()
end)

AddEventHandler('esx:enteredVehicle', function(vehicle, plate, seat, displayName, netId)
    Utils.vehicle = vehicle
    if not Config.Seatbelt.Enable then return end
    SB:Thread()
end)

AddEventHandler('esx:exitedVehicle', function(vehicle, plate, seat, displayName, netId)
    Utils.vehicle = nil
end)

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    Utils.ped = PlayerPedId()
end)