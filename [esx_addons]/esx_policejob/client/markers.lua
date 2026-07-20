local A = POLICE

AddEventHandler('esx_policejob:hasEnteredMarker', function(station, part, partNum)
    if part == 'Cloakroom' then
        A.CurrentAction     = 'menu_cloakroom'
        A.CurrentActionMsg  = TranslateCap('open_cloackroom')
        A.CurrentActionData = {}

    elseif part == 'Armory' then
        A.CurrentAction     = 'menu_armory'
        A.CurrentActionMsg  = TranslateCap('open_armory')
        A.CurrentActionData = { station = station }

    elseif part == 'Vehicles' then
        A.CurrentAction     = 'menu_vehicle_spawner'
        A.CurrentActionMsg  = TranslateCap('garage_prompt')
        A.CurrentActionData = { station = station, part = part, partNum = partNum }

    elseif part == 'Helicopters' then
        A.CurrentAction     = 'Helicopters'
        A.CurrentActionMsg  = TranslateCap('helicopter_prompt')
        A.CurrentActionData = { station = station, part = part, partNum = partNum }

    elseif part == 'BossActions' then
        A.CurrentAction     = 'menu_boss_actions'
        A.CurrentActionMsg  = TranslateCap('open_bossmenu')
        A.CurrentActionData = {}
    end
end)

AddEventHandler('esx_policejob:hasExitedMarker', function()
    if not A.isInShopMenu then
        ESX.CloseContext()
    end
    A.CurrentAction = nil
end)

AddEventHandler('esx_policejob:hasEnteredEntityZone', function(entity)
    local playerPed = PlayerPedId()

    if ESX.PlayerData.job and ESX.PlayerData.job.name == 'police' and IsPedOnFoot(playerPed) then
        A.CurrentAction     = 'remove_entity'
        A.CurrentActionMsg  = TranslateCap('remove_prop')
        A.CurrentActionData = { entity = entity }
    end

    if GetEntityModel(entity) == `p_ld_stinger_s` then
        if IsPedInAnyVehicle(playerPed, false) then
            local vehicle = GetVehiclePedIsIn(playerPed)
            for i = 0, 7 do
                SetVehicleTyreBurst(vehicle, i, true, 1000)
            end
        end
    end
end)

AddEventHandler('esx_policejob:hasExitedEntityZone', function(entity)
    if A.CurrentAction == 'remove_entity' and A.CurrentActionData and A.CurrentActionData.entity == entity then
        A.CurrentAction = nil
    end
end)


