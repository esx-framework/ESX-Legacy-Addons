xLib.nui.register("closePanel", function()
    xLib.nui.focus(false, false)
    return "ok"
end)

xLib.nui.register("unitChanged", function(state)
    if HUD.Data.Driver then
        if Config.Default.Kmh ~= state.unit then
            TriggerEvent("esx_hud:UnitChanged", state.unit)
        end
    end
    Config.Default.Kmh = state.unit
    return "ok"
end)

xLib.nui.register("minimapSettingChanged", function(state)
    Config.Disable.MinimapOnFoot = state.changed
    if IsPedOnFoot(ESX.PlayerData.ped) ~= 1 then
        return "ok"
    end
    DisplayRadar(not state.changed)
    return "ok"
end)

xLib.nui.register("notify", function(data)
    local state = data.state
    if state.reset then
        ESX.ShowNotification(Translate("settingsResetSuccess", 5000, "info"))
        return "ok"
    end
    ESX.ShowNotification(Translate("settingsSaveSuccess", 5000, "info"))
    return "ok"
end)
