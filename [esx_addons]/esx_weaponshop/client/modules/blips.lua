local shopBlips = {}

---Creates blips for all weaponshop locations
function CreateShopBlips()
	if not Config.Zones then
		return
	end

	for _, zoneData in pairs(Config.Zones) do
		local blipSettings = zoneData.Blip
		if blipSettings.Enabled then
			local posCount = #zoneData.Locations

			for i = 1, posCount do
				local location = zoneData.Locations[i]
				local blip = AddBlipForCoord(location.x, location.y, location.z)

				SetBlipSprite(blip, blipSettings.Sprite)
				SetBlipDisplay(blip, blipSettings.Display)
				SetBlipScale(blip, blipSettings.Scale)
				SetBlipColour(blip, blipSettings.Colour)
				SetBlipAsShortRange(blip, blipSettings.ShortRange)

				BeginTextCommandSetBlipName('STRING')
				AddTextComponentSubstringPlayerName(TranslateCap('map_blip'))
				EndTextCommandSetBlipName(blip)

				shopBlips[#shopBlips + 1] = blip
			end
		end
	end
end

---Removes all weaponshop blips
function RemoveShopBlips()
	for i = 1, #shopBlips do
		RemoveBlip(shopBlips[i])
	end
	shopBlips = {}
end

-- Initialize blips after resource start (ensures Config is fully loaded)
AddEventHandler('onClientResourceStart', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		CreateShopBlips()
	end
end)
