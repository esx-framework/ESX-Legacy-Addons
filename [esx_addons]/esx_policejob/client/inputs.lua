local A = POLICE

ESX.RegisterInput("police:interact", "(ESX PoliceJob) " .. TranslateCap('interaction'), "keyboard", "E", function()
    if not A.CurrentAction then return end
    if (not ESX.PlayerData.job) or (ESX.PlayerData.job.name ~= 'police') then
        return
    end

    if A.CurrentAction == 'menu_cloakroom' then
        OpenCloakroomMenu()

    elseif A.CurrentAction == 'menu_armory' then
        if not Config.EnableESXService or A.playerInService then
            OpenArmoryMenu(A.CurrentActionData.station)
        else
            ESX.ShowNotification(TranslateCap('service_not'))
        end

    elseif A.CurrentAction == 'menu_vehicle_spawner' then
        if not Config.EnableESXService or A.playerInService then
            OpenVehicleSpawnerMenu('car', A.CurrentActionData.station, A.CurrentActionData.part, A.CurrentActionData.partNum)
        else
            ESX.ShowNotification(TranslateCap('service_not'))
        end

    elseif A.CurrentAction == 'Helicopters' then
        if not Config.EnableESXService or A.playerInService then
            OpenVehicleSpawnerMenu('helicopter', A.CurrentActionData.station, A.CurrentActionData.part, A.CurrentActionData.partNum)
        else
            ESX.ShowNotification(TranslateCap('service_not'))
        end

    elseif A.CurrentAction == 'delete_vehicle' then
        ESX.Game.DeleteVehicle(A.CurrentActionData.vehicle)

    elseif A.CurrentAction == 'menu_boss_actions' then
        ESX.CloseContext()
        TriggerEvent('esx_society:openBossMenu', 'police', function()
            ESX.CloseContext()
            A.CurrentAction     = 'menu_boss_actions'
            A.CurrentActionMsg  = TranslateCap('open_bossmenu')
            A.CurrentActionData = {}
        end, { wash = false })

    elseif A.CurrentAction == 'remove_entity' then
        if A.CurrentActionData and A.CurrentActionData.entity and DoesEntityExist(A.CurrentActionData.entity) then
            DeleteEntity(A.CurrentActionData.entity)
        end
    end

    A.CurrentAction = nil
end)

ESX.RegisterInput("police:quickactions", "(ESX PoliceJob) "..TranslateCap('quick_actions'), "keyboard", "F6", function()
    if not ESX.PlayerData.job or (ESX.PlayerData.job.name ~= 'police') or A.isDead then
        return
    end
    if not Config.EnableESXService or A.playerInService then
        OpenPoliceActionsMenu()
    else
        ESX.ShowNotification(TranslateCap('service_not'))
    end
end)

CreateThread(function()
    while true do
        local Sleep = 1000
        if A.CurrentAction then
            Sleep = 0
            ESX.ShowHelpNotification(A.CurrentActionMsg)
        end
        Wait(Sleep)
    end
end)
