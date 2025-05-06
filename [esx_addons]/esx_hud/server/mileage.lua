if not Config.Disable.Vehicle then
    HUD.Mileage = {
        Data = {},
    }

    local Mileage = HUD.Mileage

    -- Create column in sql if not exist
    -- CREDIT: Overextended (https://github.com/overextended)
    CreateThread(function()
        local success, result = pcall(MySQL.query.await, "SELECT mileage FROM owned_vehicles")
        if not success then
            MySQL.query("ALTER TABLE owned_vehicles ADD COLUMN `mileage` FLOAT(10) DEFAULT 0; ")
        end
    end)

    function Mileage:Load(plate, playerId, kmh)
        MySQL.single("SELECT mileage FROM owned_vehicles WHERE plate = ?", { plate }, function(data)
            local mileage, owned
            if data then
                mileage, owned = data.mileage, true
                if kmh then
                    mileage = mileage * 1.61
                end
            else
                mileage, owned = math.random(100, 10000), false
            end
            self:Create(plate, mileage, owned, playerId)
        end)
    end

    function Mileage:Save()
        if next(Mileage.Data) then
            local parameters = {}
            for plate, data in pairs(Mileage.Data) do
                if data.owned then
                    parameters[#parameters + 1] = { data.mileage, plate }
                end
            end

            if next(parameters) then
                MySQL.prepare("UPDATE `owned_vehicles` SET `mileage` = ? WHERE `plate` = ?", parameters)
            end
        end
    end

    function Mileage:Create(plate, mileage, owned, playerId)
        self.Data[plate] = { mileage = mileage, owned = owned }
        self:UpdateClient(mileage, playerId)
    end

    function Mileage:Update(plate, mileage, playerId, kmh)
        if not self.Data[plate] then
            return
        end

        if kmh then
            mileage = mileage / 1.61
        end

        self.Data[plate].mileage = mileage
        if playerId then
            self:UpdateClient(mileage, playerId)
        end
    end

    function Mileage:Exist(plate, playerId, kmh)
        if self.Data[plate] then
            local milage = self.Data[plate].mileage
            if kmh then
                milage = self.Data[plate].mileage * 1.61
            end
            self:UpdateClient(milage, playerId)
            return
        end
        self:Load(plate, playerId, kmh)
    end

    -- Send date to client
    function Mileage:UpdateClient(mileage, playerId)
        TriggerClientEvent("esx_hud:UpdateMileage", playerId, mileage)
    end

    RegisterNetEvent("esx_hud:EnteredVehicle", function(plate, kmh)
        local playerId = source
        Mileage:Exist(plate, playerId, kmh)
    end)

    RegisterNetEvent("esx_hud:ExitedVehicle", function(plate, mileage, kmh)
        Mileage:Update(plate, mileage, source, kmh)
    end)

    -- Auto save every 5 min
    CreateThread(function()
        while true do
            Wait(1000 * 60 * 5)
            Mileage:Save()
        end
    end)

    -- Auto save on resource stop
    AddEventHandler("onResourceStop", function(resourceName)
        if GetCurrentResourceName() ~= resourceName then
            return
        end
        Mileage:Save()
    end)

    -- Auto save 10 sec before scheduled restart
    AddEventHandler("txAdmin:events:scheduledRestart", function(eventData)
        if eventData.secondsRemaining == 60 then
            CreateThread(function()
                Wait(50000)
                Mileage:Save()
            end)
        end
    end)

    -- Auto save on txAdmin server stop
    AddEventHandler("txAdmin:events:serverShuttingDown", function()
        Mileage:Save()
    end)
end
