-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local currentShop = nil
local uiOpen = false
local openingShop = false
local nuiReady = false

-- NUI Ready Callback
xLib.nui.register('ready', function()
	nuiReady = true
	return { theme = GetESXThemeColors() }
end)

---Opens shop NUI
---@param zone string Shop zone name
function OpenShop(zone)
	if uiOpen or openingShop then
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
	openingShop = true

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
			openingShop = false
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
		openingShop = false
	end)
end

function CloseShop()
	xLib.nui.close({ type = 'closeShop' })
	currentShop = nil
	uiOpen = false
	openingShop = false
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
xLib.nui.register('purchaseItems', function(data)
    local shop = currentShop

    if not shop or type(data) ~= 'table' then
        return {
            ok = false,
            error = { code = 'CLIENT', message = _U('no_shop_selected') },
        }
    end

    xLib.nui.send({ type = 'paymentGateway', active = true })
    xLib.nui.focus(false, false)

    local success, message = PaymentGateway.Await({
        quote = 'esx_shops:quotePurchase',
        title = shop,
    }, 'esx_shops:purchaseItemsGateway', data, shop)

    xLib.nui.send({ type = 'paymentGateway', active = false })

    if currentShop == shop and uiOpen then
        xLib.nui.focus(true, true)
    end

    if success then
        return { ok = true, data = { message = message } }
    end

    return { ok = false, error = { code = 'PAYMENT', message = message } }
end)

-- Close UI callback
xLib.nui.register('closeUI', function()
	CloseShop()
	return 'ok'
end)
