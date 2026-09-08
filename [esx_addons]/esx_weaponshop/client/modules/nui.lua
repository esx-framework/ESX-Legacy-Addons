local currentShop = nil
local uiOpen = false

local function NormalizeUiInteger(value)
	value = tonumber(value)

	if not value or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end

	return math.floor(value)
end

local function GetInitialWeaponAmmo()
	return math.max(NormalizeUiInteger(Config.InitialWeaponAmmo) or 42, 0)
end

local function SyncBoughtWeaponToPed(weaponName)
	if Config.OxInventory then
		return
	end

	if type(weaponName) ~= 'string' or weaponName == '' then
		return
	end

	if type(GiveWeaponToPed) ~= 'function' then
		return
	end

	local ped = PlayerPedId()
	if not ped or ped == 0 then
		return
	end

	local weaponHash = joaat(weaponName)
	local initialAmmo = GetInitialWeaponAmmo()

	if HasPedGotWeapon(ped, weaponHash, false) then
		local currentAmmo = NormalizeUiInteger(GetAmmoInPedWeapon(ped, weaponHash)) or 0

		if currentAmmo < initialAmmo and type(SetPedAmmo) == 'function' then
			SetPedAmmo(ped, weaponHash, initialAmmo)
		end

		return
	end

	GiveWeaponToPed(ped, weaponHash, initialAmmo, false, false)
end

local function BuildBoughtWeaponState(weaponName)
	if Config.OxInventory and type(BuildCurrentShopWeaponState) == 'function' then
		local state = BuildCurrentShopWeaponState(weaponName)
		local hadWeaponState = type(state) == 'table' and state.owned == true

		state = type(state) == 'table' and state or {}
		state.owned = true
		state.ammo = NormalizeUiInteger(state.ammo) or 0
		state.tintIndex = NormalizeUiInteger(state.tintIndex) or 0
		state.components = type(state.components) == 'table' and state.components or {}

		if not hadWeaponState and WeaponShopWeaponUsesAmmo(weaponName) then
			state.ammo = state.ammo + GetInitialWeaponAmmo()
		end

		return state
	end

	local ammo = WeaponShopWeaponUsesAmmo(weaponName) and GetInitialWeaponAmmo() or 0
	local ped = PlayerPedId()

	if ped and ped ~= 0 then
		local weaponHash = joaat(weaponName)

		if HasPedGotWeapon(ped, weaponHash, false) then
			ammo = math.max(NormalizeUiInteger(GetAmmoInPedWeapon(ped, weaponHash)) or 0, ammo)
		end
	end

	return {
		owned = true,
		ammo = ammo,
		tintIndex = 0,
		components = {}
	}
end

local function GetWeaponComponentData(weaponName, componentName)
	if type(weaponName) ~= 'string' or weaponName == '' or type(componentName) ~= 'string' or componentName == '' then
		return nil
	end

	local ok, first, second = pcall(ESX.GetWeaponComponent, weaponName, componentName)
	if not ok then
		return nil
	end

	if type(second) == 'table' then
		return second
	end

	return type(first) == 'table' and first or nil
end

