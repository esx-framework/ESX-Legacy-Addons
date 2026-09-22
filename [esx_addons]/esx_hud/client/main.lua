-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

-- Keep server defaults immutable when NUI callbacks update runtime preferences.
local initialConfig = json.decode(json.encode(Config))

function HUD:UpdateRadar()
    local show = ESX.PlayerLoaded and not self.Data.hudHidden and not self.Data.cinematic and not IsPauseMenuActive()
    local inVehicle = self.Data.Vehicle ~= nil
    DisplayRadar(show and (inVehicle or not Config.Disable.MinimapOnFoot))
end

function HUD:Toggle(state)
    xLib.nui.send({ type = "SHOW", value = state })
    if state then self:UpdateRadar() else DisplayRadar(false) end
end

function HUD:GetTheme()
    local theme = xLib.colors.getESXTheme({
        primaryColor = Config.Default.AccentColor ~= "" and Config.Default.AccentColor or nil,
        secondaryColor = "#191919",
    })

    if theme.logoUrl == "" then
        theme.logoUrl = Config.Default.ServerLogo or ""
    end

    return theme
end

function HUD:SetHudColor()
    initialConfig.Theme = self:GetTheme()
    xLib.nui.send({ type = "SET_CONFIG_DATA", value = initialConfig })
end

function HUD:Start(xPlayer)
    while not ESX.PlayerLoaded do
        Wait(0)
    end

    if not xPlayer then
        xPlayer = ESX.GetPlayerData()
    end

    self:SetHudColor()
    self:SlowThick()
    self:FastThick()

    if not Config.Disable.Status then
        self:StatusThread()
    end

    if not Config.Disable.Money then
        self:UpdateAccounts(xPlayer.accounts)
    end

    if Config.Disable.MinimapOnFoot then
        DisplayRadar(false)
    end

    self:Toggle(true)
end

local function ToggleHud(state)
    HUD.Data.hudHidden = not state
    HUD:Toggle(state)
end

RegisterNetEvent("esx_hud:HudToggle", ToggleHud)
exports("HudToggle", ToggleHud)

-- Handlers
-- On script start
AddEventHandler("onResourceStart", function(resource)
    if GetCurrentResourceName() ~= resource then
        return
    end
    Wait(1000)
    HUD:Start()
end)

-- On player loaded
ESX.SecureNetEvent("esx:playerLoaded", function(xPlayer)
    while IsScreenFadedOut() do
        Wait(200)
    end

    HUD:Start(xPlayer)
end)

-- ForceLog or Logout
ESX.SecureNetEvent("esx:onPlayerLogout", function()
    Wait(1000)
    HUD:Toggle(false)
end)
