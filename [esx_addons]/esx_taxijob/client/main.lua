local show_text, OnJob, IsNearCustomer, CustomerIsEnteringVehicle, CustomerEnteredVehicle,
    CurrentActionData = false, false, false, false, false, {}
local CurrentCustomer, CurrentCustomerBlip, DestinationBlip, targetCoords, CurrentAction, CurrentActionMsg, lastSelectedNPC

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    ESX.PlayerData = xPlayer
    ESX.PlayerLoaded = true
end)

RegisterNetEvent('esx:onPlayerLogout')
AddEventHandler('esx:onPlayerLogout', function()
    ESX.PlayerLoaded = false
    ESX.PlayerData = {}
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    ESX.PlayerData.job = job
end)

function DrawSub(msg, time)
    ClearPrints()
    BeginTextCommandPrint('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandPrint(time, 1)
end

function ShowLoadingPromt(msg, time, type)
    CreateThread(function()
        Wait(0)

        BeginTextCommandBusyspinnerOn('STRING')
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandBusyspinnerOn(type)
        Wait(time)

        BusyspinnerOff()
    end)
end

function GetRandomWalkingNPC()
    local search = {}
    local peds = GetGamePool("CPed")

    for i = 1, #peds, 1 do
        if IsPedHuman(peds[i]) and IsPedWalking(peds[i]) and not IsPedAPlayer(peds[i]) then
            if peds[i] ~= lastSelectedNPC then
                search[#search+1] = peds[i]
            end
        end
    end

    if #search > 0 then
        local selectedNPC = search[math.random(#search)]
        lastSelectedNPC = selectedNPC
        return selectedNPC
    else
        return nil
    end
end

function ClearCurrentMission()
    if DoesBlipExist(CurrentCustomerBlip) then
        RemoveBlip(CurrentCustomerBlip)
    end

    if DoesBlipExist(DestinationBlip) then
        RemoveBlip(DestinationBlip)
    end

    CurrentCustomer = nil
    CurrentCustomerBlip = nil
    DestinationBlip = nil
    IsNearCustomer = false
    CustomerIsEnteringVehicle = false
    CustomerEnteredVehicle = false
    targetCoords = nil
end

function StartTaxiJob()
    ShowLoadingPromt(TranslateCap('taking_service'), 5000, 3)
    ClearCurrentMission()

    OnJob = true
end

function StopTaxiJob()
    local playerPed = PlayerPedId()

    if IsPedInAnyVehicle(playerPed, false) and CurrentCustomer ~= nil then
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        TaskLeaveVehicle(CurrentCustomer, vehicle, 0)

        if CustomerEnteredVehicle then
            TaskGoStraightToCoord(CurrentCustomer, targetCoords.x, targetCoords.y, targetCoords.z, 1.0, -1, 0.0, 0.0)
        end
    end

    ClearCurrentMission()
    OnJob = false
    DrawSub(TranslateCap('mission_complete'), 5000)
end

function OpenCloakroom()
    local elements = {
        {unselectable = true, icon = "fas fa-shirt", title = TranslateCap('cloakroom_menu')},
        {icon = "fas fa-shirt", title = TranslateCap('wear_citizen'), value = "wear_citizen"},
        {icon = "fas fa-shirt", title = TranslateCap('wear_work'), value = "wear_work"},
    }

    ESX.OpenContext("right", elements, function(menu,element)
        if element.value == "wear_citizen" then
            ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
                TriggerEvent('skinchanger:loadSkin', skin)
            end)
        elseif element.value == "wear_work" then
            ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin, jobSkin)
                if skin.sex == 0 then
                    TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_male)
                else
                    TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_female)
                end
            end)
        end
    end, function(menu)
        CurrentAction = 'cloakroom'
        CurrentActionMsg = TranslateCap('cloakroom_prompt')
        CurrentActionData = {}
    end)
end

