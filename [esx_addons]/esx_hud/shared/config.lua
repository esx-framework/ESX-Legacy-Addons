Config = {
    Locale = ESX.GetConfig().Locale or "en", -- If you want to change UI language texts you can do it here: web/src/assets/translate.json !!IMPORTANT that this can only be modified with the unbuilt version.
    Colors = {
        Info = {
            ["money-text-color"] = "#0aad20",
            ["bank-text-color"] = "#666666",
            ["job-text-color"] = "#fb9b04",
        },
        Status = {
            healthBar = "red",
            armorBar = "blue",
            drinkBar = "lightblue",
            foodBar = "#fb9b04",
        },
        Speedo = {
            ["segment-color"] = "#eee",
            ["segment-progress-color"] = "#c97d03",
            ["number-color"] = "#eee",
            ["danger-color"] = "red",
            ["danger-progress-color"] = "pink",
            ["number-danger-color"] = "red",
            ["speedo-progress-color"] = "#fb9b04",
            ["damage-progress-color"] = "#0aad20",
            ["speedo-all-texts"] = "#fb9b04",
            ["engine-icon-color"] = "#fb9b04",
            ["tempomat-icon-color"] = "#fb9b04",
            ["light-icon-color"] = "#fb9b04",
            ["door-icon-color"] = "#fb9b04",
            ["fuel-icon-color"] = "#fb9b04",
            ["fuel-level-color"] = "white",
            ["mileage-level-color"] = "#eee",
            ["unit-color"] = "white",
            ["current-speed-color"] = "#fb9b04",
            ["left-right-index-color"] = "#00B065",
            ["damage-icon-color"] = "#0aad20",
            ["speedo-background-color"] = "rgba(15,15,15,0.7)",
            ["speedo-outer-circle-color"] = "rgba(30,30,30,0.7)",
            ["speedo-nooble-color"] = "#fb9b04",
            ["speedo-nooble-container"] = "rgb(30, 30, 30)",
            ["speedo-seatbelt-icon-color"] = "#D22B2B",
        },
    },
    Disable = {
        Status = false,
        Vehicle = false,
        Weapon = false,
        Position = false,
        Voice = false,
        Money = false,
        Info = false,
        IndicatorSound = true, --vehicle index sound
        IndicatorSeatbeltSound = false, --seatbelt sound
        VehicleHandlers = false, -- Engine toggle, Indicator lights
        MinimapOnFoot = false,
        Needle = false,
        StatusPercent = false,
        CenterStatuses = false, -- true for above minimap, false for left side of the screen
    },
    Default = {
        ServerLogo = "https://esx.s3.fr-par.scw.cloud/blanc-800x800.png",
        Kmh = false,
        PassengerSpeedo = false, -- if this true , you can see speedometer if you don't driver
    },
}
