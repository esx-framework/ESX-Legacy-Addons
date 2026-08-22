local WEAPON_CATEGORIES = {
	[`GROUP_MELEE`] = 'melee',
	[`GROUP_PISTOL`] = 'handguns',
	[`GROUP_STUNGUN`] = 'handguns',
	[`GROUP_SMG`] = 'smgs',
	[`GROUP_RIFLE`] = 'rifles',
	[`GROUP_MG`] = 'rifles',
	[`GROUP_SHOTGUN`] = 'shotguns',
	[`GROUP_SNIPER`] = 'rifles',
	[`GROUP_HEAVY`] = 'heavy',
	[`GROUP_THROWN`] = 'throwables',
	[`GROUP_FIREEXTINGUISHER`] = 'misc',
	[`GROUP_PETROLCAN`] = 'misc',
}

local CATEGORY_ORDER = {
	'melee',
	'handguns',
	'smgs',
	'shotguns',
	'rifles',
	'heavy',
	'throwables',
	'misc'
}

---Gets display label for a weapon item
---@param weaponName string
---@return string
function GetItemLabel(weaponName)
	local label = ESX.GetWeaponLabel(weaponName)

	if Config.OxInventory then
		local oxItem = exports.ox_inventory:Items(weaponName)
		if oxItem then
			label = oxItem.label
		end
	end

	return label
end

---Gets image URL for a weapon item
---@param weaponName string
---@return string
function GetWeaponImage(weaponName)
	if Config.OxInventory then
		local oxItem = exports.ox_inventory:Items(weaponName)
		if oxItem and oxItem.client and oxItem.client.image then
			return oxItem.client.image
		end

		return ('nui://ox_inventory/web/images/%s.png'):format(weaponName)
	end

	return ('https://docs-backend.fivem.net/weapons/%s.png'):format(weaponName)
end

---Maps weapon to UI category
---@param weaponName string
---@return string
function GetWeaponCategory(weaponName)
	local group = GetWeapontypeGroup(joaat(weaponName))
	return WEAPON_CATEGORIES[group] or 'misc'
end

---Gets localized labels used by the weaponshop NUI
---@return table
function GetShopLocales()
	return {
		searchPlaceholder = TranslateCap('search_placeholder'),
		buy = TranslateCap('buy'),
		noWeaponSelected = TranslateCap('no_weapon_selected'),
		noImageAvailable = TranslateCap('no_image_available'),
		licenseTitle = TranslateCap('license_shop_title'),
		licenseDescription = TranslateCap('license_description'),
		buyLicense = TranslateCap('buy_license'),
		cancel = TranslateCap('menu_cancel')
	}
end

---Builds NUI item list for a zone
---@param zone string
---@return table
function BuildShopItems(zone)
	local zoneItems = Config.Zones[zone].Items
	local items = {}

	for i = 1, #zoneItems do
		local item = zoneItems[i]
		items[i] = {
			name = item.name,
			label = GetItemLabel(item.name),
			price = item.price,
			category = GetWeaponCategory(item.name),
			image = GetWeaponImage(item.name)
		}
	end

	return items
end

---Builds category filter list from zone items
---@param items table
---@return table
function BuildCategories(items)
	local found = {}

	for i = 1, #items do
		found[items[i].category] = true
	end

	local categories = {
		{ id = 'all', label = TranslateCap('category_all') }
	}

	for i = 1, #CATEGORY_ORDER do
		local id = CATEGORY_ORDER[i]
		if found[id] then
			categories[#categories + 1] = {
				id = id,
				label = TranslateCap('category_' .. id)
			}
		end
	end

	return categories
end

---Gets weapon price from the currently selected zone
---@param zone string
---@param weaponName string
---@return number
function GetZoneWeaponPrice(zone, weaponName)
	local zoneItems = Config.Zones[zone].Items

	for i = 1, #zoneItems do
		if zoneItems[i].name == weaponName then
			return zoneItems[i].price
		end
	end

	return 0
end

---Displays purchase scaleform and purchase sound
---@param weaponName string
---@param price number
function DisplayBoughtScaleform(weaponName, price)
	local scaleform = ESX.Scaleform.Utils.RequestScaleformMovie('MP_BIG_MESSAGE_FREEMODE')
	local sec = 4

	BeginScaleformMovieMethod(scaleform, 'SHOW_WEAPON_PURCHASED')

	local label = GetItemLabel(weaponName)

	ScaleformMovieMethodAddParamTextureNameString(TranslateCap('weapon_bought', ESX.Math.GroupDigits(price)))
	ScaleformMovieMethodAddParamTextureNameString(label)
	ScaleformMovieMethodAddParamInt(joaat(weaponName))
	ScaleformMovieMethodAddParamTextureNameString('')
	ScaleformMovieMethodAddParamInt(100)
	EndScaleformMovieMethod()

	PlaySoundFrontend(-1, 'WEAPON_PURCHASE', 'HUD_AMMO_SHOP_SOUNDSET', false)

	CreateThread(function()
		while sec > 0 do
			Wait(0)
			sec = sec - 0.01

			DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255, 0)
		end
	end)
end
