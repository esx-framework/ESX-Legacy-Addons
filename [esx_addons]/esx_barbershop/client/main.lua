-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local hasAlreadyEnteredMarker, cachedSkin, lastZone, currentAction, currentActionMsg, hasPaid

function OpenShopMenu()
	ESX.HideUI()
	hasPaid = false

	TriggerEvent('skinchanger:getSkin', function(skin)
		cachedSkin = skin;
	end)

	while not cachedSkin do
		Wait(10)
	end

	TriggerEvent('esx_skin:openRestrictedMenu', function(data, menu)
		menu.close()

		local elements = {
			{unselectable = true, icon = "fas fa-check-double", title = TranslateCap("valid_purchase")},
			{icon = "fas fa-check-circle", title = TranslateCap("yes"), value = "yes"},
			{icon = "fas fa-window-close", title = TranslateCap("no"), value = "no"},
		}

		ESX.OpenContext("right", elements, function(menu,element)
			if element.value == "yes" then
				xLib.callback('esx_barbershop:pay', false, function(paid)
					if paid then
						ESX.CloseContext()
						TriggerEvent('skinchanger:getSkin', function(skin)
							TriggerServerEvent('esx_skin:save', skin)
						end)

						hasPaid = true
					else
						ESX.CloseContext()
						TriggerEvent('skinchanger:loadSkin', cachedSkin)
									
						ESX.ShowNotification(TranslateCap('not_enough_money'))
					end
				end)
			elseif element.value == "no" then
				TriggerEvent('skinchanger:loadSkin', cachedSkin) 
				ESX.CloseContext()
			end
			currentAction = 'shop_menu'
			currentActionMsg = TranslateCap('press_access')
			ESX.TextUI(currentActionMsg)
		end, function(menu)
			currentAction = 'shop_menu'
			currentActionMsg = TranslateCap('press_access')
			ESX.TextUI(currentActionMsg)
		end)
	end, function(data, menu)
		menu.close()

		currentAction    = 'shop_menu'
		currentActionMsg  = TranslateCap('press_access')
		ESX.TextUI(currentActionMsg)
	end, {
		'beard_1',
		'beard_2',
		'beard_3',
		'beard_4',
		'hair_1',
		'hair_2',
		'hair_color_1',
		'hair_color_2',
		'eyebrows_1',
		'eyebrows_2',
		'eyebrows_3',
		'eyebrows_4',
		'makeup_1',
		'makeup_2',
		'makeup_3',
		'makeup_4',
		'lipstick_1',
		'lipstick_2',
		'lipstick_3',
		'lipstick_4',
		'ears_1',
		'ears_2',
	})
end

AddEventHandler('esx_barbershop:hasEnteredMarker', function(zone)
	currentAction = 'shop_menu'
	currentActionMsg = TranslateCap('press_access')
	ESX.TextUI(currentActionMsg)
end)

AddEventHandler('esx_barbershop:hasExitedMarker', function(zone)
	ESX.CloseContext()
	currentAction = nil
	ESX.HideUI()

	if not hasPaid then
		xLib.callback('esx_skin:getPlayerSkin', false, function(skin)
			TriggerEvent('skinchanger:loadSkin', skin)
		end)
	end
end)

-- Create Blips
CreateThread(function()
	for i = 1, #Config.Shops do
		xLib.blips.create({
			coords = Config.Shops[i],
			sprite = 71,
			color = 51,
			shortRange = true,
			label = TranslateCap('barber_blip')
		})
    	end
end)

-- Enter / Exit marker events and draw marker
CreateThread(function()
	for i = 1, #Config.Shops do
		xLib.markerZone.create({
			coords = Config.Shops[i],
			drawDistance = Config.DrawDistance,
			interactDistance = 1.5,
			marker = {
				type = Config.MarkerType,
				size = Config.MarkerSize,
				color = {
					r = Config.MarkerColor.r,
					g = Config.MarkerColor.g,
					b = Config.MarkerColor.b,
					a = 100
				}
			},
			onEnter = function()
				hasAlreadyEnteredMarker, lastZone = true, i
				TriggerEvent('esx_barbershop:hasEnteredMarker', i)
			end,
			onExit = function()
				hasAlreadyEnteredMarker = false
				TriggerEvent('esx_barbershop:hasExitedMarker', i)
			end
		})
	end
end)

-- Key controls
CreateThread(function()
	while true do
		Wait(0)

		if currentAction then
			if IsControlJustReleased(0, 38) then
				if currentAction == 'shop_menu' then
					OpenShopMenu()
				end

				currentAction = nil
			end
		else
			Wait(500)
		end
	end
end)
