-- SPDX-License-Identifier: GPL-3.0-only

Config = {}

Config.Locale = GetConvar("esx:locale", ESX.GetConfig().Locale or "en")

-- Server branding. Interface copy is translated in locales/.
Config.Brand = {
    kicker = "FIVEM ROLEPLAY",
    title = "ESX LEGACY",
    tagline = "ROLEPLAY BEYOND LIMITS",
    city = "Los Santos",
    established = "2015",
    communityLine = "BUILT BY A COMMUNITY THAT CARES"
}

-- External links. Leave a value empty to disable that destination.
Config.Links = {
    discord = "https://discord.gg/esx-framework",
    rules = "https://esx-framework.org/",
    store = ""
}

-- Optional announcements shown by the News button. Newest entries first.
-- Each entry accepts title, body and date strings; dates are displayed as written.
-- Example: { title = "Community meeting", body = "Details on Discord.", date = "27 SEP 2026" }
Config.News = {}

-- The online players chip opens this command when esx_scoreboard is running.
Config.PeopleCommand = "scoreboard"

-- Pause controls commonly used by GTA/FiveM.
Config.Controls = {
    pause = 200, -- INPUT_FRONTEND_PAUSE_ALTERNATE (ESC)
    pauseAlt = 199 -- INPUT_FRONTEND_PAUSE (P)
}

Config.ScreenBlurMs = 180
Config.Debug = false
