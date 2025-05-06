if Config.Cruise.Enable then
    ESX.RegisterInput('esx_cruisecontrol:Enable', Translate('cruiseControl'), "keyboard", Config.Cruise.Key, function()
        if not Utils.vehicle then return end
        
        if CC.cruiseActive then
            CC:Reset()
            return
        end
        CC:Enable()
    end)

    ESX.RegisterInput('esx_cruisecontrol:IncreaseSpeed', Translate('increaseSpeed'), "keyboard", "ADD", function()
        if not Utils.vehicle then return end
        CC:ChangeSpeed(true)
    end)

    ESX.RegisterInput('esx_cruisecontrol:DecreaseSpeed', Translate('decreaseSpeed'), "keyboard", "SUBTRACT", function()
        if not Utils.vehicle then return end
        CC:ChangeSpeed(false)
    end)
end

if Config.Seatbelt.Enable then
    ESX.RegisterInput('esx_cruisecontrol:ToggleSeatbelt', Translate('toggleSeatbelt'), "keyboard", Config.Seatbelt.Key, function()
        if not Utils.vehicle then return end
        SB.seatbelt = not SB.seatbelt
        SB:SetState(SB.seatbelt)
        ESX.ShowNotification(Translate(SB.seatbelt and 'seatbeltOn' or 'seatbeltOff', 5000, 'info'))
    end)
end