function OpenVehicleSpawnerMenu()
    local elements = {
        {unselectable = true, icon = "fas fa-car", title = TranslateCap('spawn_veh')}
    }

    if Config.EnableSocietyOwnedVehicles then
        ESX.TriggerServerCallback('esx_society:getVehiclesInGarage', function(vehicles)

            for i = 1, #vehicles, 1 do
                elements[#elements+1] = {
                    icon = "fas fa-car",
                    title = GetDisplayNameFromVehicleModel(vehicles[i].model) .. ' [' .. vehicles[i].plate .. ']',
                    value = vehicles[i]
                }
            end

            ESX.OpenContext("right", elements, function(menu,element)
                if not ESX.Game.IsSpawnPointClear(Config.Zones.VehicleSpawnPoint.Pos, 5.0) then
                    ESX.ShowNotification(TranslateCap('spawnpoint_blocked'))
                    return
                end

                local vehicleProps = element.value
                ESX.TriggerServerCallback("esx_taxijob:SpawnVehicle", function()
                    return
                end, vehicleProps.model, vehicleProps)
                TriggerServerEvent('esx_society:removeVehicleFromGarage', 'taxi', vehicleProps)
                ESX.CloseContext()
            end, function(menu)
                CurrentAction = 'vehicle_spawner'
                CurrentActionMsg = TranslateCap('spawner_prompt')
                CurrentActionData = {}
            end)
        end, 'taxi')
    else -- not society vehicles
        if #Config.AuthorizedVehicles == 0 then
            ESX.ShowNotification(TranslateCap('empty_authorized_vehicles_table'), "error")
            return
        end
        ESX.OpenContext("right", Config.AuthorizedVehicles, function(menu,element)
            if not element.model or string.len(element.model) == 0 then
                ESX.ShowNotification(TranslateCap('unknow_model'), "error")
                return
            end
            if not ESX.Game.IsSpawnPointClear(Config.Zones.VehicleSpawnPoint.Pos, 5.0) then
                ESX.ShowNotification(TranslateCap('spawnpoint_blocked'))
                return
            end
            ESX.TriggerServerCallback("esx_taxijob:SpawnVehicle", function()
                ESX.ShowNotification(TranslateCap('vehicle_spawned', element.title), "success")
            end, element.model, {plate = "TAXI JOB"})
            ESX.CloseContext()
        end, function(menu)
            CurrentAction = 'vehicle_spawner'
            CurrentActionMsg = TranslateCap('spawner_prompt')
            CurrentActionData = {}
        end)
    end
end

function DeleteJobVehicle()
    local playerPed = PlayerPedId()

    if Config.EnableSocietyOwnedVehicles then
        local vehicleProps = ESX.Game.GetVehicleProperties(CurrentActionData.vehicle)
        TriggerServerEvent('esx_society:putVehicleInGarage', 'taxi', vehicleProps)
        ESX.Game.DeleteVehicle(CurrentActionData.vehicle)
    else
        if IsInAuthorizedVehicle() then
            ESX.Game.DeleteVehicle(CurrentActionData.vehicle)

            if Config.MaxInService ~= -1 then
                TriggerServerEvent('esx_service:disableService', 'taxi')
            end
        else
            ESX.ShowNotification(TranslateCap('only_taxi'))
        end
    end
end

function OpenTaxiActionsMenu()
    local elements = {
        {unselectable = true, icon = "fas fa-taxi", title = TranslateCap('taxi')},
        {icon = "fas fa-box",title = TranslateCap('deposit_stock'),value = 'put_stock'}, 
        {icon = "fas fa-box", title = TranslateCap('take_stock'), value = 'get_stock'}
    }

    if Config.EnablePlayerManagement and ESX.PlayerData.job ~= nil and ESX.PlayerData.job.grade_name == 'boss' then
        elements[#elements+1] = {
            icon = "fas fa-wallet",
            title = TranslateCap('boss_actions'),
            value = "boss_actions"
        }
    end

    ESX.OpenContext("right", elements, function(menu,element)
        if Config.OxInventory and (element.value == 'put_stock' or element.value == 'get_stock') then
            exports.ox_inventory:openInventory('stash', 'society_taxi')
            return ESX.CloseContext()
        elseif element.value == 'put_stock' then
            OpenPutStocksMenu()
        elseif element.value == 'get_stock' then
            OpenGetStocksMenu()
        elseif element.value == 'boss_actions' then
            TriggerEvent('esx_society:openBossMenu', 'taxi', function(data, menu)
                menu.close()
            end)
        end
    end, function(menu)
        CurrentAction = 'taxi_actions_menu'
        CurrentActionMsg = TranslateCap('press_to_open')
        CurrentActionData = {}
    end)
