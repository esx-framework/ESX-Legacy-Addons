ESX.TriggerServerCallback('esx-adminmenu:server:getInitData', function(data)
    if not data or data.error then
        if data.error and Config.Debug then
            print(data.error)
        end
        return
    end
    SendNUIMessage({
        action = 'initResource',
        data = data
    })
end)

