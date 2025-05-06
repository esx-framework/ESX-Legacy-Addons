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

-- Create Blips
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
local GetEntityCoords = GetEntityCoords
local CreateThread = CreateThread
local Wait = Wait
local IsControlJustReleased = IsControlJustReleased

-- Display markers
CreateThread(function()
    while true do
        local sleep = 1500
        local currentShop = nil
        local coords = GetEntityCoords(ESX.PlayerData.ped)

        for k, v in pairs(Config.Zones) do
            for i = 1, #v.Locations, 1 do
                if (Config.Type ~= -1 and #(coords - v.Locations[i]) < Config.DrawDistance) then
                    currentShop = v.Locations[i]
                    sleep = 0
                    if #(coords - currentShop) < 2.0 then
                        if not textShown then
                            ESX.TextUI(TranslateCap('shop_menu_prompt', ESX.GetInteractKey()))
                            textShown = true
                            nearbyZone = k
                        end
                    end
                    DrawMarker(Config.Type, v.Locations[i].x, v.Locations[i].y, v.Locations[i].z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, Config.Size.x, Config.Size.y,
                    Config.Size.z, Config.Color.r, Config.Color.g, Config.Color.b, 100, false, true, 2, false, false,
                    false, false)
                end
            end
        end

        if (not currentShop or shopOpen) and textShown then
            textShown = false
            nearbyZone = nil
            ESX.HideUI()
        end

        if not currentShop and shopOpen then
            textShown = false
            ESX.HideUI()
            ESX.CloseContext()
            shopOpen = false
            nearbyZone = nil
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
