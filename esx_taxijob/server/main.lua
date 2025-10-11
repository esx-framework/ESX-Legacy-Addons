local lastPlayerSuccess = {}

if Config.MaxInService ~= -1 then
    TriggerEvent('esx_service:activateService', 'taxi', Config.MaxInService)
end

TriggerEvent('esx_phone:registerNumber', 'taxi', TranslateCap('taxi_client'), true, true)
TriggerEvent('esx_society:registerSociety', 'taxi', 'Taxi', 'society_taxi', 'society_taxi', 'society_taxi', {
    type = 'public'
})

-- Reputation storage
local PlayerReputation = {}

RegisterNetEvent('esx_taxijob:success', function(tripData)
    local xPlayer = ESX.Player(source)
    local timeNow = os.clock()
    local job = xPlayer.getJob()
    if job.name ~= 'taxi' then
        print(('[^3WARNING^7] Player ^5%s^7 attempted to ^5esx_taxijob:success^7 (cheating)'):format(source))
        return
    end

    if not lastPlayerSuccess[source] or timeNow - lastPlayerSuccess[source] > 3 then
        lastPlayerSuccess[source] = timeNow
        
        -- Default trip data if not provided (backwards compatibility)
        tripData = tripData or {}
        local distance = tripData.distance or 3000
        local time = tripData.time or 60
        local perfectDrive = tripData.perfectDrive ~= false
        local vehicleMultiplier = tripData.vehicleMultiplier or 1.0
        local rushHour = tripData.rushHour or false
        local weatherMultiplier = tripData.weatherMultiplier or 1.0
        local missionType = tripData.missionType or 'normal'
        
        -- Initialize reputation if needed
        if not PlayerReputation[source] then
            PlayerReputation[source] = 50
        end

        -- Base earnings calculation
        local baseEarning = math.random(Config.NPCJobEarnings.min, Config.NPCJobEarnings.max)
        
        -- Distance-based earnings
        local distanceBonus = (distance * Config.DistanceMultiplier)
        
        -- Time-based earnings (for waiting)
        local timeBonus = (time * Config.TimeMultiplier)
        
        -- Calculate total before multipliers
        local total = baseEarning + distanceBonus + timeBonus
        
        -- Apply vehicle multiplier
        total = total * vehicleMultiplier
        
        -- Apply rush hour multiplier
        if rushHour and Config.EnableRushHour then
            total = total * Config.RushHourMultiplier
        end
        
        -- Apply weather multiplier
        if Config.EnableWeatherBonus then
            total = total * weatherMultiplier
        end
        
        -- Special mission bonuses
        if Config.EnableSpecialMissions then
            if missionType == 'vip' and Config.VIPClients.enabled then
                total = total + Config.VIPClients.bonus
            elseif missionType == 'airport' and Config.AirportRuns.enabled then
                total = total + Config.AirportRuns.bonus
            elseif missionType == 'longdistance' and Config.LongDistance.enabled then
                total = total + Config.LongDistance.bonus
            end
        end
        
        -- Reputation bonus
        if Config.EnableReputation and PlayerReputation[source] >= Config.ReputationBonusThreshold then
            total = total * Config.ReputationBonus
        end
        
        -- Grade bonus
        if job.grade >= 3 then
            total = total * 1.5
        end
        
        -- Round total
        total = ESX.Math.Round(total)
        
        -- Calculate tip
        local tip = 0
        if Config.EnableTips then
            local tipChance = math.random(100)
            if tipChance <= Config.TipChance then
                tip = math.random(Config.TipAmount.min, Config.TipAmount.max)
                
                -- Perfect drive tip bonus
                if perfectDrive then
                    tip = ESX.Math.Round(tip * Config.PerfectDriveTipBonus)
                end
            end
        end
        
        -- Update reputation
        if Config.EnableReputation then
            if perfectDrive then
                PlayerReputation[source] = math.min(Config.MaxReputation, PlayerReputation[source] + Config.ReputationGainPerJob)
            else
                PlayerReputation[source] = math.max(0, PlayerReputation[source] - Config.ReputationLossPerBadJob)
            end
            
            -- Send updated reputation to client
            TriggerClientEvent('esx_taxijob:updateReputation', source, PlayerReputation[source])
        end
        
        -- Distribute money
        TriggerEvent('esx_addonaccount:getSharedAccount', 'society_taxi', function(account)
            if account then
                local playerMoney = ESX.Math.Round(total / 100 * 30)
                local societyMoney = ESX.Math.Round(total / 100 * 70)

                xPlayer.addMoney(playerMoney + tip, "Taxi Fare")
                account.addMoney(societyMoney)
                
                -- Enhanced notification
                local msg = TranslateCap('comp_earned', societyMoney, playerMoney)
                if tip > 0 then
                    msg = msg .. ' ~g~+$' .. tip .. ' tip!'
                end
                if perfectDrive then
                    msg = msg .. ' ~b~Perfect Drive!'
                end
                xPlayer.showNotification(msg)
            else
                xPlayer.addMoney(total + tip, "Taxi Fare")
                local msg = TranslateCap('have_earned', total)
                if tip > 0 then
                    msg = msg .. ' ~g~+$' .. tip .. ' tip!'
                end
                xPlayer.showNotification(msg)
            end
        end)
    end
end)

