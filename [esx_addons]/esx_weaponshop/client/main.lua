local shopOpen = false
local nearbyZone = nil
function OpenBuyLicenseMenu(zone)
    shopOpen = true
    local elements = {{
        icon = "fa-regular fa-money-bill-alt",
        unselectable = true,
        title = TranslateCap("license_shop_title")
	}, {
		icon = "fa-regular fa-id-card",
		title = TranslateCap("buy_license"),
        description = "Price: $"..Config.LicensePrice,
		value = "buylicense"
	}, {
		icon = "fa-solid fa-xmark",
		title = TranslateCap("menu_cancel"),
		value = "cancel"
    }}

    ESX.OpenContext(Config.MenuPosition, elements, function(menu, element)
        if element.value == "buylicense" then
			ESX.TriggerServerCallback('esx_weaponshop:buyLicense', function(bought)
                if bought then
                    ESX.CloseContext()
                end
            end)
		end
		if element.value == "cancel" then
          shopOpen = false
          ESX.CloseContext()
		end
    end)
end

function OpenShopMenu(zone)
    shopOpen = true
    local elements = {{
        icon = "fa-solid fa-bullseye",
        unselectable = true,
        description = TranslateCap("weapon_shop_menu_description"),
        title = TranslateCap("weapon_shop_menu_title")
    }}
    for i = 1, #Config.Zones[zone].Items, 1 do
        local item = Config.Zones[zone].Items[i]
        item.label = ESX.GetWeaponLabel(item.name)
        elements[#elements + 1] = {
            icon = "fa-solid fa-gun",
            title = item.label,
            description = "Price: $".. ESX.Math.GroupDigits(item.price),
            price = item.price,
            weaponName = item.name,
            value = "buy"
        }
    end

    ESX.OpenContext(Config.MenuPosition, elements, function(menu, element)

        if element.value == "buy" then
            ESX.TriggerServerCallback('esx_weaponshop:buyWeapon', function(bought)
                if bought then
                    DisplayBoughtScaleform(element.weaponName, element.price)
					ESX.CloseContext()
                else
                    PlaySoundFrontend(-1, 'ERROR', 'HUD_AMMO_SHOP_SOUNDSET', false)
                end
            end, element.weaponName, zone)
        end

    end, function(menu)
        shopOpen = false
    end)
end

function DisplayBoughtScaleform(weaponName, price)
    local scaleform = ESX.Scaleform.Utils.RequestScaleformMovie('MP_BIG_MESSAGE_FREEMODE')
    local sec = 4

    BeginScaleformMovieMethod(scaleform, 'SHOW_WEAPON_PURCHASED')

    ScaleformMovieMethodAddParamTextureNameString(TranslateCap('weapon_bought', ESX.Math.GroupDigits(price)))
    ScaleformMovieMethodAddParamTextureNameString(ESX.GetWeaponLabel(weaponName))
    ScaleformMovieMethodAddParamInt(joaat(weaponName))
    ScaleformMovieMethodAddParamTextureNameString('')
    ScaleformMovieMethodAddParamInt(100)
    EndScaleformMovieMethod()

    PlaySoundFrontend(-1, 'WEAPON_PURCHASE', 'HUD_AMMO_SHOP_SOUNDSET', false)

    CreateThread(function()
        while sec > 0 do
            Wait(0)
            sec = sec - 0.01

            DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255)
        end
    end)
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if shopOpen then
            ESX.CloseContext()
        end
    end
end)

CreateThread(function()
    for k, v in pairs(Config.Zones) do
        local blipSettings = v.Blip
        if blipSettings.Enabled then
            for i = 1, #v.Locations, 1 do
                local blip = AddBlipForCoord(v.Locations[i])

                SetBlipSprite(blip, blipSettings.Sprite)
                SetBlipDisplay(blip, blipSettings.Display)
                SetBlipScale(blip, blipSettings.Scale)
                SetBlipColour(blip, blipSettings.Colour)
                SetBlipAsShortRange(blip, blipSettings.ShortRange)

                BeginTextCommandSetBlipName("STRING")
                AddTextComponentSubstringPlayerName(TranslateCap('map_blip'))
                EndTextCommandSetBlipName(blip)
            end
        end
    end
end)

local textShown = false
local HasAlreadyEnteredMarker = false
local LastZone = nil

CreateThread(function()
	while true do
		local sleep = 1500
		local coords = GetEntityCoords(ESX.PlayerData.ped)
		local isInMarker = false
		local currentZone = nil
		local nearMarker = false

		for k, v in pairs(Config.Zones) do
			for i = 1, #v.Locations, 1 do
				local location = v.Locations[i]
				local distance = #(coords - location)
				if (Config.Type ~= -1 and distance < Config.DrawDistance) then
					nearMarker = true
					DrawMarker(Config.Type, location.x, location.y, location.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, Config.Size.x, Config.Size.y,
					Config.Size.z, Config.Color.r, Config.Color.g, Config.Color.b, 100, false, true, 2, false, false,
					false, false)
					if distance < Config.Size.x then
						isInMarker = true
						currentZone = k
						break
					end
				end
			end
		end

		if nearMarker then
			sleep = 0
		end

		if isInMarker and (not HasAlreadyEnteredMarker or LastZone ~= currentZone) then
			HasAlreadyEnteredMarker = true
			LastZone = currentZone
			nearbyZone = currentZone
			if not textShown then
				ESX.TextUI(TranslateCap('shop_menu_prompt', ESX.GetInteractKey()))
				textShown = true
			end
		end

		if not isInMarker and HasAlreadyEnteredMarker then
			HasAlreadyEnteredMarker = false
			if textShown then
				ESX.HideUI()
				textShown = false
			end
			nearbyZone = nil
			if shopOpen then
				ESX.CloseContext()
				shopOpen = false
			end
		end

		Wait(sleep)
	end
end)

ESX.RegisterInteraction("open_weaponshop", function ()
    local zone = Config.Zones[nearbyZone]

    if Config.LicenseEnable and zone.Legal then
        ESX.TriggerServerCallback('esx_license:checkLicense', function(hasWeaponLicense)
            if hasWeaponLicense then
                OpenShopMenu(nearbyZone)
            else
                OpenBuyLicenseMenu(nearbyZone)
            end
        end, ESX.serverId, 'weapon')
    else
        OpenShopMenu(nearbyZone)
    end
end, function()
    return nearbyZone ~= nil and not shopOpen
end)