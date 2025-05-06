local function handleItemUsage(itemName, itemConfig, source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if itemConfig.remove then
        xPlayer.removeInventoryItem(itemName, 1)
    end

    local statusType, notificationMessage
    if itemConfig.type == "food" then
        statusType = "hunger"
        notificationMessage = TranslateCap('used_food', ESX.GetItemLabel(itemName))
    elseif itemConfig.type == "drink" then
        statusType = "thirst"
        notificationMessage = TranslateCap('used_drink', ESX.GetItemLabel(itemName))
    else
        print(string.format('^1[ERROR]^0 Item "%s" has an invalid type defined.', itemName))
        return
    end

    TriggerClientEvent("esx_status:add", source, statusType, itemConfig.status)
    TriggerClientEvent('esx_basicneeds:onUse', source, itemConfig.type, itemConfig.prop, itemConfig.anim, itemConfig.pos, itemConfig.rot)
    xPlayer.showNotification(notificationMessage)
end

CreateThread(function()
    for itemName, itemConfig in pairs(Config.Items) do
        ESX.RegisterUsableItem(itemName, function(source)
            handleItemUsage(itemName, itemConfig, source)
        end)
    end
end)

ESX.RegisterCommand('heal', 'admin', function(xPlayer, args, showError)
    if not args.playerId then
        return showError("Player ID is required")
    end
    args.playerId.triggerEvent('esx_basicneeds:healPlayer')
    args.playerId.showNotification(TranslateCap('got_healed'))
end, true, {
    help = 'Heal a player, or yourself - restores thirst, hunger, and health.',
    validate = true,
    arguments = {
        {name = 'playerId', help = 'The player ID', type = 'player'}
    }
})

AddEventHandler('txAdmin:events:healedPlayer', function(eventData)
    if GetInvokingResource() ~= "monitor" or type(eventData) ~= "table" or type(eventData.id) ~= "number" then
        return
    end
    TriggerClientEvent('esx_basicneeds:healPlayer', eventData.id)
end)
