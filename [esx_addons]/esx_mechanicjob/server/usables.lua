ESX.RegisterUsableItem('blowpipe', function(source)
	local source = source
	local xPlayer  = ESX.Player(source)

	xPlayer.removeInventoryItem('blowpipe', 1)

	TriggerClientEvent('esx_mechanicjob:onHijack', source)
	TriggerClientEvent('esx:showNotification', source, TranslateCap('you_used_blowtorch'))
end)

ESX.RegisterUsableItem('fixkit', function(source)
	local source = source
	local xPlayer  = ESX.Player(source)

	xPlayer.removeInventoryItem('fixkit', 1)

	TriggerClientEvent('esx_mechanicjob:onFixkit', source)
	TriggerClientEvent('esx:showNotification', source, TranslateCap('you_used_repair_kit'))
end)

ESX.RegisterUsableItem('carokit', function(source)
	local source = source
	local xPlayer  = ESX.Player(source)

	xPlayer.removeInventoryItem('carokit', 1)

	TriggerClientEvent('esx_mechanicjob:onCarokit', source)
	TriggerClientEvent('esx:showNotification', source, TranslateCap('you_used_body_kit'))
end)


