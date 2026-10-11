-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local hasAlreadyEnteredMarker = false
local hasPaid = false
local currentActionData = {}
local lastZone
local currentAction
local currentActionMsg
local oldSkin
local newSkin
local purchasePending = false

local function restoreSkin()
    if type(oldSkin) == 'table' then
        TriggerEvent('skinchanger:loadSkin', oldSkin)
    end
end

function OpenShopMenu()
    if purchasePending then
        return
    end

    ESX.HideUI()
    hasPaid = false
    TriggerEvent('skinchanger:getSkin', function(skin)
        oldSkin = skin
    end)
    TriggerEvent('esx_skin:openRestrictedMenu', function(data, menu)
        menu.close()

        local elements = {
            {
                unselectable = true,
                icon = 'fas fa-check-double',
                title = TranslateCap('valid_this_purchase'),
            },
            { icon = 'fas fa-check-circle', title = TranslateCap('yes'), value = 'yes' },
            { icon = 'fas fa-window-close', title = TranslateCap('no'), value = 'no' },
        }

        ESX.OpenContext('right', elements, function(menu, element)
            if element.value == 'yes' then
                if purchasePending then
                    return
                end

                TriggerEvent('skinchanger:getSkin', function(skin)
                    newSkin = skin
                end)
                purchasePending = true

                xLib.callback('esx_clotheshop:buyClothes', false, function(bought, failure)
                    purchasePending = false

                    if bought then
                        hasPaid = true
                        TriggerEvent('esx_skin:setLastSkin', newSkin)

                        if not hasAlreadyEnteredMarker then
                            ESX.CloseContext()
                            return
                        end

                        xLib.callback(
                            'esx_clotheshop:checkPropertyDataStore',
                            false,
                            function(foundStore)
                                if foundStore then
                                    local elements2 = {
                                        {
                                            unselectable = true,
                                            icon = 'fas fa-check-double',
                                            title = TranslateCap('save_in_dressing'),
                                        },
                                        {
                                            icon = 'fas fa-check-circle',
                                            title = TranslateCap('yes'),
                                            value = 'yes',
                                        },
                                        {
                                            icon = 'fas fa-window-close',
                                            title = TranslateCap('no'),
                                            value = 'no',
                                        },
                                    }

                                    ESX.OpenContext('right', elements2, function(menu2, element2)
                                        if element2.value == 'yes' then
                                            local elements3 = {
                                                {
                                                    unselectable = true,
                                                    icon = 'fas fa-shirt',
                                                    title = TranslateCap('name_outfit'),
                                                },
                                                {
                                                    title = TranslateCap('outfit_name'),
                                                    input = true,
                                                    inputType = 'text',
                                                    inputPlaceholder = TranslateCap(
                                                        'outfit_placeholder'
                                                    ),
                                                },
                                                {
                                                    icon = 'fas fa-check-circle',
                                                    title = TranslateCap('confirm'),
                                                    value = 'confirm',
                                                },
                                            }

                                            ESX.OpenContext(
                                                'right',
                                                elements3,
                                                function(menu3, element3)
                                                    TriggerEvent(
                                                        'skinchanger:getSkin',
                                                        function(skin)
                                                            ESX.CloseContext()
                                                            TriggerServerEvent(
                                                                'esx_clotheshop:saveOutfit',
                                                                menu3.eles[2].inputValue,
                                                                skin
                                                            )
                                                            ESX.ShowNotification(
                                                                TranslateCap('saved_outfit')
                                                            )
                                                        end
                                                    )
                                                end,
                                                function()
                                                    hasAlreadyEnteredMarker = false
                                                end
                                            )
                                        elseif element2.value == 'no' then
                                            ESX.CloseContext()
                                        end
                                    end, function()
                                        hasAlreadyEnteredMarker = false
                                    end)
                                end
                            end
                        )
                    else
                        ESX.CloseContext()
                        restoreSkin()

                        local message = TranslateCap('not_enough_money')

                        if failure ~= 'not_enough_money' then
                            local translations = Locales[Config.Locale] or Locales.en
                            message = translations.save_failed or Locales.en.save_failed
                        end

                        ESX.ShowNotification(message)
                    end
                end, newSkin, oldSkin)
            elseif element.value == 'no' then
                restoreSkin()
                ESX.CloseContext()
            end
            currentAction = 'shop_menu'
            currentActionMsg = TranslateCap('press_menu')
            currentActionData = {}
        end, function(menu)
            if not purchasePending and not hasPaid then
                restoreSkin()
            end

            hasAlreadyEnteredMarker = false
            currentAction = 'shop_menu'
            currentActionMsg = TranslateCap('press_menu')
            currentActionData = {}
        end)

    end, function(data, menu)
        menu.close()
        restoreSkin()
        hasAlreadyEnteredMarker = false
        currentAction = 'shop_menu'
        currentActionMsg = TranslateCap('press_menu')
        currentActionData = {}
    end, {
        'tshirt_1',
        'tshirt_2',
        'torso_1',
        'torso_2',
        'decals_1',
        'decals_2',
        'arms',
        'arms_2',
        'pants_1',
        'pants_2',
        'shoes_1',
        'shoes_2',
        'bags_1',
        'bags_2',
        'chain_1',
        'chain_2',
        'helmet_1',
        'helmet_2',
        'glasses_1',
        'glasses_2',
        'watches_1',
        'watches_2',
    })
end

AddEventHandler('esx_clotheshop:hasEnteredMarker', function(zone)
    currentAction = 'shop_menu'
    currentActionMsg = TranslateCap('press_menu')
    currentActionData = {}
    ESX.TextUI(currentActionMsg)
end)

AddEventHandler('esx_clotheshop:hasExitedMarker', function(zone)
    ESX.CloseContext()
    ESX.HideUI()
    currentAction = nil

    if not hasPaid and not purchasePending then
        restoreSkin()
    end
end)

-- Create Blips
CreateThread(function()
    for k, v in ipairs(Config.Shops) do
        xLib.blips.create({
            coords = v,
            sprite = 73,
            color = 47,
            shortRange = true,
            label = TranslateCap('clothes'),
        })
    end
end)

-- Enter / Exit marker events & draw markers
CreateThread(function()
    for k, v in pairs(Config.Shops) do
        xLib.markerZone.create({
            coords = v,
            drawDistance = Config.DrawDistance,
            interactDistance = Config.MarkerSize.x,
            marker = {
                type = Config.MarkerType,
                size = Config.MarkerSize,
                color = {
                    r = Config.MarkerColor.r,
                    g = Config.MarkerColor.g,
                    b = Config.MarkerColor.b,
                    a = 100,
                },
            },
            onEnter = function()
                hasAlreadyEnteredMarker, lastZone = true, k
                TriggerEvent('esx_clotheshop:hasEnteredMarker', k)
            end,
            onExit = function()
                hasAlreadyEnteredMarker = false
                TriggerEvent('esx_clotheshop:hasExitedMarker', k)
            end,
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