ESX.RegisterServerCallback("esx_taxijob:SpawnVehicle", function(source, cb, model , props)
    local xPlayer = ESX.Player(source)

    if xPlayer.getJob().name ~= "taxi" then 
        print(('[^3WARNING^7] Player ^5%s^7 attempted to Exploit Vehicle Spawing!!'):format(source))
        return
    end

    local SpawnPoint = vector3(Config.Zones.VehicleSpawnPoint.Pos.x, Config.Zones.VehicleSpawnPoint.Pos.y, Config.Zones.VehicleSpawnPoint.Pos.z)
    ESX.OneSync.SpawnVehicle(joaat(model), SpawnPoint, Config.Zones.VehicleSpawnPoint.Heading, props, function(vehicle)
        local vehicle = NetworkGetEntityFromNetworkId(vehicle)
        while GetVehicleNumberPlateText(vehicle) ~= props.plate do
            Wait(0)
        end
        TaskWarpPedIntoVehicle(GetPlayerPed(source), vehicle, -1)
    end)
    cb()
end)

RegisterNetEvent('esx_taxijob:getStockItem', function(itemName, count)
    local xPlayer = ESX.Player(source)
    
    if xPlayer.getJob().name ~= 'taxi' then
        print(('[^3WARNING^7] Player ^5%s^7 attempted ^5esx_taxijob:getStockItem^7 (cheating)'):format(source))
        return
    end

    TriggerEvent('esx_addoninventory:getSharedInventory', 'society_taxi', function(inventory)
        local item = inventory.getItem(itemName)
        
        if not xPlayer.canCarryItem(itemName, count) then
            xPlayer.showNotification(TranslateCap('player_cannot_hold'))
            return
        end

        if count < 0 and item.count <= count then
            xPlayer.showNotification(TranslateCap('quantity_invalid'))
            return
        end

        inventory.removeItem(itemName, count)
        xPlayer.addInventoryItem(itemName, count)
        xPlayer.showNotification(TranslateCap('have_withdrawn', count, item.label))
    end)
end)

ESX.RegisterServerCallback('esx_taxijob:getStockItems', function(source, cb)
    TriggerEvent('esx_addoninventory:getSharedInventory', 'society_taxi', function(inventory)
        cb(inventory.items)
    end)
end)

RegisterNetEvent('esx_taxijob:putStockItems', function(itemName, count)
    local xPlayer = ESX.Player(source)
	local sourceItem = xPlayer.getInventoryItem(itemName)
    
    if xPlayer.getJob().name ~= 'taxi' then
        print(('[^3WARNING^7] Player ^5%s^7 attempted ^5esx_taxijob:putStockItems^7 (cheating)'):format(source))
        return
    end

    TriggerEvent('esx_addoninventory:getSharedInventory', 'society_taxi', function(inventory)
        local item = inventory.getItem(itemName)
        
        if sourceItem.count < count or count < 0 then
            return xPlayer.showNotification(TranslateCap('quantity_invalid'))
        end

        xPlayer.removeInventoryItem(itemName, count)
        inventory.addItem(itemName, count)
        xPlayer.showNotification(TranslateCap('have_deposited', count, item.label))
    end)
end)

ESX.RegisterServerCallback('esx_taxijob:getPlayerInventory', function(source, cb)
    local xPlayer = ESX.Player(source)
    local items = xPlayer.getInventory(false)
    cb({
        items = items
    })
end)

-- Get player reputation
ESX.RegisterServerCallback('esx_taxijob:getReputation', function(source, cb)
    if not PlayerReputation[source] then
        PlayerReputation[source] = 50 -- Default starting reputation
    end
    cb(PlayerReputation[source])
end)

-- Clean up reputation on player drop
AddEventHandler('playerDropped', function()
    local _source = source
    if PlayerReputation[_source] then
        PlayerReputation[_source] = nil
    end
end)
