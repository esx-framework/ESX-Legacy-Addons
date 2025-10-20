do
    local menuOpen = false
    local cfgMarker = Config.Marker
    local dealerCoords = Config.CircleZones.DrugDealer.coords
    local drugDealerPoint = ESX.Point:new({
        coords = dealerCoords,
        distance = 2,
        enter = function()
            ESX.TextUI(TranslateCap('dealer_prompt'))
        end,
        leave = function()
            ESX.HideUI()
            if menuOpen then
                menuOpen = false
            end
        end,
        inside = function(self)
			DrawMarker(cfgMarker.Type, dealerCoords.x, dealerCoords.y, dealerCoords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, cfgMarker.Size, cfgMarker.Color.r, cfgMarker.Color.g, cfgMarker.Color.b, cfgMarker.Color.a, false, true, 2, false, nil, nil, false)
            if IsControlJustPressed(0, 38) then
                OpenDrugShop()
                menuOpen = true
            end
        end
    })
end

function OpenDrugShop()
	local elements = {
		{ unselectable = true, icon = "fas fa-cannabis", title = TranslateCap('dealer_title') }
	}
	menuOpen = true

	for _, v in ipairs(ESX.GetPlayerData().inventory) do
		local price = Config.DrugDealerItems[v.name]
		if price and v.count > 0 then
			elements[#elements+1] = {
				icon = "fas fa-shopping-basket",
				title = ('%s - <span style="color:green;">%s</span>'):format(
					v.label, 
					TranslateCap('dealer_item', ESX.Math.GroupDigits(price))
				),
				name = v.name,
				price = price,
			}
		end
	end

	ESX.OpenContext("right", elements, function(menu, element)
		do
			local elements = {
				{ unselectable = true, icon = "fas fa-shopping-basket", title = element.title },
				{
					icon = "fas fa-shopping-basket",
					title = "Amount",
					input = true,
					inputType = "number",
					inputPlaceholder = "Amount you want to sell",
					inputValue = 0,
					inputMin = Config.SellMenu.Min,
					inputMax = Config.SellMenu.Max
				},
				{ icon = "fas fa-check-double", title = "Confirm", val = "confirm" }
			}

			ESX.OpenContext("right", elements, function(menu2, element2)
				ESX.CloseContext()
				local count = tonumber(menu2.eles[2] and menu2.eles[2].inputValue)
				if not count or count < 1 then return end
				TriggerServerEvent('esx_drugs:sellDrug', tostring(element.name), count)
			end, function(menu2)
				menuOpen = false
			end)
		end
	end, function(menu)
		menuOpen = false
	end)
end

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		if menuOpen then
			ESX.CloseContext()
		end
	end
end)

function OpenBuyLicenseMenu(licenseName)
	menuOpen = true
	local license = Config.LicensePrices[licenseName]
	local elements = {
		{unselectable = true, title = TranslateCap('purchase_license')},
		{title = ('%s - <span style="color:green;">%s</span>'):format(license.label, TranslateCap('dealer_item', ESX.Math.GroupDigits(license.price))), value = licenseName, price = license.price, licenseName = license.label}
	}
	ESX.OpenContext("right", elements, function(menu,element)
		ESX.TriggerServerCallback('esx_drugs:buyLicense', function(boughtLicense)
			if boughtLicense then
				ESX.CloseContext()
				ESX.ShowNotification(TranslateCap('license_bought', element.licenseName, ESX.Math.GroupDigits(element.price)))
			else
				ESX.ShowNotification(TranslateCap('license_bought_fail', element.licenseName))
			end
		end, element.value)
	end, function(menu)
		menuOpen = false
	end)
end

function CreateBlipCircle(coords, text, radius, color, sprite)
	local blip = AddBlipForRadius(coords, radius)
	SetBlipHighDetail(blip, true)
	SetBlipColour(blip, 1)
	SetBlipAlpha (blip, 128)
	blip = AddBlipForCoord(coords)
	SetBlipHighDetail(blip, true)
	SetBlipSprite (blip, sprite)
	SetBlipScale  (blip, 1.0)
	SetBlipColour (blip, color)
	SetBlipAsShortRange(blip, true)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentSubstringPlayerName(text)
	EndTextCommandSetBlipName(blip)
end

CreateThread(function()
	for k,zone in pairs(Config.CircleZones) do
		CreateBlipCircle(zone.coords, zone.name, zone.radius, zone.color, zone.sprite)
	end
end)