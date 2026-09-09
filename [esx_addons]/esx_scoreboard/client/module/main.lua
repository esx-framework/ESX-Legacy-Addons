-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- @module client.module.main
--- Client-side scoreboard module

local ScoreboardClass = xLib.require "@esx_scoreboard.client.module.class"

local ScoreboardModule = {}
local currentScoreboard = nil

--- Check if scoreboard is currently open.
--- @return boolean
function ScoreboardModule.IsOpen()
  return currentScoreboard ~= nil and currentScoreboard:IsOpen()
end

--- Open the scoreboard.
function ScoreboardModule.OpenScoreboard()
  if ScoreboardModule.IsOpen() then return end

  currentScoreboard = ScoreboardClass:new()
  currentScoreboard:Open()

  xLib.nui.open({ type = "show" })
  TriggerServerEvent("esx_scoreboard:server:open")
end

--- Close the scoreboard.
function ScoreboardModule.CloseScoreboard()
  if not ScoreboardModule.IsOpen() then return end

  TriggerServerEvent("esx_scoreboard:server:close")
  xLib.nui.close({ type = "hide" })

  currentScoreboard:Close()
  currentScoreboard = nil
end

--- Toggle scoreboard visibility.
function ScoreboardModule.ToggleScoreboard()
  if ScoreboardModule.IsOpen() then
    ScoreboardModule.CloseScoreboard()
  else
    ScoreboardModule.OpenScoreboard()
  end
end

--- Request one player page from the server.
--- @param data table|nil
function ScoreboardModule.RequestPage(data)
  if not ScoreboardModule.IsOpen() then return end
  TriggerServerEvent("esx_scoreboard:server:requestPage", type(data) == "table" and data or {})
end

--- Refresh initial scoreboard data from server.
function ScoreboardModule.RefreshData()
  if not ScoreboardModule.IsOpen() then return end
  TriggerServerEvent("esx_scoreboard:server:requestData")
end

RegisterNetEvent("esx_scoreboard:client:receiveSummary", function(summary)
  xLib.nui.send({
    type = "updateSummary",
    summary = summary
  })
end)

RegisterNetEvent("esx_scoreboard:client:receivePage", function(page)
  xLib.nui.send({
    type = "updatePage",
    page = page
  })
end)

RegisterNetEvent("esx_scoreboard:client:receiveActivities", function(activities)
  xLib.nui.send({
    type = "updateActivities",
    activities = activities
  })
end)

RegisterNetEvent("esx_scoreboard:client:receiveData", function(players, jobs, activities, info)
  xLib.nui.send({
    type = "updateAll",
    players = players,
    jobs = jobs,
    activities = activities,
    info = info
  })
end)

return ScoreboardModule
