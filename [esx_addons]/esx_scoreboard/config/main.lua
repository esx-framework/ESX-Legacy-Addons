-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- @module config.main
--- Configuration file for the scoreboard resource

Config = {}

--- Enable debug logging (default: false)
Config.Debug = false

--- Key to open the scoreboard (default: Z )
Config.OpenKey = "Z"

--- Interval (ms) to broadcast summary counters to clients with scoreboard open
Config.SummaryInterval = 10000

--- Interval (ms) to refresh visible player pages for clients with scoreboard open
Config.PageRefreshInterval = 15000

--- Number of open scoreboards refreshed before yielding the server thread
Config.PageRefreshBatchSize = 25

--- Delay (ms) between open-scoreboard refresh batches
Config.PageRefreshBatchDelay = 50

--- Interval (ms) to refresh player ping values server-side
Config.PingRefreshInterval = 30000

--- Interval (ms) to reconcile the full ESX player list as a safety net
Config.FullReconcileInterval = 60000

--- Minimum interval (ms) between open requests from the same player
Config.OpenCooldown = 2000

--- Minimum interval (ms) between page/search/sort requests from the same player
Config.PageRequestCooldown = 1500

--- Debounce (ms) for activity updates sent to clients
Config.ActivityDebounce = 1000

--- Player rows sent per page by default
Config.DefaultPageSize = 50

--- Hard cap for rows sent in a single page
Config.MaxPageSize = 100

--- Maximum cached page payloads kept between player/ping changes
Config.MaxPageCacheEntries = 256

--- Maximum cached filtered/sorted player queries kept between player/ping changes
Config.MaxPlayerQueryCacheEntries = 64

--- Maximum search text length accepted from the UI
Config.MaxSearchLength = 48

--- Maximum active activities kept in memory
Config.MaxActivities = 64

--- Maximum player entries stored per activity
Config.MaxActivityPlayers = 16

--- Legacy alias kept for external configs that still read UpdateInterval
Config.UpdateInterval = Config.SummaryInterval

--- Server display name shown in the scoreboard header
Config.ServerName = "ESX Server"

--- Max players displayed in the header (set to nil to use sv_maxclients convar)
Config.MaxPlayers = nil

--- HTTPS logo URL shown in the scoreboard header (set to "" to show ESX placeholder)
Config.LogoUrl = ""

--- Jobs to display in the scoreboard with their display labels
Config.Jobs = {
  police = { label = "Police", color = "#3B82F6" },
  ambulance = { label = "EMS", color = "#EF4444" },
  mechanic = { label = "Mechanic", color = "#F59E0B" },
  taxi = { label = "Taxi", color = "#FBBF24" },
  realtor = { label = "Realtor", color = "#10B981" },
  cardealer = { label = "Car Dealer", color = "#8B5CF6" },
  banker = { label = "Banker", color = "#06B6D4" }
}

--- Activity types that can be shown in the scoreboard
Config.ActivityTypes = {
  robbery = { label = "Robbery", icon = "💰" },
  heist = { label = "Heist", icon = "🏦" },
  drug = { label = "Drug Sale", icon = "💊" },
  race = { label = "Street Race", icon = "🏎️" },
  hostage = { label = "Hostage", icon = "🚫" },
  shootout = { label = "Shootout", icon = "🔫" }
}
