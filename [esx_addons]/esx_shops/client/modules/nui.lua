local currentShop = nil
local uiOpen = false
local nuiReady = false

-- NUI Ready Callback
RegisterNUICallback('ready', function(data, cb)
	cb({ theme = GetESXThemeColors() })
	nuiReady = true
end)

---Opens shop NUI
---@param zone string Shop zone name
function OpenShop(zone)
	if uiOpen then
		DebugPrint('[esx_shops] Shop already open')
		return
	end

	if not nuiReady then
		DebugPrint('[esx_shops] NUI not ready yet')
		ESX.ShowNotification(_U('nui_not_ready'))
		return
	end

	local zoneData = Config.Zones[zone]
	if not zoneData then return end

	local callbackReceived = false
	local defaultTaxRate = Config.TaxRate

	local processedItems = ProcessItemImages(zoneData.Items)

	SetTimeout(5000, function()
		if not callbackReceived then
			DebugPrint('[^3WARNING^7] ' .. _U('tax_callback_timeout'))

			local shopData = {
				shopName = zone,
				items = processedItems,
				categories = zoneData.Categories,
				taxRate = defaultTaxRate,
				taxMessage = nil
			}

			SetNuiFocus(true, true)
			SendNUIMessage({
				type = 'openShop',
				shopData = shopData
			})

			currentShop = zone
			uiOpen = true
		end
	end)

	-- Get player's dynamic tax rate
	ESX.TriggerServerCallback('esx_shops:getTaxRate', function(taxRate, taxMessage)
		if callbackReceived then return end
		callbackReceived = true

		local shopData = {
			shopName = zone,
			items = processedItems,
			categories = zoneData.Categories,
			taxRate = taxRate,
			taxMessage = taxMessage
		}

		SetNuiFocus(true, true)
		SendNUIMessage({
			type = 'openShop',
			shopData = shopData
		})

		currentShop = zone
		uiOpen = true
	end)
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

---Checks if NUI is ready
---@return boolean
function IsNUIReady()
	return nuiReady
end

-- Purchase callback
RegisterNUICallback('purchaseItems', function(data, cb)
	if not currentShop then
		cb({
			ok = false,
			error = { code = 'CLIENT', message = _U('no_shop_selected') }
		})
		return
	end

	ESX.TriggerServerCallback('esx_shops:purchaseItems', function(success, message)
		if success then
			cb({ ok = true, data = { message = message } })
		else
			cb({ ok = false, error = { code = 'SERVER', message = message } })
		end
	end, data, currentShop)
end)

-- Close UI callback
RegisterNUICallback('closeUI', function(data, cb)
	CloseShop()
	cb('ok')
end)
