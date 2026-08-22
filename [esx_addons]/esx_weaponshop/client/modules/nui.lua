local currentShop = nil
local uiOpen = false

---Opens weaponshop NUI
---@param zone string Shop zone name
---@param mode string NUI mode (`shop` or `license`)
local function OpenNui(zone, mode)
	local items = BuildShopItems(zone)

	currentShop = zone
	uiOpen = true

	SetNuiFocus(true, true)
	SendNUIMessage({
		type = 'openShop',
		shopData = {
			shopName = TranslateCap('shop_menu_title'),
			items = items,
			categories = BuildCategories(items),
			locales = GetShopLocales(),
			legal = Config.Zones[zone].Legal,
			mode = mode,
			licensePrice = Config.LicensePrice
		}
	})
end

---Opens the weapon shop
---@param zone string Shop zone name
function OpenShop(zone)
	OpenNui(zone, 'shop')
end

---Opens the weapon license purchase view
---@param zone string Shop zone name
function OpenBuyLicenseMenu(zone)
	OpenNui(zone, 'license')
end

function CloseShop()
	SetNuiFocus(false, false)
	SendNUIMessage({ type = 'closeShop' })
	currentShop = nil
	uiOpen = false
end

---Gets current shop name
---@return string|nil
function GetCurrentShop()
	return currentShop
end

---Checks if UI is open
---@return boolean
function IsUIOpen()
	return uiOpen
end

-- NUI Ready Callback
RegisterNUICallback('ready', function(data, cb)
	cb({ theme = GetESXThemeColors() })
end)

-- Purchase callback
RegisterNUICallback('buyWeapon', function(data, cb)
	if type(data) ~= 'table' or type(data.weaponName) ~= 'string' or not currentShop then
		cb({ ok = false })
		return
	end

	ESX.TriggerServerCallback('esx_weaponshop:buyWeapon', function(bought)
		if bought then
			local price = GetZoneWeaponPrice(currentShop, data.weaponName)
			DisplayBoughtScaleform(data.weaponName, price)
		else
			PlaySoundFrontend(-1, 'ERROR', 'HUD_AMMO_SHOP_SOUNDSET', false)
		end

		cb({ ok = bought and true or false })
	end, data.weaponName, currentShop)
end)

-- License callback
RegisterNUICallback('buyLicense', function(_, cb)
	ESX.TriggerServerCallback('esx_weaponshop:buyLicense', function(bought)
		cb({ ok = bought and true or false })

		if bought and currentShop then
			OpenShop(currentShop)
		end
	end)
end)

-- Close UI callback
RegisterNUICallback('closeUI', function(data, cb)
	CloseShop()
	cb('ok')
end)
