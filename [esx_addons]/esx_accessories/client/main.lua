local show_text = false

function OpenAccessoryMenu()
	local elements = {
		{unselectable = true, icon = "fas fa-user", title = TranslateCap('set_unset')},
		{icon = "fas fa-hat-cowboy", title = TranslateCap("helmet"), value = "Helmet"},
		{icon = "fas fa-deaf", title = TranslateCap("ears"), value = "Ears"},
		{icon = "fas fa-mask", title = TranslateCap("mask"), value = "Mask"},
		{icon = "fas fa-glasses", title = TranslateCap("glasses"), value = "Glasses"}
	}

	ESX.OpenContext("right", elements, function(menu,element)
		SetUnsetAccessory(element.value)
	end)
end

function SetUnsetAccessory(accessory)
	ESX.TriggerServerCallback('esx_accessories:get', function(hasAccessory, accessorySkin)
		local _accessory = string.lower(accessory)

		if hasAccessory then
			TriggerEvent('skinchanger:getSkin', function(skin)
				local mAccessory = -1
				local mColor = 0

				if _accessory == "mask" then
					mAccessory = 0
				end

				if skin[_accessory .. '_1'] == mAccessory then
					mAccessory = accessorySkin[_accessory .. '_1']
					mColor = accessorySkin[_accessory .. '_2']
				end

				local accessorySkin = {}
				accessorySkin[_accessory .. '_1'] = mAccessory
				accessorySkin[_accessory .. '_2'] = mColor
				TriggerEvent('skinchanger:loadClothes', skin, accessorySkin)
			end)
		else
			ESX.ShowNotification(TranslateCap('no_' .. _accessory))
		end
	end, accessory)
end

function OpenShopMenu(accessory)
	local _accessory = string.lower(accessory)
	local restrict = {}

	restrict = { _accessory .. '_1', _accessory .. '_2' }

	TriggerEvent('esx_skin:openRestrictedMenu', function(data, menu)

		menu.close()	
		local elements = {
			{unselectable = true, icon = "fas fa-check-double", title = TranslateCap('valid_purchase')},
			{icon = "fas fa-check-circle", title = TranslateCap("yes", ESX.Math.GroupDigits(Config.Price)), value = "yes"},
			{icon = "fas fa-window-close", title = TranslateCap("no"), value = "no"}
		}

		ESX.OpenContext("right", elements, function(menu,element)
			if element.value == "yes" then
				ESX.TriggerServerCallback('esx_accessories:checkMoney', function(hasEnoughMoney)
					if hasEnoughMoney then
						ESX.CloseContext()
						TriggerServerEvent('esx_accessories:pay')
						TriggerEvent('skinchanger:getSkin', function(skin)
							TriggerServerEvent('esx_accessories:save', skin, accessory)
						end)
					else
						ESX.CloseContext()
						local player = PlayerPedId()
						TriggerEvent('esx_skin:getLastSkin', function(skin)
							TriggerEvent('skinchanger:loadSkin', skin)
						end)
						if accessory == "Ears" then
							ClearPedProp(player, 2)
						elseif accessory == "Mask" then
							SetPedComponentVariation(player, 1, 0 ,0, 2)
						elseif accessory == "Helmet" then
							ClearPedProp(player, 0)
						elseif accessory == "Glasses" then
							SetPedPropIndex(player, 1, -1, 0, 0)
						end
						ESX.ShowNotification(TranslateCap('not_enough_money'))
					end
				end)
			elseif element.value == "no" then
				local player = PlayerPedId()
				TriggerEvent('esx_skin:getLastSkin', function(skin)
					TriggerEvent('skinchanger:loadSkin', skin)
				end)
				if accessory == "Ears" then
					ClearPedProp(player, 2)
				elseif accessory == "Mask" then
					SetPedComponentVariation(player, 1, 0 ,0, 2)
				elseif accessory == "Helmet" then
					ClearPedProp(player, 0)
				elseif accessory == "Glasses" then
					SetPedPropIndex(player, 1, -1, 0, 0)
				end

				ESX.CloseContext()
			end
		end, function(menu)
		end)
	end, function(data, menu)
		menu.close()
	end, restrict)
end

-- Create Blips --
CreateThread(function()
	for k,v in pairs(Config.ShopsBlips) do
		if v.Pos then
			for i=1, #v.Pos, 1 do
				local blip = AddBlipForCoord(v.Pos[i])

				SetBlipSprite (blip, v.Blip.sprite)
				SetBlipDisplay(blip, 4)
				SetBlipScale  (blip, 1.0)
				SetBlipColour (blip, v.Blip.color)
				SetBlipAsShortRange(blip, true)

				BeginTextCommandSetBlipName("STRING")
				AddTextComponentSubstringPlayerName(TranslateCap('shop', TranslateCap(string.lower(k))))
				EndTextCommandSetBlipName(blip)
			end
		end
	end
end)

CreateThread(function()
	while true do
		local interval = true
		local playerCoords = GetEntityCoords(PlayerPedId())
		local isInMarker = false
		
		for k,v in pairs(Config.Zones) do
			for i = 1, #v.Pos, 1 do
				local distance = #(playerCoords - v.Pos[i])
				
				if Config.Type ~= -1 and distance < Config.DrawDistance then
					DrawMarker(Config.Type, v.Pos[i], 0.0, 0.0, 0.0, 0, 0.0, 0.0, Config.Size.x, Config.Size.y, Config.Size.z, Config.Color.r, Config.Color.g, Config.Color.b, 255, true, false, 2, true, false, false, false)
					interval = false
				end
				
				if distance < Config.Size.x then
					isInMarker = true
					interval = false
					if IsControlJustReleased(0, 38) then
						OpenShopMenu(k)
					end
				end
			end
		end
		
		if isInMarker and not show_text then
			ESX.TextUI(TranslateCap('press_access'))
			show_text = true
		elseif not isInMarker and show_text then
			ESX.HideUI()
			show_text = false
		end
		
		if interval then
			Wait(500)
		else
			Wait(0)
		end
	end
end)

if Config.EnableControls then
	ESX.RegisterInput('accessory', TranslateCap('keymap'), 'keyboard', 'j', function()
		if not ESX.PlayerData.dead then
			OpenAccessoryMenu()
		end
	end)
end