end

function OpenMobileTaxiActionsMenu()
    local elements = {
        {unselectable = true, icon = "fas fa-taxi", title = TranslateCap('taxi')},
        {icon = "fas fa-scroll", title = TranslateCap('billing'), value = "billing"},
        {icon = "fas fa-taxi", title = TranslateCap('start_job'), value = "start_job"},
    }

    ESX.OpenContext("right", elements, function(menu,element)
        if element.value == "billing" then
            local elements2 = {
                {unselectable = true, icon = "fas fa-taxi", title = element.title},
                {title = TranslateCap('amount'), input = true, inputType = "number", inputMin = 1, inputMax = 250000, inputPlaceholder = TranslateCap('bill_amount')},
                {icon = "fas fa-check-double", title = TranslateCap('confirm'), value = "confirm"}
            }

            ESX.OpenContext("right", elements2, function(menu2,element2)
                local amount = tonumber(menu2.eles[2].inputValue)
                if amount == nil then
                    ESX.ShowNotification(TranslateCap('amount_invalid'))
                else
                    ESX.CloseContext()
                    local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
                    if closestPlayer == -1 or closestDistance > 3.0 then
                        ESX.ShowNotification(TranslateCap('no_players_near'))
                    else
                        TriggerServerEvent('esx_billing:sendBill', GetPlayerServerId(closestPlayer), 'society_taxi',
                            'Taxi', amount)
                        ESX.ShowNotification(TranslateCap('billing_sent'))
                    end
                end
            end)
        elseif element.value == "start_job" then
            if OnJob then
                ESX.CloseContext()
                StopTaxiJob()
            else
                if ESX.PlayerData.job ~= nil and ESX.PlayerData.job.name == 'taxi' then
                    local playerPed = PlayerPedId()
                    local vehicle = GetVehiclePedIsIn(playerPed, false)

                    if IsPedInAnyVehicle(playerPed, false) and GetPedInVehicleSeat(vehicle, -1) == playerPed then
                        if tonumber(ESX.PlayerData.job.grade) >= 3 then
                            ESX.CloseContext()
                            StartTaxiJob()
                        else
                            if IsInAuthorizedVehicle() then
                                ESX.CloseContext()
                                StartTaxiJob()
                            else
                                ESX.ShowNotification(TranslateCap('must_in_taxi'))
                            end
                        end
                    else
                        if tonumber(ESX.PlayerData.job.grade) >= 3 then
                            ESX.ShowNotification(TranslateCap('must_in_vehicle'))
                        else
                            ESX.ShowNotification(TranslateCap('must_in_taxi'))
                        end
                    end
                end
            end
        end
    end)
end

function IsInAuthorizedVehicle()
    local playerPed = PlayerPedId()
    local vehModel = GetEntityModel(GetVehiclePedIsIn(playerPed, false))

    for i = 1, #Config.AuthorizedVehicles, 1 do
        if Config.AuthorizedVehicles[i].model and vehModel == joaat(Config.AuthorizedVehicles[i].model) then
            return true
        end
    end

    return false
end

function OpenGetStocksMenu()
    ESX.TriggerServerCallback('esx_taxijob:getStockItems', function(items)
        local elements = {
            {unselectable = true, icon = "fas fa-box", title = TranslateCap('taxi_stock')}
        }

        for i = 1, #items, 1 do
            elements[#elements+1] = {
                icon = "fas fa-box",
                title = 'x' .. items[i].count .. ' ' .. items[i].label,
                value = items[i].name
            }
        end

        ESX.OpenContext("right", elements, function(menu,element)
            local itemName = element.value
            local elements2 = {
                {unselectable = true, icon = "fas fa-box", title = element.title},
                {title = TranslateCap('amount'), input = true, inputType = "number", inputMin = 1, inputMax = 100, inputPlaceholder = TranslateCap('withdraw_amount')},
                {icon = "fas fa-check-double", title = TranslateCap('confirm'), value = "confirm"}
            }

            ESX.OpenContext("right", elements2, function(menu2,element2)
                local count = tonumber(menu2.eles[2].inputValue)

                if count == nil then
                    ESX.ShowNotification(TranslateCap('quantity_invalid'))
                else
                    ESX.CloseContext()
                    TriggerServerEvent('esx_taxijob:getStockItem', itemName, count)

                    Wait(1000)
                    OpenGetStocksMenu()
                end
            end)
        end)
    end, function(menu)
        CurrentAction = 'taxi_actions_menu'
        CurrentActionMsg = TranslateCap('press_to_open')
        CurrentActionData = {}
    end)    
