-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Config = {}

Config.StatusMax = 1000000
Config.TickTime = 1000
Config.UpdateInterval = 30000
Config.SyncSlices = 30 -- Spread each server sync round across 30 batches.
Config.MinUpdateInterval = 10000 -- Minimum accepted custom-status update interval per client.
Config.LoadRetryInitial = 5000
Config.LoadRetryMax = 60000
Config.Display = false -- Enable the esx_status bars (disable if you are using another HUD)

-- Server-authoritative needs, in units per Config.TickTime.
-- Custom statuses keep the legacy integration unless explicitly listed here.
Config.AuthoritativeStatuses = {
    hunger = { default = 1000000, decay = 100 },
    thirst = { default = 1000000, decay = 75 },
}
