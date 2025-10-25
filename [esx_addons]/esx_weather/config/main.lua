---@class WeatherConfig
---@field ValidTypes WeatherType[]
---@field transitionTimeSeconds integer
---@field cycleTimeSeconds integer

---@class TimeConfig
---@field secondsPerGameMinute integer
---@field Zones table<Zone, integer>

---@class Config
---@field debug boolean
---@field AdminGroups table<string, boolean>
---@field Zones table<Zone, vector2>
---@field Weather WeatherConfig
---@field Time TimeConfig

Config = {
    debug       = true,
    AdminGroups = {
        admin = true,
        moderator = true,
    },
    Zones       = {
        [Shared.Enum.Zone.LOS_SANTOS] = vector2(-33.6997, -1102.0000),
        [Shared.Enum.Zone.SANDY_SHORES] = vector2(1728.2000, 3709.3000),
        [Shared.Enum.Zone.PALETO_BAY] = vector2(-220.2753, 6408.9116),
    },

    Weather     = {
        ValidTypes = {
            Shared.Enum.WeatherType.CLEAR,
            Shared.Enum.WeatherType.CLOUDS,
            Shared.Enum.WeatherType.EXTRASUNNY,
            Shared.Enum.WeatherType.FOGGY,
            Shared.Enum.WeatherType.OVERCAST,
            Shared.Enum.WeatherType.RAIN,
            Shared.Enum.WeatherType.SMOG,
            Shared.Enum.WeatherType.THUNDER,
        },
        transitionTimeSeconds = 30,
        cycleTimeSeconds = 60 * 30 -- 30 minutes
    },
    Time        = {
        secondsPerGameMinute = 15,
        Zones = {
            [Shared.Enum.Zone.LOS_SANTOS] = 0,
            [Shared.Enum.Zone.SANDY_SHORES] = 1,
            [Shared.Enum.Zone.PALETO_BAY] = 2,
        }
    }
} --[[@as Config]]
