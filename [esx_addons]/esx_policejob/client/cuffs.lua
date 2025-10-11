local A = POLICE

RegisterNetEvent('esx_policejob:handcuff')
AddEventHandler('esx_policejob:handcuff', function()
    A.isHandcuffed = not A.isHandcuffed
    local playerPed = PlayerPedId()

    if A.isHandcuffed then
        POLICE.playCuffAnim(playerPed)

        SetEnableHandcuffs(playerPed, true)
        DisablePlayerFiring(playerPed, true)
        SetCurrentPedWeapon(playerPed, `WEAPON_UNARMED`, true)
        SetPedCanPlayGestureAnims(playerPed, false)

        if Config.Cuffs and Config.Cuffs.FreezePlayer then
            FreezeEntityPosition(playerPed, true)
        else
            FreezeEntityPosition(playerPed, false)
            SetPedCanRagdoll(playerPed, true)
            SetPedMoveRateOverride(playerPed, 1.0)
            SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
        end

        DisplayRadar(false)
        SetEntityCollision(playerPed, true, true)
        SetEntityDynamic(playerPed, true)
        TriggerServerEvent('esx_policejob:cuffsState', true)

        if Config.EnableHandcuffTimer then
            if A.handcuffTimer.active then ESX.ClearTimeout(A.handcuffTimer.task) end
            StartHandcuffTimer()
        end
    else
        if Config.EnableHandcuffTimer and A.handcuffTimer.active then
            ESX.ClearTimeout(A.handcuffTimer.task)
        end

        POLICE.stopCuffAnim(playerPed)
        SetEnableHandcuffs(playerPed, false)
        DisablePlayerFiring(playerPed, false)
        SetPedCanPlayGestureAnims(playerPed, true)
        FreezeEntityPosition(playerPed, false)
        DisplayRadar(true)
        SetEntityCollision(playerPed, true, true)
        SetEntityDynamic(playerPed, true)

        TriggerServerEvent('esx_policejob:cuffsState', false)
    end
end)

RegisterNetEvent('esx_policejob:unrestrain')
AddEventHandler('esx_policejob:unrestrain', function()
    if not A.isHandcuffed then return end
    local playerPed = PlayerPedId()
    A.isHandcuffed = false

    POLICE.stopCuffAnim(playerPed)
    SetEnableHandcuffs(playerPed, false)
    DisablePlayerFiring(playerPed, false)
    SetPedCanPlayGestureAnims(playerPed, true)
    FreezeEntityPosition(playerPed, false)
    DisplayRadar(true)

    if Config.EnableHandcuffTimer and A.handcuffTimer.active then
        ESX.ClearTimeout(A.handcuffTimer.task)
    end

    TriggerServerEvent('esx_policejob:cuffsState', false)
end)

CreateThread(function()
    while true do
        if A.isHandcuffed and (not Config.Cuffs or not Config.Cuffs.FreezePlayer) then
            local ped = PlayerPedId()

            if IsPedUsingAnyScenario(ped) then
                ClearPedTasksImmediately(ped)
            end

            if IsEntityPlayingAnim(ped, A.ARREST_DICT, A.ARREST_ANIM, 3) ~= 1 then
                POLICE.playCuffAnim(ped)
            end

            FreezeEntityPosition(ped, false)

            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 47,  true)
            DisableControlAction(2, 36,  true)
            Wait(0)
        else
            Wait(300)
        end
    end
end)

RegisterNetEvent('esx_policejob:drag')
AddEventHandler('esx_policejob:drag', function(copId)
    if A.isHandcuffed then
        A.dragStatus.isDragged = not A.dragStatus.isDragged
        A.dragStatus.CopId = copId
    end
end)

