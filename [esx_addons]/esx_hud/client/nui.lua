RegisterNUICallback("closePanel", function(data, cb)
    SetNuiFocus(false, false)
    cb("ok")
end)

RegisterNUICallback("unitChanged", function(state, cb)
    if HUD.Data.Driver then
        if Config.Default.Kmh ~= state.unit then
            TriggerEvent("esx_hud:UnitChanged", state.unit)
        end
    end
    Config.Default.Kmh = state.unit
    cb("ok")
end)

RegisterNUICallback("minimapSettingChanged", function(state, cb)
    Config.Disable.MinimapOnFoot = state.changed
    if IsPedOnFoot(ESX.PlayerData.ped) ~= 1 then
        return cb("ok")
    end
    DisplayRadar(not state.changed)
    cb("ok")
end)

RegisterNUICallback("notify", function(data, cb)
    local state = data.state
    if state.reset then
        ESX.ShowNotification(Translate("settingsResetSuccess", 5000, "info"))
        cb("ok")
        return
    end
    ESX.ShowNotification(Translate("settingsSaveSuccess", 5000, "info"))
    cb("ok")
end)
