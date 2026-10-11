-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- @module server.main
--- Main server entry point for the scoreboard resource

local ScoreboardModule = xLib.require "@esx_scoreboard.server.module.main"

local RESOURCE_NAME <const> = GetCurrentResourceName()

AddEventHandler("onResourceStart", function(resourceName)
  if resourceName ~= RESOURCE_NAME then return end
  print("[^2esx_scoreboard^7] Scoreboard started successfully")
end)
