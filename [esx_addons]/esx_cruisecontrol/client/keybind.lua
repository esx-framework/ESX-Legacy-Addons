-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

if Config.Cruise.Enable then
    xLib.addKeybind({
    name = 'esx_cruisecontrol:Enable',
    description = Translate('cruiseControl'),
    defaultMapper = "keyboard",
    defaultKey = Config.Cruise.Key,
    onPressed = function()
        if not Utils.vehicle then return end
        
        if CC.cruiseActive then
            CC:Reset()
            return
        end
        CC:Enable()
    end,
})

    xLib.addKeybind({
    name = 'esx_cruisecontrol:IncreaseSpeed',
    description = Translate('increaseSpeed'),
    defaultMapper = "keyboard",
    defaultKey = "ADD",
    onPressed = function()
        if not Utils.vehicle then return end
        CC:ChangeSpeed(true)
    end,
})

    xLib.addKeybind({
    name = 'esx_cruisecontrol:DecreaseSpeed',
    description = Translate('decreaseSpeed'),
    defaultMapper = "keyboard",
    defaultKey = "SUBTRACT",
    onPressed = function()
        if not Utils.vehicle then return end
        CC:ChangeSpeed(false)
    end,
})
end

if Config.Seatbelt.Enable then
    xLib.addKeybind({
    name = 'esx_cruisecontrol:ToggleSeatbelt',
    description = Translate('toggleSeatbelt'),
    defaultMapper = "keyboard",
    defaultKey = Config.Seatbelt.Key,
    onPressed = function()
        if not Utils.vehicle then return end
        SB.seatbelt = not SB.seatbelt
        SB:SetState(SB.seatbelt)
        ESX.ShowNotification(Translate(SB.seatbelt and 'seatbeltOn' or 'seatbeltOff', 5000, 'info'))
    end,
})
end

