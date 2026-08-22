---Gets weapon price from a configured zone
---@param weaponName string
---@param zone string
---@return number
function GetPrice(weaponName, zone)
	local zoneConfig = Config.Zones[zone]

	if not zoneConfig or not zoneConfig.Items then
		return -1
	end

	for i = 1, #zoneConfig.Items do
		local weapon = zoneConfig.Items[i]

		if weapon.name == weaponName then
			return tonumber(weapon.price) or -1
		end
	end

	return -1
end

---Validates zone exists
---@param zone string Zone name
---@param source number Player source for logging
---@return boolean valid
function ValidateZone(zone, source)
	if not zone or not Config.Zones[zone] then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to buy weapon from Invalid zone - %s!'):format(
			source,
			zone
		))
		return false
	end

	return true
end
