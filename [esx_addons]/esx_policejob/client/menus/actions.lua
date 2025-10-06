local A = POLICE

function OpenPoliceActionsMenu()
    local elements = {
        {unselectable = true, icon = "fas fa-police", title = TranslateCap('menu_title')},
        {icon = "fas fa-user", title = TranslateCap('citizen_interaction'), value = 'citizen_interaction'},
        {icon = "fas fa-car", title = TranslateCap('vehicle_interaction'), value = 'vehicle_interaction'},
        {icon = "fas fa-object", title = TranslateCap('object_spawner'), value = 'object_spawner'}
    }

    ESX.OpenContext("right", elements, function(menu,element)
        local data = {current = element}

        if data.current.value == 'citizen_interaction' then
            local elements2 = {
                {unselectable = true, icon = "fas fa-user", title = element.title},
                {icon = "fas fa-idkyet", title = TranslateCap('id_card'), value = 'identity_card'},
                {icon = "fas fa-idkyet", title = TranslateCap('search'), value = 'search'},
                {icon = "fas fa-idkyet", title = TranslateCap('handcuff'), value = 'handcuff'},
                {icon = "fas fa-idkyet", title = TranslateCap('drag'), value = 'drag'},
                {icon = "fas fa-idkyet", title = TranslateCap('put_in_vehicle'), value = 'put_in_vehicle'},
                {icon = "fas fa-idkyet", title = TranslateCap('out_the_vehicle'), value = 'out_the_vehicle'},
                {icon = "fas fa-idkyet", title = TranslateCap('fine'), value = 'fine'},
                {icon = "fas fa-idkyet", title = TranslateCap('unpaid_bills'), value = 'unpaid_bills'}
            }

            if Config.EnableLicenses then
                elements2[#elements2+1] = {
                    icon = "fas fa-scroll",
                    title = TranslateCap('license_check'),
                    value = 'license'
                }
            end

            ESX.OpenContext("right", elements2, function(menu2,element2)
                local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
                if closestPlayer ~= -1 and closestDistance <= 3.0 then
                    local data2 = {current = element2}
                    local action = data2.current.value

                    if action == 'identity_card' then
                        OpenIdentityCardMenu(closestPlayer)
                    elseif action == 'search' then
                        OpenBodySearchMenu(closestPlayer)
                    elseif action == 'handcuff' then
                        TriggerServerEvent('esx_policejob:handcuff', GetPlayerServerId(closestPlayer))
                    elseif action == 'drag' then
                        TriggerServerEvent('esx_policejob:drag', GetPlayerServerId(closestPlayer))
                    elseif action == 'put_in_vehicle' then
                        TriggerServerEvent('esx_policejob:putInVehicle', GetPlayerServerId(closestPlayer))
                    elseif action == 'out_the_vehicle' then
                        TriggerServerEvent('esx_policejob:OutVehicle', GetPlayerServerId(closestPlayer))
                    elseif action == 'fine' then
                        OpenFineMenu(closestPlayer)
                    elseif action == 'license' then
                        ShowPlayerLicense(closestPlayer)
                    elseif action == 'unpaid_bills' then
                        OpenUnpaidBillsMenu(closestPlayer)
                    end
                else
                    ESX.ShowNotification(TranslateCap('no_players_nearby'))
                end
            end, function(menu)
                OpenPoliceActionsMenu()
            end)

        elseif data.current.value == 'vehicle_interaction' then
            local elements3  = {
                {unselectable = true, icon = "fas fa-car", title = element.title}
            }
            local playerPed = PlayerPedId()
            local vehicle = ESX.Game.GetVehicleInDirection()

            if DoesEntityExist(vehicle) then
                elements3[#elements3+1] = {icon = "fas fa-car", title = TranslateCap('vehicle_info'), value = 'vehicle_infos'}
                elements3[#elements3+1] = {icon = "fas fa-car", title = TranslateCap('pick_lock'), value = 'hijack_vehicle'}
                elements3[#elements3+1] = {icon = "fas fa-car", title = TranslateCap('impound'), value = 'impound'}
            end

            elements3[#elements3+1] = {
                icon = "fas fa-scroll",
                title = TranslateCap('search_database'),
                value = 'search_database'
            }

            ESX.OpenContext("right", elements3, function(menu3,element3)
                local data2 = {current = element3}
                local coords  = GetEntityCoords(playerPed)
                vehicle = ESX.Game.GetVehicleInDirection()
                local action  = data2.current.value

                if action == 'search_database' then
                    LookupVehicle(element3)
                elseif DoesEntityExist(vehicle) then
                    if action == 'vehicle_infos' then
                        local vehicleData = ESX.Game.GetVehicleProperties(vehicle)
                        OpenVehicleInfosMenu(vehicleData)
                    elseif action == 'hijack_vehicle' then
                        if IsAnyVehicleNearPoint(coords.x, coords.y, coords.z, 3.0) then
                            TaskStartScenarioInPlace(playerPed, 'WORLD_HUMAN_WELDING', 0, true)
                            Wait(20000)
                            ClearPedTasksImmediately(playerPed)
                            SetVehicleDoorsLocked(vehicle, 1)
                            SetVehicleDoorsLockedForAllPlayers(vehicle, false)
                            ESX.ShowNotification(TranslateCap('vehicle_unlocked'))
                        end
                    elseif action == 'impound' then
                        if A.currentTask.busy then return end
                        ESX.ShowHelpNotification(TranslateCap('impound_prompt'))
                        TaskStartScenarioInPlace(playerPed, 'CODE_HUMAN_MEDIC_TEND_TO_DEAD', 0, true)
                        A.currentTask.busy = true
                        A.currentTask.task = ESX.SetTimeout(10000, function()
                            ClearPedTasks(playerPed)
                            ImpoundVehicle(vehicle)
                            Wait(100)
                        end)
                        CreateThread(function()
                            while A.currentTask.busy do
                                Wait(1000)
                                vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 3.0, 0, 71)
                                if not DoesEntityExist(vehicle) and A.currentTask.busy then
                                    ESX.ShowNotification(TranslateCap('impound_canceled_moved'))
                                    ESX.ClearTimeout(A.currentTask.task)
                                    ClearPedTasks(playerPed)
                                    A.currentTask.busy = false
                                    break
                                end
                            end
                        end)
                    end
                else
                    ESX.ShowNotification(TranslateCap('no_vehicles_nearby'))
                end
            end, function(menu)
                OpenPoliceActionsMenu()
            end)

        elseif data.current.value == "object_spawner" then
            local elements4 = {
                {unselectable = true, icon = "fas fa-object", title = element.title},
                {icon = "fas fa-cone", title = TranslateCap('cone'), model = 'prop_roadcone02a'},
                {icon = "fas fa-cone", title = TranslateCap('barrier'), model = 'prop_barrier_work05'},
                {icon = "fas fa-cone", title = TranslateCap('spikestrips'), model = 'p_ld_stinger_s'},
                {icon = "fas fa-cone", title = TranslateCap('box'), model = 'prop_boxpile_07d'},
                {icon = "fas fa-cone", title = TranslateCap('cash'), model = 'hei_prop_cash_crate_half_full'}
            }

            ESX.OpenContext("right", elements4, function(menu4,element4)
                local data2 = {current = element4}
                local playerPed = PlayerPedId()
                local coords, forward = GetEntityCoords(playerPed), GetEntityForwardVector(playerPed)
                local objectCoords = (coords + forward * 1.0)
                ESX.Game.SpawnObject(data2.current.model, objectCoords, function(obj)
                    Wait(100)
                    SetEntityHeading(obj, GetEntityHeading(playerPed))
                    PlaceObjectOnGroundProperly(obj)
                end)
            end, function(menu)
                OpenPoliceActionsMenu()
            end)
        end
    end)
end
