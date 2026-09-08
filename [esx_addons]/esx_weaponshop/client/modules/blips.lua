local shopBlips = {}

---Creates blips for all weaponshop locations
function CreateShopBlips()
	if not Config.Zones then
		return
	end

	for _, zoneData in pairs(Config.Zones) do
		local blipSettings = zoneData.Blip
		local locations = zoneData.Locations
		if blipSettings and blipSettings.Enabled and type(locations) == 'table' then
			local posCount = #locations

			for i = 1, posCount do
				local location = locations[i]
				local blip = xLib.blips.create({
					coords = location,
					sprite = blipSettings.Sprite,
					display = blipSettings.Display,
					scale = blipSettings.Scale,
					color = blipSettings.Color,
					shortRange = blipSettings.ShortRange,
					label = TranslateCap('map_blip')
				})

				shopBlips[#shopBlips + 1] = blip
			end
		end
	end
end

---Removes all weaponshop blips
function RemoveShopBlips()
	for i = 1, #shopBlips do
		xLib.blips.remove(shopBlips[i])
	end
	shopBlips = {}
end

-- Initialize blips after resource start (ensures Config is fully loaded)
AddEventHandler('onClientResourceStart', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		CreateShopBlips()
	end
end)
