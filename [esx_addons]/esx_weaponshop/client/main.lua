CreateThread(function()
	while true do
		local sleep = DrawMarkersAndCheckProximity()
		Wait(sleep)
	end
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		if IsUIOpen() then
			CloseShop()
		end
	end
end)
