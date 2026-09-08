local currentShop = nil
local uiOpen = false
local nuiReady = false

-- NUI Ready Callback
xLib.nui.register('ready', function()
	nuiReady = true
	return { theme = GetESXThemeColors() }
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

			xLib.nui.focus(true, true)
			xLib.nui.send({
				type = 'openShop',
				shopData = shopData
			})

			currentShop = zone
			uiOpen = true
		end
	end)

	-- Get player's dynamic tax rate
	xLib.callback('esx_shops:getTaxRate', false, function(taxRate, taxMessage)
		if callbackReceived then return end
		callbackReceived = true

		local shopData = {
			shopName = zone,
			items = processedItems,
			categories = zoneData.Categories,
			taxRate = taxRate,
			taxMessage = taxMessage
		}

		xLib.nui.focus(true, true)
		xLib.nui.send({
			type = 'openShop',
			shopData = shopData
		})

		currentShop = zone
		uiOpen = true
	end)
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

---Checks if NUI is ready
---@return boolean
function IsNUIReady()
	return nuiReady
end

-- Purchase callback
xLib.nui.register('purchaseItems', function(data, reply)
	if not currentShop then
		reply({
			ok = false,
			error = { code = 'CLIENT', message = _U('no_shop_selected') }
		})
		return
	end

	xLib.callback('esx_shops:purchaseItems', false, function(success, message)
		if success then
			reply({ ok = true, data = { message = message } })
		else
			reply({ ok = false, error = { code = 'SERVER', message = message } })
		end
	end, data, currentShop)

	return xLib.nui.defer
end)

-- Close UI callback
xLib.nui.register('closeUI', function()
	CloseShop()
	return 'ok'
end)