CreateThread(function()
    while true do
        local Sleep = 1500
        if ESX.PlayerData.job and ESX.PlayerData.job.name == 'police' then
            Sleep = 500
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local isInMarker, hasExited = false, false
            local currentStation, currentPart, currentPartNum

            for k, v in pairs(Config.PoliceStations) do
                -- Vestiaires
                for i=1, #v.Cloakrooms do
                    local distance = #(playerCoords - v.Cloakrooms[i])
                    if distance < Config.DrawDistance then
                        DrawMarker(Config.MarkerType.Cloakrooms, v.Cloakrooms[i], 0.0, 0.0, 0.0, 0, 0.0, 0.0, 1.0, 1.0, 1.0, Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, 100, false, true, 2, true, false, false, false)
                        Sleep = 0
                        if distance < Config.MarkerSize.x then
                            isInMarker, currentStation, currentPart, currentPartNum = true, k, 'Cloakroom', i
                        end
                    end
                end

                -- Armureries
                for i=1, #v.Armories do
                    local distance = #(playerCoords - v.Armories[i])
                    if distance < Config.DrawDistance then
                        DrawMarker(Config.MarkerType.Armories, v.Armories[i], 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, 100, false, true, 2, true, false, false, false)
                        Sleep = 0
                        if distance < Config.MarkerSize.x then
                            isInMarker, currentStation, currentPart, currentPartNum = true, k, 'Armory', i
                        end
                    end
                end

                -- Garage voitures
                for i=1, #v.Vehicles do
                    local distance = #(playerCoords - v.Vehicles[i].Spawner)
                    if distance < Config.DrawDistance then
                        DrawMarker(Config.MarkerType.Vehicles, v.Vehicles[i].Spawner, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, 100, false, true, 2, true, false, false, false)
                        Sleep = 0
                        if distance < Config.MarkerSize.x then
                            isInMarker, currentStation, currentPart, currentPartNum = true, k, 'Vehicles', i
                        end
                    end
                end

                -- Héliport
                for i=1, #v.Helicopters do
                    local distance =  #(playerCoords - v.Helicopters[i].Spawner)
                    if distance < Config.DrawDistance then
                        DrawMarker(Config.MarkerType.Helicopters, v.Helicopters[i].Spawner, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, 100, false, true, 2, true, false, false, false)
                        Sleep = 0
                        if distance < Config.MarkerSize.x then
                            isInMarker, currentStation, currentPart, currentPartNum = true, k, 'Helicopters', i
                        end
                    end
                end

                -- Boss actions
                if Config.EnablePlayerManagement and ESX.PlayerData.job.grade_name == 'boss' then
                    for i=1, #v.BossActions do
                        local distance = #(playerCoords - v.BossActions[i])
                        if distance < Config.DrawDistance then
                            DrawMarker(Config.MarkerType.BossActions, v.BossActions[i], 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, 100, false, true, 2, true, false, false, false)
                            Sleep = 0
                            if distance < Config.MarkerSize.x then
                                isInMarker, currentStation, currentPart, currentPartNum = true, k, 'BossActions', i
                            end
                        end
                    end
                end
            end

            -- Enter/Exit
            if (isInMarker and not A.HasAlreadyEnteredMarker) or
               (isInMarker and (A.LastStation ~= currentStation or A.LastPart ~= currentPart or A.LastPartNum ~= currentPartNum)) then

                if (A.LastStation and A.LastPart and A.LastPartNum) and
                   (A.LastStation ~= currentStation or A.LastPart ~= currentPart or A.LastPartNum ~= currentPartNum) then
                    TriggerEvent('esx_policejob:hasExitedMarker', A.LastStation, A.LastPart, A.LastPartNum)
                    hasExited = true
                end

                A.HasAlreadyEnteredMarker = true
                A.LastStation = currentStation
                A.LastPart = currentPart
                A.LastPartNum = currentPartNum

                TriggerEvent('esx_policejob:hasEnteredMarker', currentStation, currentPart, currentPartNum)
            end

            if not hasExited and not isInMarker and A.HasAlreadyEnteredMarker then
                A.HasAlreadyEnteredMarker = false
                TriggerEvent('esx_policejob:hasExitedMarker', A.LastStation, A.LastPart, A.LastPartNum)
            end
        end
        Wait(Sleep)
    end
end)


CreateThread(function()
    local trackedEntities = {
        `prop_roadcone02a`,
        `prop_barrier_work05`,
        `p_ld_stinger_s`,
        `prop_boxpile_07d`,
        `hei_prop_cash_crate_half_full`
    }

    while true do
        local Sleep = 1500
        if ESX.PlayerData.job and ESX.PlayerData.job.name == 'police' then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local closestDistance = -1
            local closestEntity = nil

            for i=1, #trackedEntities do
                local object = GetClosestObjectOfType(playerCoords, 3.0, trackedEntities[i], false, false, false)
                if DoesEntityExist(object) then
                    Sleep = 500
                    local objCoords = GetEntityCoords(object)
                    local distance = #(playerCoords - objCoords)
                    if closestDistance == -1 or closestDistance > distance then
                        closestDistance = distance
                        closestEntity   = object
                    end
                end
            end

            if closestDistance ~= -1 and closestDistance <= 3.0 then
                if A.LastEntity ~= closestEntity then
                    TriggerEvent('esx_policejob:hasEnteredEntityZone', closestEntity)
                    A.LastEntity = closestEntity
                end
            else
                if A.LastEntity then
                    TriggerEvent('esx_policejob:hasExitedEntityZone', A.LastEntity)
                    A.LastEntity = nil
                end
            end
        end
        Wait(Sleep)
    end
end)
