local A = POLICE

function A.playCuffAnim(ped)
    RequestAnimDict(A.ARREST_DICT)
    local tries = 0
    while not HasAnimDictLoaded(A.ARREST_DICT) and tries < 100 do
        Wait(10); tries = tries + 1
    end
    TaskPlayAnim(ped, A.ARREST_DICT, A.ARREST_ANIM, 8.0, -8.0, -1, 49, 0.0, false, false, false)
end

function A.stopCuffAnim(ped)
    ClearPedSecondaryTask(ped)
    if HasAnimDictLoaded(A.ARREST_DICT) then
        RemoveAnimDict(A.ARREST_DICT)
    end
end

function A.cleanPlayer(playerPed)
    SetPedArmour(playerPed, 0)
    ClearPedBloodDamage(playerPed)
    ResetPedVisibleDamage(playerPed)
    ClearPedLastWeaponDamage(playerPed)
    ResetPedMovementClipset(playerPed, 0)
end

function POLICE.setUniform(uniform, playerPed)
    TriggerEvent('skinchanger:getSkin', function(skin)
        local uniformObject
        local sex = (skin.sex == 0) and "male" or "female"

        if Config.Uniforms and Config.Uniforms[uniform] and Config.Uniforms[uniform][sex] then
            uniformObject = Config.Uniforms[uniform][sex]
        end

        if uniformObject then
            TriggerEvent('skinchanger:loadClothes', skin, uniformObject)
            if uniform == 'bullet_wear' then
                SetPedArmour(playerPed, 100)
            end
        else
            ESX.ShowNotification(TranslateCap('no_outfit'))
        end
    end)
end

function ImpoundVehicle(vehicle)
    ESX.Game.DeleteVehicle(vehicle)
    ESX.ShowNotification(TranslateCap('impound_successful'))
    A.currentTask.busy = false
end
