-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Config = {}
Config.Debug = false

-- Shared ESX language: setr esx:locale "es" (Spanish) or "en" (English).
Config.Locale = GetConvar('esx:locale', 'en')

Config.DeathAnim = {
    enabled = true,
    dict = 'misslamar1dead_body',
    name = 'dead_idle',
    fadeIn = 10.0,
    fadeOut = 10.0,
    flags = 1 | 2 | 8,
    playbackRate = 1.0
}

Config.zoom = {
    min = 1,
    max = 6,
    step = 0.5
}

---@class MedalClipOptions
---@field duration integer
---@field captureDelayMs integer
---@field alertType 'Default'|'Disabled'|'SoundOnly'|'OverlayOnly'

---@class MedalConfig
---@field enabled boolean
---@field publicKey string
---@field eventName string
---@field clipOptions MedalClipOptions

---@type MedalConfig
Config.Medal = {
    enabled = true,
    publicKey = 'pub_82qkpMKV77AkpqLSgWsxLlDyfzpPI7Vw',
    eventName = 'Death',
    clipOptions = {
        duration = 30,
        captureDelayMs = 0,
        alertType = 'Default'
    }
}

Config.EarlyRespawnTimer          = 60000 * 1  -- time til respawn is available
Config.BleedoutTimer              = 60000 * 10 -- time til the player bleeds out

Config.RemoveWeaponsAfterRPDeath  = true
Config.RemoveCashAfterRPDeath     = true
Config.RemoveItemsAfterRPDeath    = true

-- Let the player pay for respawning early, only if he can afford it.
Config.EarlyRespawnFine           = false
Config.EarlyRespawnFineAmount     = 5000

Config.OxInventory                = ESX.GetConfig().OxInventory

Config.RespawnPoints = {
    { coords = vector3(341.0, -1397.3, 32.5), heading = 48.5 },    -- Central Los Santos
    { coords = vector3(1836.03, 3670.99, 34.28), heading = 296.06 } -- Sandy Shores
}

-- Global death UI. Brand colors match esx_identity.
Config.Brand = { name = 'ESX', subtitle = 'ROLEPLAY', color = '#fb9b04', bright = '#ffb435' }
Config.HoldDuration = 1500          -- milliseconds; independent of frame rate
Config.DistressCooldown = 60000

-- Show the death reason on the death screen below the action buttons.
-- Defaults to showing "(killed by a player)"; if ShowKillerName is true the killer's name is shown instead.
-- This only applies to player inflicted deaths.
Config.ShowDeathReason = true
Config.ShowKillerName = false
Config.CameraEnabled = false
Config.AutoMigrate = true           -- adds missing users.is_dead / users.death_time columns