---@class WeatherConfig
---@field ValidTypes WeatherType[]
---@field transitionTimeSeconds integer
---@field cycleTimeSeconds integer

---@class TimeConfig
---@field secondsPerGameMinute integer
---@field Zones table<string, integer>

---@class Config
---@field debug boolean
---@field AdminGroups table<string, boolean>
---@field Zones table<string, vector2>
---@field Weather WeatherConfig
---@field Time TimeConfig

Config = {
    debug       = true,
    AdminGroups = {
        admin = true,
        moderator = true,
    },
    Zones       = {
        ["Los Santos"] = vector2(-33.6997, -1102.0000),
        ["Sandy Shores"] = vector2(1728.2000, 3709.3000),
        ["Paleto Bay"] = vector2(-220.2753, 6408.9116),
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
            ["Los Santos"] = 0,
            ["Sandy Shores"] = 5,
            ["Paleto Bay"] = 3,
        }
    }
} --[[@as Config]]
