
-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local HasAlreadyEnteredMarker = false
local LastZone, CurrentAction, CurrentActionMsg
local CurrentActionData = {}

function OpenAccessoryMenu()
    local elements = {
        {unselectable = true, icon = "fas fa-user", title = TranslateCap('set_unset')},
        {icon = "fas fa-hat-cowboy", title = TranslateCap("helmet"), value = "Helmet"},
        {icon = "fas fa-deaf", title = TranslateCap("ears"), value = "Ears"},
        {icon = "fas fa-mask", title = TranslateCap("mask"), value = "Mask"},
        {icon = "fas fa-glasses", title = TranslateCap("glasses"), value = "Glasses"}
    }

    ESX.OpenContext("right", elements, function(menu, element)
        SetUnsetAccessory(element.value)
    end)
end

function SetUnsetAccessory(accessory)
    xLib.callback('esx_accessories:get', false, function(hasAccessory, accessorySkin)
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

                local newAccessorySkin = {}
                newAccessorySkin[_accessory .. '_1'] = mAccessory
                newAccessorySkin[_accessory .. '_2'] = mColor

                TriggerEvent('skinchanger:loadClothes', skin, newAccessorySkin)
            end)
        else
            ESX.ShowNotification(TranslateCap('no_' .. _accessory))
        end
    end, accessory)
end

function OpenShopMenu(accessory)
    local _accessory = string.lower(accessory)
    local restrict = { _accessory .. '_1', _accessory .. '_2' }

    TriggerEvent('esx_skin:openRestrictedMenu', function(data, menu)
        menu.close()

        PaymentGateway.Pay({
            amount = Config.Price,
            title = TranslateCap(string.lower(accessory)),
        }, 'esx_accessories:buy', function(bought, paymentFailure)
            if bought then
                TriggerEvent('skinchanger:getSkin', function(skin)
                    TriggerServerEvent('esx_accessories:save', skin, accessory)
                end)
            else
                local player = PlayerPedId()

                TriggerEvent('esx_skin:getLastSkin', function(skin)
                    if skin then
                        TriggerEvent('skinchanger:loadSkin', skin)
                    end
                end)

                if accessory == "Ears" then
                    ClearPedProp(player, 2)
                elseif accessory == "Mask" then
                    SetPedComponentVariation(player, 1, 0, 0, 2)
                elseif accessory == "Helmet" then
                    ClearPedProp(player, 0)
                elseif accessory == "Glasses" then
                    SetPedPropIndex(player, 1, -1, 0, 0)
                end

                PaymentGateway.NotifyFailure(
                    paymentFailure,
                    TranslateCap('not_enough_money')
                )
            end

            CurrentAction = 'shop_menu'
            CurrentActionMsg = TranslateCap('press_access')
            CurrentActionData = {}
        end, accessory)

    end, function(data, menu)
        menu.close()

        CurrentAction = 'shop_menu'
        CurrentActionMsg = TranslateCap('press_access')
        CurrentActionData = {}
    end, restrict)
end

AddEventHandler('esx_accessories:hasEnteredMarker', function(zone)
    CurrentAction = 'shop_menu'
    CurrentActionMsg = TranslateCap('press_access')
    CurrentActionData = { accessory = zone }
end)

AddEventHandler('esx_accessories:hasExitedMarker', function(zone)
    ESX.CloseContext()
    CurrentAction = nil
end)

-- Create Blips
CreateThread(function()
    for k, v in pairs(Config.ShopsBlips) do
        if v.Pos then
            for i = 1, #v.Pos do
                xLib.blips.create({
                    coords = v.Pos[i],
                    sprite = v.Blip.sprite,
                    display = 4,
                    scale = 1.0,
                    color = v.Blip.color,
                    shortRange = true,
                    label = TranslateCap('shop', TranslateCap(string.lower(k)))
                })
            end
        end
    end
end)

-- Display markers
CreateThread(function()
    if Config.Type == -1 then
        return
    end

    for k, v in pairs(Config.Zones) do
        for i = 1, #v.Pos do
            xLib.markerZone.create({
                coords = v.Pos[i],
                drawDistance = Config.DrawDistance,
                interactDistance = Config.Size.x,
                marker = {
                    type = Config.Type,
                    size = Config.Size,
                    color = {
                        r = Config.Color.r,
                        g = Config.Color.g,
                        b = Config.Color.b,
                        a = 255
                    },
                    bobUpAndDown = true,
                    faceCamera = false,
                    rotate = true
                },
                onEnter = function()
                    HasAlreadyEnteredMarker = true
                    LastZone = k
                    TriggerEvent('esx_accessories:hasEnteredMarker', k)
                end,
                onExit = function()
                    HasAlreadyEnteredMarker = false
                    TriggerEvent('esx_accessories:hasExitedMarker', k)
                end
            })
        end
    end
end)

-- Key controls
CreateThread(function()
	while true do
		local Sleep = 1500
		
		if CurrentAction then
			Sleep = 0
			ESX.ShowHelpNotification(CurrentActionMsg)

			if IsControlJustReleased(0, 38) and CurrentActionData.accessory then
				OpenShopMenu(CurrentActionData.accessory)
				CurrentAction = nil
			end
		end
		Wait(Sleep)
	end
end)

if Config.EnableControls then
    xLib.addKeybind({
        name = 'accessory',
        description = TranslateCap('keymap'),
        defaultMapper = 'keyboard',
        defaultKey = 'j',
        onPressed = function()
            if not ESX.PlayerData.dead then
                OpenAccessoryMenu()
            end
        end,
    })
end