local function AddComponentToState(state, componentName)
	if type(state) ~= 'table' or type(componentName) ~= 'string' or componentName == '' then
		return
	end

	if type(state.components) ~= 'table' then
		state.components = {}
	end

	for i = 1, #state.components do
		if state.components[i] == componentName then
			return
		end
	end

	state.components[#state.components + 1] = componentName
end

local function SyncBoughtUpgradeToPed(data)
	if Config.OxInventory or type(data) ~= 'table' then
		return
	end

	local weaponName = data.weaponName
	if type(weaponName) ~= 'string' or weaponName == '' then
		return
	end

	local ped = PlayerPedId()
	if not ped or ped == 0 then
		return
	end

	local weaponHash = joaat(weaponName)
	if not HasPedGotWeapon(ped, weaponHash, false) then
		return
	end

	if data.action == 'component' then
		local component = GetWeaponComponentData(weaponName, data.componentName)

		if component and component.hash and type(GiveWeaponComponentToPed) == 'function' then
			GiveWeaponComponentToPed(ped, weaponHash, component.hash)
		end
	elseif data.action == 'tint' then
		local tintIndex = NormalizeUiInteger(data.tintIndex)

		if tintIndex and type(SetPedWeaponTintIndex) == 'function' then
			SetPedWeaponTintIndex(ped, weaponHash, tintIndex)
		end
	end
end

local function BuildBoughtUpgradeState(data)
	if type(data) ~= 'table' or type(data.weaponName) ~= 'string' or type(BuildCurrentShopWeaponState) ~= 'function' then
		return nil
	end

	local state = BuildCurrentShopWeaponState(data.weaponName)
	if type(state) ~= 'table' then
		return nil
	end

	state.owned = true

	if data.action == 'component' then
		AddComponentToState(state, data.componentName)
	elseif data.action == 'ammo' then
		state.ammo = math.max((NormalizeUiInteger(state.ammo) or 0) + (NormalizeUiInteger(data.amount) or 0), 0)
	elseif data.action == 'tint' then
		state.tintIndex = NormalizeUiInteger(data.tintIndex) or state.tintIndex
	end

	return state
end

local function ApplyItemStateOverrides(items, stateOverrides)
	if type(stateOverrides) ~= 'table' then
		return
	end

	for i = 1, #items do
		local item = items[i]
		local override = item and stateOverrides[item.name]

		if type(override) == 'table' then
			item.state = {
				owned = override.owned == true or item.state.owned == true,
				ammo = math.max(NormalizeUiInteger(override.ammo) or NormalizeUiInteger(item.state.ammo) or 0, 0),
				tintIndex = math.max(NormalizeUiInteger(override.tintIndex) or NormalizeUiInteger(item.state.tintIndex) or 0, 0),
				components = type(override.components) == 'table' and override.components or item.state.components or {}
			}
		end
	end
end

---Opens weaponshop NUI
---@param zone string Shop zone name
---@param mode string NUI mode (`shop` or `license`)
---@param selectedName string|nil Weapon selected after refresh
---@param stateOverrides table|nil Item state overrides applied before sending data to NUI
local function OpenNui(zone, mode, selectedName, stateOverrides)
	local items = BuildShopItems(zone)
	ApplyItemStateOverrides(items, stateOverrides)

	currentShop = zone
	uiOpen = true

	ESX.HideUI()
	xLib.nui.focus(true, true)
	xLib.nui.send({
		type = 'openShop',
		shopData = {
			shopName = TranslateCap('shop_menu_title'),
			items = items,
			categories = BuildCategories(items),
			locales = GetShopLocales(),
			fallbackImage = GetWeaponShopFallbackImage(),
			legal = Config.Zones[zone].Legal,
			mode = mode,
			licensePrice = Config.LicensePrice,
			selectedName = selectedName
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
	xLib.nui.close({ type = 'closeShop' })
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
xLib.nui.register('ready', function()
	return { theme = GetESXThemeColors() }
end)

-- Purchase callback
xLib.nui.register('buyWeapon', function(data, reply)
	if type(data) ~= 'table' or type(data.weaponName) ~= 'string' or not currentShop then
		reply({ ok = false })
		return
	end

	local shop = currentShop

	xLib.callback('esx_weaponshop:buyWeapon', false, function(bought)
		if bought then
			local price = GetZoneWeaponPrice(shop, data.weaponName)
			DisplayBoughtScaleform(data.weaponName, price)
			SyncBoughtWeaponToPed(data.weaponName)

			if currentShop == shop then
				OpenNui(shop, 'shop', data.weaponName, {
					[data.weaponName] = BuildBoughtWeaponState(data.weaponName)
				})
			end
		else
			PlaySoundFrontend(-1, 'ERROR', 'HUD_AMMO_SHOP_SOUNDSET', false)
		end

		reply({ ok = bought and true or false })
	end, data.weaponName, shop)

	return xLib.nui.defer
end)

-- Upgrade purchase callback
xLib.nui.register('buyUpgrade', function(data, reply)
	if type(data) ~= 'table' or type(data.weaponName) ~= 'string' or type(data.action) ~= 'string' or not currentShop then
		reply({ ok = false })
		return
	end

	local shop = currentShop

	xLib.callback('esx_weaponshop:buyUpgrade', false, function(bought)
		if bought then
			PlaySoundFrontend(-1, 'WEAPON_PURCHASE', 'HUD_AMMO_SHOP_SOUNDSET', false)
			ESX.ShowNotification(TranslateCap('upgrade_bought'))
			SyncBoughtUpgradeToPed(data)

			if currentShop == shop then
				local state = BuildBoughtUpgradeState(data)
				OpenNui(shop, 'shop', data.weaponName, state and {
					[data.weaponName] = state
				} or nil)
			end
		else
			PlaySoundFrontend(-1, 'ERROR', 'HUD_AMMO_SHOP_SOUNDSET', false)
		end

		reply({ ok = bought and true or false })
	end, data, shop)

	return xLib.nui.defer
end)

-- License callback
xLib.nui.register('buyLicense', function(_, reply)
	xLib.callback('esx_weaponshop:buyLicense', false, function(bought)
		reply({ ok = bought and true or false })

		if bought and currentShop then
			OpenShop(currentShop)
		end
	end)

	return xLib.nui.defer
end)

-- Close UI callback
xLib.nui.register('closeUI', function()
	CloseShop()
	return 'ok'
end)