end

function OpenPutStocksMenu()
    ESX.TriggerServerCallback('esx_taxijob:getPlayerInventory', function(inventory)
        local elements = {
            {unselectable = true, icon = "fas fa-box", title = TranslateCap('inventory')}
        }

        for i = 1, #inventory.items, 1 do
            local item = inventory.items[i]
            if item.count > 0 then
                elements[#elements+1] = {
                    icon = "fas fa-box",
                    title = item.label .. ' x' .. item.count,
                    type = 'item_standard',
                    value = item.name
                }
            end
        end

        ESX.OpenContext("right", elements, function(menu,element)
            local itemName = element.value

            local elements2 = {
                {unselectable = true, icon = "fas fa-box", title = element.title},
                {title = TranslateCap('amount'), input = true, inputType = "number", inputMin = 1, inputMax = 100, inputPlaceholder = TranslateCap('deposit_amount')},
                {icon = "fas fa-check-double", title = "Confirm", value = "confirm"}
            }

            ESX.OpenContext("right", elements2, function(menu2,element2)
                local count = tonumber(menu2.eles[2].inputValue)

                if count == nil then
                    ESX.ShowNotification(TranslateCap('quantity_invalid'))
                else                    
                    ESX.CloseContext()
                    -- todo: refresh on callback
                    TriggerServerEvent('esx_taxijob:putStockItems', itemName, count)
                    Wait(1000)
                    OpenPutStocksMenu()
                end
            end)
        end)
    end, function(menu)
        CurrentAction = 'taxi_actions_menu'
        CurrentActionMsg = TranslateCap('press_to_open')
        CurrentActionData = {}
    end)  
end



-- Create Blips
CreateThread(function()
    local blip = AddBlipForCoord(Config.Zones.TaxiActions.Pos.x, Config.Zones.TaxiActions.Pos.y,
        Config.Zones.TaxiActions.Pos.z)

    SetBlipSprite(blip, 198)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 1.0)
    SetBlipColour(blip, 5)
    SetBlipAsShortRange(blip, true)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(TranslateCap('blip_taxi'))
    EndTextCommandSetBlipName(blip)
end)

CreateThread(function()
    while true do
        local sleep = 1500
        local playerCoords = GetEntityCoords(PlayerPedId())
        local isInMarker = false
        
        if ESX.PlayerData.job and ESX.PlayerData.job.name == 'taxi' then
            for k, v in pairs(Config.Zones) do
                local zonePos = vector3(v.Pos.x, v.Pos.y, v.Pos.z)
                local distance = #(playerCoords - zonePos)

                if v.Type ~= -1 and distance < Config.DrawDistance then
                    sleep = 0
                    DrawMarker(v.Type, v.Pos.x, v.Pos.y, v.Pos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, v.Size.x, v.Size.y,
                        v.Size.z, v.Color.r, v.Color.g, v.Color.b, 100, false, false, 2, v.Rotate, nil, nil, false)
                end

                if distance < v.Size.x and v.Type ~= -1 then
                    if k == 'VehicleDeleter' then
                        local playerPed = PlayerPedId()
                        local vehicle = GetVehiclePedIsIn(playerPed, false)
                        
                        if IsPedInAnyVehicle(playerPed, false) and GetPedInVehicleSeat(vehicle, -1) == playerPed then
                            isInMarker = true
                            CurrentAction = 'delete_vehicle'
                            CurrentActionMsg = TranslateCap('store_veh')
                            CurrentActionData = {
                                vehicle = vehicle
                            }
                        end
                    else
                        isInMarker = true
                        CurrentAction = k:lower()
                        CurrentActionMsg = TranslateCap(k:lower() .. '_prompt')
                        CurrentActionData = {}
                    end
                end
            end
        end
        
        if isInMarker and not show_text then
            show_text = true
            ESX.TextUI(CurrentActionMsg)
        elseif not isInMarker and show_text then
            show_text = false
            ESX.HideUI()
            CurrentAction = nil
        end
        
        if CurrentAction and not ESX.PlayerData.dead then
            if IsControlJustReleased(0, 38) and ESX.PlayerData.job and ESX.PlayerData.job.name == 'taxi' then
                if CurrentAction == 'taxiactions' then
                    OpenTaxiActionsMenu()
                elseif CurrentAction == 'cloakroom' then
                    OpenCloakroom()
                elseif CurrentAction == 'vehiclespawner' then
                    OpenVehicleSpawnerMenu()
                elseif CurrentAction == 'delete_vehicle' then
                    DeleteJobVehicle()
                end

                CurrentAction = nil
            end
        end
        
        Wait(sleep)
    end
end)

