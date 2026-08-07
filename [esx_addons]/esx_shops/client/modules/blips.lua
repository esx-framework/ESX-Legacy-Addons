local shopBlips = {}

---Creates blips for all shop locations
function CreateShopBlips()
	if not Config.Zones then
		DebugPrint('[^1ERROR^7] Config.Zones is nil - cannot create blips')
		return
	end

	for zoneName, zoneData in pairs(Config.Zones) do
		if zoneData.ShowBlip then
			local posCount = #zoneData.Pos

			for i = 1, posCount do
				local pos = zoneData.Pos[i]
				local blip = AddBlipForCoord(pos.x, pos.y, pos.z)

				SetBlipSprite(blip, zoneData.Type)
				SetBlipScale(blip, zoneData.Size)
				SetBlipColour(blip, zoneData.Color)
				SetBlipAsShortRange(blip, true)

				BeginTextCommandSetBlipName('STRING')
				AddTextComponentSubstringPlayerName(zoneName)
				EndTextCommandSetBlipName(blip)

				shopBlips[#shopBlips + 1] = blip
			end
		end
	end

	DebugPrint(('[^2INFO^7] Created ^5%s^7 shop blips'):format(#shopBlips))
end

---Removes all shop blips 
function RemoveShopBlips()
	for i = 1, #shopBlips do
		RemoveBlip(shopBlips[i])
	end
	shopBlips = {}
end

-- Initialize blips after resource start 
AddEventHandler('onClientResourceStart', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		CreateShopBlips()
	end
end)
