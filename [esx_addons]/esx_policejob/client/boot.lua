local A = POLICE

AddEventHandler('esx:onPlayerSpawn', function()
    A.isDead = false
    TriggerEvent('esx_policejob:unrestrain')
    if not A.hasAlreadyJoined then
        TriggerServerEvent('esx_policejob:spawned')
    end
    A.hasAlreadyJoined = true
end)

AddEventHandler('esx:onPlayerDeath', function()
    A.isDead = true
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        TriggerEvent('esx_policejob:unrestrain')
        TriggerEvent('esx_phone:removeSpecialContact', 'police')

        if Config.EnableESXService then
            TriggerServerEvent('esx_service:disableService', 'police')
        end

        if Config.EnableHandcuffTimer and A.handcuffTimer.active then
            ESX.ClearTimeout(A.handcuffTimer.task)
        end
    end
end)

function ImpoundVehicle(vehicle)
    ESX.Game.DeleteVehicle(vehicle)
    ESX.ShowNotification(TranslateCap('impound_successful'))
    A.currentTask.busy = false
end
