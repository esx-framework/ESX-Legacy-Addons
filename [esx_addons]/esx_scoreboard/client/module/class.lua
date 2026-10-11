-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- @module client.module.class
--- Class definitions for the scoreboard client module

local Enum = xLib.require "@esx_scoreboard.client.module.enum"

--- @class Scoreboard
--- @field state number Current scoreboard state
local Scoreboard = {}
Scoreboard.__index = Scoreboard

--- Create a new Scoreboard instance
--- @return Scoreboard
function Scoreboard:new()
  local newScoreboard = {
    state = Enum.ScoreboardState.CLOSED
  }
  setmetatable(newScoreboard, Scoreboard)
  return newScoreboard
end

--- Check if scoreboard is open
--- @return boolean
function Scoreboard:IsOpen()
  return self.state == Enum.ScoreboardState.OPEN
end

--- Open the scoreboard
function Scoreboard:Open()
  self.state = Enum.ScoreboardState.OPEN
end

--- Close the scoreboard
function Scoreboard:Close()
  self.state = Enum.ScoreboardState.CLOSED
end

return Scoreboard
