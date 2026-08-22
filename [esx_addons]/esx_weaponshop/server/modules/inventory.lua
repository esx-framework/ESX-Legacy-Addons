local ox_inventory = Config.OxInventory and exports.ox_inventory

---Checks if player can receive the weapon
---@param source number Player source
---@param xPlayer table ESX player object
---@param weaponName string
---@return boolean
function CanReceiveWeapon(source, xPlayer, weaponName)
	if ox_inventory then
		if not ox_inventory:CanCarryItem(source, weaponName, 1) then
			xPlayer.showNotification(TranslateCap('cannot_carry'))
			return false
		end

		return true
	end

	if xPlayer.hasWeapon(weaponName) then
		xPlayer.showNotification(TranslateCap('already_owned'))
		return false
	end

	return true
end

---Gives weapon item to player depending on inventory backend
---@param source number Player source
---@param xPlayer table ESX player object
---@param weaponName string
---@return boolean
function AddWeapon(source, xPlayer, weaponName)
	if ox_inventory then
		return ox_inventory:AddItem(source, weaponName, 1)
	end

	xPlayer.addWeapon(weaponName, 42)
	return true
end
