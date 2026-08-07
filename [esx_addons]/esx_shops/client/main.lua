CreateThread(function()
	while true do
		UpdateNearbyShops()
		Wait(500)
	end
end)

CreateThread(function()
	while true do
		local sleep, isInMarker, currentZone = DrawMarkersAndCheckProximity()

		if isInMarker then
			sleep = 0

			if not GetMarkerState() then
				SetEnteredMarker(true)
				OnMarkerEnter(currentZone)
				local msg = GetCurrentActionMsg()
				if msg then
					ESX.TextUI(msg)
				end
			end
		else
			if GetMarkerState() then
				SetEnteredMarker(false)
				ESX.HideUI()
				OnMarkerExit(GetLastZone())
			end
		end

		Wait(sleep)
	end
end)