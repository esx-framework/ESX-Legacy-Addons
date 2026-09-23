-- SPDX-License-Identifier: GPL-3.0-only

Config = {}

Config.Locale = GetConvar("esx:locale", "en")

-- Visual copy used by the supplied concept. All text is configurable.
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

-- If esx_scoreboard is running this command opens it from PEOPLE.
Config.PeopleCommand = "scoreboard"

-- Pause controls commonly used by GTA/FiveM.
Config.Controls = {
    pause = 200, -- INPUT_FRONTEND_PAUSE_ALTERNATE (ESC)
    pauseAlt = 199 -- INPUT_FRONTEND_PAUSE (P)
}

Config.ScreenBlurMs = 180
Config.Debug = false
