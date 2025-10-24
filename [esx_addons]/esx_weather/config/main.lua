Config = {}
Config.Weather = {}
Config.Time = {}

Config.debug = true

Config.AdminGroups = {
    admin = true,
    moderator = true,
}

Config.Zones = {
    ["Los Santos"] = vector2(-33.6997, -1102.0000),
    ["Sandy Shores"] = vector2(1728.2000, 3709.3000),
    ["Paleto Bay"] = vector2(-220.2753, 6408.9116),
}

Config.Weather.ValidTypes = {
    Shared.Enum.WeatherType.CLEAR,
    Shared.Enum.WeatherType.CLOUDS,
    Shared.Enum.WeatherType.EXTRASUNNY,
    Shared.Enum.WeatherType.FOGGY,
    Shared.Enum.WeatherType.OVERCAST,
    Shared.Enum.WeatherType.RAIN,
    Shared.Enum.WeatherType.SMOG,
    Shared.Enum.WeatherType.THUNDER,
}

Config.Weather.transitionTimeSeconds = 30
Config.Weather.cycleTimeSeconds = 60 * 30 -- 30 minutes

Config.Time.secondsPerGameMinute = 15
Config.Time.Zones = {
    ["Los Santos"] = 0,
    ["Sandy Shores"] = 5,
    ["Paleto Bay"] = 3,
}
