-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

if not Config.Disable.Vehicle then
    HUD.Mileage = {
        Data = {},
    }

    local Mileage = HUD.Mileage
    local MAX_STORED_MILEAGE <const> = 99999999.99
    local MILES_TO_KILOMETERS <const> = 1.61

    local function numericMileage(value)
        value = tonumber(value)
        if not value or value ~= value or value == -math.huge then
            return nil
        end

        if value < 0 then
            return 0
        end

        return value
    end

    local function roundMileage(value)
        return math.floor(value * 100 + 0.5) / 100
    end

    local function storedMileageValue(value)
        local mileage = numericMileage(value)
        if not mileage then
            return 0
        end

        if mileage == math.huge or mileage > MAX_STORED_MILEAGE then
            return MAX_STORED_MILEAGE
        end

        return roundMileage(mileage)
    end

    local function clientMileageValue(value, kmh)
        local mileage = numericMileage(value)
        if not mileage then
            return nil
        end

        local maxMileage = kmh and (MAX_STORED_MILEAGE * MILES_TO_KILOMETERS) or MAX_STORED_MILEAGE
        if mileage == math.huge or mileage > maxMileage then
            mileage = maxMileage
        end

        return roundMileage(mileage)
    end

    local function plateKey(plate)
        if type(plate) ~= "string" then
            return nil
        end

        local key = plate:gsub("^%s+", ""):gsub("%s+$", ""):upper()
        if key == "" then
            return nil
        end

        return key
    end

    local function addUniquePlateValue(values, value)
        if type(value) ~= "string" or value == "" then
            return
        end

        for i = 1, #values do
            if values[i] == value then
                return
            end
        end

        values[#values + 1] = value
    end

    local function plateValues(plate)
        local values = {}
        local key = plateKey(plate)

        addUniquePlateValue(values, plate)
        addUniquePlateValue(values, key)

        return values, key
    end

    local function plateCondition(values)
        if #values <= 1 then
            return "`plate` = ?"
        end

        local placeholders = {}
        for i = 1, #values do
            placeholders[i] = "?"
        end

        return ("`plate` IN (%s)"):format(table.concat(placeholders, ", "))
    end

    local function mileageData(plate)
        local data = Mileage.Data[plate]
        if data then
            return data
        end

        local key = plateKey(plate)
        return key and Mileage.Data[key] or nil
    end

    local function cachedMileage(plate)
        local data = mileageData(plate)
        if data and data.owned then
            local mileage = tonumber(data.mileage)
            if mileage and data.kmh then
                mileage = mileage / MILES_TO_KILOMETERS
            end

            return storedMileageValue(mileage)
        end

        return nil
    end

    exports("GetMileage", cachedMileage)

    exports("GetMileages", function(plates)
        local mileages = {}
        if type(plates) ~= "table" then
            return mileages
        end

        for i = 1, #plates do
            local plate = plates[i]
            if type(plate) == "string" then
                local mileage = cachedMileage(plate)
                if mileage then
                    mileages[plate] = mileage
                end
            end
        end

        return mileages
    end)

    -- Create column in sql if not exist
    -- CREDIT: Overextended (https://github.com/overextended)
    CreateThread(function()
        local success, result = pcall(MySQL.query.await, "SELECT mileage FROM owned_vehicles")
        if not success then
            MySQL.query("ALTER TABLE owned_vehicles ADD COLUMN `mileage` DECIMAL(10,2) NOT NULL DEFAULT 0.00; ")
        end
    end)

    function Mileage:Load(plate, playerId, kmh)
        local values, key = plateValues(plate)
        if not key or #values == 0 then
            return self:UpdateClient(0, playerId)
        end

        MySQL.single(("SELECT plate, mileage FROM owned_vehicles WHERE %s LIMIT 1"):format(plateCondition(values)), values, function(data)
            local mileage, owned
            if data then
                mileage, owned = tonumber(data.mileage) or 0, true
                if kmh then
                    mileage = mileage * MILES_TO_KILOMETERS
                end
            else
                mileage, owned = math.random(100, 10000), false
            end
            self:Create(data and data.plate or plate, mileage, owned, playerId, kmh, key)
        end)
    end

    function Mileage:Save()
        if next(Mileage.Data) then
            local parameters = {}
            for _, data in pairs(Mileage.Data) do
                if data.owned and type(data.plate) == "string" then
                    local mileage = tonumber(data.mileage) or 0
                    if data.kmh then
                        mileage = mileage / MILES_TO_KILOMETERS
                    end

                    mileage = storedMileageValue(mileage)
                    parameters[#parameters + 1] = { mileage, data.plate }
                end
            end

            if next(parameters) then
                MySQL.prepare("UPDATE `owned_vehicles` SET `mileage` = ? WHERE `plate` = ?", parameters)
            end
        end
    end

    function Mileage:Create(plate, mileage, owned, playerId, kmh, key)
        local cacheKey = key or plateKey(plate)
        if not cacheKey then
            return
        end

        self.Data[cacheKey] = { plate = plate, mileage = mileage, owned = owned, kmh = kmh == true }
        self:UpdateClient(mileage, playerId)
    end

    function Mileage:Update(plate, mileage, playerId, kmh)
        local data = mileageData(plate)
        if not data then
            return
        end

        local clientMileage = clientMileageValue(mileage, kmh)
        if not clientMileage then
            return
        end

        local storedMileage = kmh and clientMileage / MILES_TO_KILOMETERS or clientMileage
        storedMileage = storedMileageValue(storedMileage)
        clientMileage = kmh and clientMileageValue(storedMileage * MILES_TO_KILOMETERS, true) or storedMileage

        data.mileage = storedMileage
        data.kmh = false

        if playerId then
            self:UpdateClient(clientMileage, playerId)
        end
    end

    function Mileage:Exist(plate, playerId, kmh)
        if mileageData(plate) then
            local milage = cachedMileage(plate) or 0
            if kmh then
                milage = milage * MILES_TO_KILOMETERS
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

    RegisterNetEvent("esx_hud:UpdateVehicleMileage", function(plate, mileage, kmh)
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
