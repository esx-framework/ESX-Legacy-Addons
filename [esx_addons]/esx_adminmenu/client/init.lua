ESX.TriggerServerCallback('esx-adminmenu:server:getInitData', function(data)
    if not data or data.err then
        if data.err and Config.Debug then
            print(data.err)
        end
        return
    end
    SendNUIMessage({
        action = 'initResource',
        data = data
    })
end)