CreateThread(function()
    local wasDragged
    while true do
        local sleep = 1500
        if A.isHandcuffed and A.dragStatus.isDragged then
            sleep = 50
            local targetPed = GetPlayerPed(GetPlayerFromServerId(A.dragStatus.CopId))
            if DoesEntityExist(targetPed) and IsPedOnFoot(targetPed) and not Player(A.dragStatus.CopId).state.isDead then
                if not wasDragged then
                    AttachEntityToEntity(PlayerPedId(), targetPed, 11816, 0.54, 0.54, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                    wasDragged = true
                else
                    Wait(1000)
                end
            else
                wasDragged = false
                A.dragStatus.isDragged = false
                DetachEntity(PlayerPedId(), true, false)
            end
        elseif wasDragged then
            wasDragged = false
            DetachEntity(PlayerPedId(), true, false)
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('esx_policejob:putInVehicle')
AddEventHandler('esx_policejob:putInVehicle', function()
    if A.isHandcuffed then
        local playerPed = PlayerPedId()
        local vehicle, distance = ESX.Game.GetClosestVehicle()
        if vehicle and distance < 5.0 then
            local maxSeats, freeSeat = GetVehicleMaxNumberOfPassengers(vehicle)
            for i=maxSeats - 1, 0, -1 do
                if IsVehicleSeatFree(vehicle, i) then freeSeat = i break end
            end
            if freeSeat then
                TaskWarpPedIntoVehicle(playerPed, vehicle, freeSeat)
                A.dragStatus.isDragged = false
            end
        end
    end
end)

RegisterNetEvent('esx_policejob:OutVehicle')
AddEventHandler('esx_policejob:OutVehicle', function()
    local ped = PlayerPedId()
    if IsPedSittingInAnyVehicle(ped) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        TaskLeaveVehicle(ped, vehicle, 64)
    end
end)

CreateThread(function()
    while true do
        local sleep = 1000
        if A.isHandcuffed and Config.Cuffs and Config.Cuffs.FreezePlayer then
            sleep = 0
            DisableControlAction(0, 1,   true)
            DisableControlAction(0, 2,   true)
            DisableControlAction(0, 24,  true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 25,  true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 32,  true)
            DisableControlAction(0, 34,  true)
            DisableControlAction(0, 31,  true)
            DisableControlAction(0, 30,  true)
            DisableControlAction(0, 45,  true)
            DisableControlAction(0, 22,  true)
            DisableControlAction(0, 44,  true)
            DisableControlAction(0, 37,  true)
            DisableControlAction(0, 23,  true)
            DisableControlAction(0, 288, true)
            DisableControlAction(0, 289, true)
            DisableControlAction(0, 170, true)
            DisableControlAction(0, 167, true)
            DisableControlAction(0, 0,   true)
            DisableControlAction(0, 26,  true)
            DisableControlAction(0, 73,  true)
            DisableControlAction(2, 199, true)
            DisableControlAction(0, 59,  true)
            DisableControlAction(0, 71,  true)
            DisableControlAction(0, 72,  true)
            DisableControlAction(2, 36,  true)
            DisableControlAction(0, 47,  true)
            DisableControlAction(0, 264, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 143, true)
            DisableControlAction(0, 75,  true)
            DisableControlAction(27, 75,  true)

            local ped = PlayerPedId()
            if IsEntityPlayingAnim(ped, 'mp_arresting', 'idle', 3) ~= 1 then
                ESX.Streaming.RequestAnimDict('mp_arresting', function()
                    TaskPlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0.0, false, false, false)
                    RemoveAnimDict('mp_arresting')
                end)
            end
        end
        Wait(sleep)
    end
end)

function StartHandcuffTimer()
    if Config.EnableHandcuffTimer and A.handcuffTimer.active then
        ESX.ClearTimeout(A.handcuffTimer.task)
    end
    A.handcuffTimer.active = true
    A.handcuffTimer.task = ESX.SetTimeout(Config.HandcuffTimer, function()
        ESX.ShowNotification(TranslateCap('unrestrained_timer'))
        TriggerEvent('esx_policejob:unrestrain')
        A.handcuffTimer.active = false
    end)
end
