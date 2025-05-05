Config = {
    Locale = GetConvar('esx:locale', 'en'),
    HudResource = 'esx_hud',
    Cruise = {
        Enable = true,
        Key = "CAPITAL",
        Export = function (state)
            exports[Config.HudResource]:CruiseControlState(state)
        end,
    },
    Seatbelt = {
        Enable = true,
        Key = "B",
        EjectCheckSpeed = 45, -- MPH
        RagdollTime = 1, -- MS
        Export = function (state)
            exports[Config.HudResource]:SeatbeltState(state)
        end
    }
}