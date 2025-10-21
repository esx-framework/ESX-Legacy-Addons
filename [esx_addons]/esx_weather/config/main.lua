---@class Config
---@field debug boolean
---@field Zones table<string, vector2>
---@field ValidWeatherTypes WeatherType[]
---@field weatherTransitionTimeSeconds integer
---@field weatherCycleTimeSeconds integer
---@field AdminGroups table<string, boolean>
Config = {}

Config.debug = true

Config.Zones = {
    ["Los Santos"] = vector2(-33.6997, -1102.0000),
    ["Sandy Shores"] = vector2(1728.2000, 3709.3000),
    ["Paleto Bay"] = vector2(-220.2753, 6408.9116),
}

Config.ValidWeatherTypes = {
    Shared.Enum.WeatherType.CLEAR,
    Shared.Enum.WeatherType.CLOUDS,
    Shared.Enum.WeatherType.EXTRASUNNY,
    Shared.Enum.WeatherType.FOGGY,
    Shared.Enum.WeatherType.OVERCAST,
    Shared.Enum.WeatherType.RAIN,
    Shared.Enum.WeatherType.SMOG,
    Shared.Enum.WeatherType.THUNDER,
}

Config.weatherTransitionTimeSeconds = 30
Config.weatherCycleTimeSeconds = 60 * 30 -- 30 minutes

Config.AdminGroups = {
    admin = true,
    moderator = true,
}
