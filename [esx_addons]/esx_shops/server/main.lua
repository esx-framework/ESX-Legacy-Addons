---Handles purchase requests from clients
ESX.RegisterServerCallback('esx_shops:purchaseItems', function(source, cb, purchaseData, zone)
	ProcessPurchase(source, purchaseData, zone, cb)
end)
