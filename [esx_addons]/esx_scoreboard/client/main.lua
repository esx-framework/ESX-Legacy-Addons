-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- @module client.main
--- Main client entry point for the scoreboard resource

local ScoreboardModule = xLib.require "@esx_scoreboard.client.module.main"

local RESOURCE_NAME <const> = GetCurrentResourceName()

--- Register NUI callback to close scoreboard from UI
xLib.nui.register("closeScoreboard", function()
  ScoreboardModule.CloseScoreboard()
  return {}
end)

--- Send theme update to NUI
local function SendThemeUpdate()
  local theme = xLib.colors.getESXTheme()
  theme.type = "updateTheme"

  xLib.nui.send(theme)
end

--- Register NUI callback for when the UI is fully mounted
xLib.nui.register("nuiReady", function()
  SendThemeUpdate()
  return {}
end)

--- Register NUI callback for paged player requests
xLib.nui.register("requestPlayersPage", function(data)
  ScoreboardModule.RequestPage(data)
  return { ok = true }
end)

RegisterCommand("scoreboard", function()
  ScoreboardModule.ToggleScoreboard()
end, false)

RegisterKeyMapping("scoreboard", "Open/Close Scoreboard", "keyboard", Config.OpenKey)

-- Disable controls only when open
CreateThread(function()
  while true do
    if ScoreboardModule.IsOpen() then
      Wait(0)
      DisableControlAction(0, 1, true)   -- look left/right
      DisableControlAction(0, 2, true)   -- look up/down
      DisableControlAction(0, 142, true) -- melee attack
      DisableControlAction(0, 18, true)  -- attack
      DisableControlAction(0, 322, true) -- ESC (already handled by disabled check)
      DisableControlAction(0, 106, true) -- mouse click in vehicle
      if IsDisabledControlJustReleased(0, 322) then
        ScoreboardModule.CloseScoreboard()
      end
    else
      Wait(250)
    end
  end
end)

--- Handle resource stop
AddEventHandler("onResourceStop", function(resourceName)
  if resourceName ~= RESOURCE_NAME then return end
  ScoreboardModule.CloseScoreboard()
end)