-- Taxi Job
CreateThread(function()
    while true do
        local Sleep = 1500

        if OnJob then
            Sleep = 0
            local playerPed = PlayerPedId()
            if CurrentCustomer == nil then
                DrawSub(TranslateCap('drive_search_pass'), 5000)
            
                if IsPedInAnyVehicle(playerPed, false) and OnJob then
                    Wait(5000)
                        CurrentCustomer = GetRandomWalkingNPC()

                        if CurrentCustomer ~= nil then
                            CurrentCustomerBlip = AddBlipForEntity(CurrentCustomer)

                            SetBlipAsFriendly(CurrentCustomerBlip, true)
                            SetBlipColour(CurrentCustomerBlip, 2)
                            SetBlipCategory(CurrentCustomerBlip, 3)
                            SetBlipRoute(CurrentCustomerBlip, true)

                            SetEntityAsMissionEntity(CurrentCustomer, true, false)
                            ClearPedTasksImmediately(CurrentCustomer)
                            SetBlockingOfNonTemporaryEvents(CurrentCustomer, true)

                            local standTime = GetRandomIntInRange(60000, 180000)
                            TaskStandStill(CurrentCustomer, standTime)

                            ESX.ShowNotification(TranslateCap('customer_found'))
                        end
                end
            else
                if IsPedFatallyInjured(CurrentCustomer) then
                    ESX.ShowNotification(TranslateCap('client_unconcious'))

                    if DoesBlipExist(CurrentCustomerBlip) then
                        RemoveBlip(CurrentCustomerBlip)
                    end

                    if DoesBlipExist(DestinationBlip) then
                        RemoveBlip(DestinationBlip)
                    end

                    SetEntityAsMissionEntity(CurrentCustomer, false, true)

                    CurrentCustomer, CurrentCustomerBlip, DestinationBlip, IsNearCustomer, CustomerIsEnteringVehicle, CustomerEnteredVehicle, targetCoords =
                        nil, nil, nil, false, false, false, nil
                end

                if IsPedInAnyVehicle(playerPed, false) then
                    local vehicle = GetVehiclePedIsIn(playerPed, false)
                    local playerCoords = GetEntityCoords(playerPed)
                    local customerCoords = GetEntityCoords(CurrentCustomer)
                    local customerDistance = #(playerCoords - customerCoords)

                    if IsPedSittingInVehicle(CurrentCustomer, vehicle) then
                        if CustomerEnteredVehicle then
                            local targetDistance = #(playerCoords - targetCoords)

                            if targetDistance <= 10.0 then
                                TaskLeaveVehicle(CurrentCustomer, vehicle, 0)

                                ESX.ShowNotification(TranslateCap('arrive_dest'))

                                TaskGoStraightToCoord(CurrentCustomer, targetCoords.x, targetCoords.y, targetCoords.z,
                                    1.0, -1, 0.0, 0.0)
                                SetEntityAsMissionEntity(CurrentCustomer, false, true)
                                TriggerServerEvent('esx_taxijob:success')
                                RemoveBlip(DestinationBlip)

                                local function scope(customer)
                                    ESX.SetTimeout(60000, function()
                                        DeletePed(customer)
                                    end)
                                end

                                scope(CurrentCustomer)

                                CurrentCustomer, CurrentCustomerBlip, DestinationBlip, IsNearCustomer, CustomerIsEnteringVehicle, CustomerEnteredVehicle, targetCoords =
                                    nil, nil, nil, false, false, false, nil
                            end

                            if targetCoords then
                                DrawMarker(36, targetCoords.x, targetCoords.y, targetCoords.z + 1.1, 0.0, 0.0, 0.0, 0.0,
                                    0.0, 0.0, 1.0, 1.0, 1.0, 234, 223, 72, 155, false, false, 2, true, nil, nil, false)
                            end
                        else
                            RemoveBlip(CurrentCustomerBlip)
                            CurrentCustomerBlip = nil
                            targetCoords = Config.JobLocations[GetRandomIntInRange(1, #Config.JobLocations)]
                            local distance = #(playerCoords - targetCoords)
                            while distance < Config.MinimumDistance do
                                Wait(0)

                                targetCoords = Config.JobLocations[GetRandomIntInRange(1, #Config.JobLocations)]
                                distance = #(playerCoords - targetCoords)
                            end

                            local street = table.pack(GetStreetNameAtCoord(targetCoords.x, targetCoords.y,
                                targetCoords.z))
                            local msg = nil

                            if street[2] ~= 0 and street[2] ~= nil then
                                msg = string.format(TranslateCap('take_me_to_near', GetStreetNameFromHashKey(street[1]),
                                    GetStreetNameFromHashKey(street[2])))
                            else
                                msg = string.format(TranslateCap('take_me_to', GetStreetNameFromHashKey(street[1])))
                            end

                            ESX.ShowNotification(msg)

                            DestinationBlip = AddBlipForCoord(targetCoords.x, targetCoords.y, targetCoords.z)

                            BeginTextCommandSetBlipName('STRING')
                            AddTextComponentSubstringPlayerName('Destination')
                            EndTextCommandSetBlipName(DestinationBlip)
                            SetBlipRoute(DestinationBlip, true)

                            CustomerEnteredVehicle = true
                        end
                    else
                        DrawMarker(36, customerCoords.x, customerCoords.y, customerCoords.z + 1.1, 0.0, 0.0, 0.0, 0.0,
                            0.0, 0.0, 1.0, 1.0, 1.0, 234, 223, 72, 155, false, false, 2, true, nil, nil, false)

                        if not CustomerEnteredVehicle then
                            if customerDistance <= 40.0 then

                                if not IsNearCustomer then
                                    ESX.ShowNotification(TranslateCap('close_to_client'))
                                    IsNearCustomer = true
                                end

                            end

                            if customerDistance <= 20.0 then
                                if not CustomerIsEnteringVehicle then
                                    ClearPedTasksImmediately(CurrentCustomer)

                                    local maxSeats, freeSeat = GetVehicleMaxNumberOfPassengers(vehicle)

                                    for i = maxSeats - 1, 0, -1 do
                                        if IsVehicleSeatFree(vehicle, i) then
                                            freeSeat = i
                                            break
                                        end
                                    end

                                    if freeSeat then
                                        TaskEnterVehicle(CurrentCustomer, vehicle, -1, freeSeat, 2.0, 0)
                                        CustomerIsEnteringVehicle = true
                                    end
                                end
                            end
                        end
                    end
                else
                    DrawSub(TranslateCap('return_to_veh'), 5000)
                end
            end
        end
        Wait(Sleep)
    end
end)

CreateThread(function()
    while OnJob do
        Wait(10000)
        if ESX.PlayerData.job ~= nil and ESX.PlayerData.job.grade < 3 then
            if not IsInAuthorizedVehicle() then
                ClearCurrentMission()
                OnJob = false
                ESX.ShowNotification(TranslateCap('not_in_taxi'))
            end
        end
    end
end)



RegisterCommand('taximenu', function()
    if not ESX.PlayerData.dead and Config.EnablePlayerManagement and ESX.PlayerData.job and ESX.PlayerData.job.name ==
        'taxi' then
        OpenMobileTaxiActionsMenu()
    end
end, false)

RegisterKeyMapping('taximenu', 'Open Taxi Menu', 'keyboard', 'f6')
