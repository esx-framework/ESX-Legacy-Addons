-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

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
    HUD:UpdateRadar()
    return "ok"
end)

xLib.nui.register("notify", function(data)
    local state = data.state
    if state == "reset" or (type(state) == "table" and state.reset) then
        ESX.ShowNotification(Translate("settingsResetSuccess"), "info", 5000)
        return "ok"
    end
    ESX.ShowNotification(Translate("settingsSaveSuccess"), "info", 5000)
    return "ok"
end)

-- Resend initial state only after the browser has installed its message listener.
xLib.nui.register("ready", function()
    HUD:SetHudColor()
    HUD:Toggle(ESX.PlayerLoaded and not HUD.Data.hudHidden and not IsPauseMenuActive())
    return "ok"
end)

xLib.nui.register("cinematicChanged", function(state)
    HUD.Data.cinematic = state.enabled == true
    HUD:UpdateRadar()
    return "ok"
end)
