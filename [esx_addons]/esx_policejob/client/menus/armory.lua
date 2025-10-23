local A = POLICE

function OpenArmoryMenu(station)
    if Config.OxInventory then
        exports.ox_inventory:openInventory('stash', { id = 'society_police', owner = station })
        return ESX.CloseContext()
    end

    local elements = {
        {unselectable = true, icon = "fas fa-gun", title = TranslateCap('armory')},
        {icon = "fas fa-gun", title = TranslateCap('buy_weapons'), value = 'buy_weapons'}
    }

    if Config.EnableArmoryManagement then
        table.insert(elements, {icon = "fas fa-gun", title = TranslateCap('get_weapon'),     value = 'get_weapon'})
        table.insert(elements, {icon = "fas fa-gun", title = TranslateCap('put_weapon'),     value = 'put_weapon'})
        table.insert(elements, {icon = "fas fa-box", title = TranslateCap('remove_object'),  value = 'get_stock'})
        table.insert(elements, {icon = "fas fa-box", title = TranslateCap('deposit_object'), value = 'put_stock'})
    end

    ESX.OpenContext("right", elements, function(menu,element)
        local data = {current = element}
        if data.current.value == 'get_weapon' then
            OpenGetWeaponMenu()
        elseif data.current.value == 'put_weapon' then
            OpenPutWeaponMenu()
        elseif data.current.value == 'buy_weapons' then
            OpenBuyWeaponsMenu()
        elseif data.current.value == 'put_stock' then
            OpenPutStocksMenu()
        elseif data.current.value == 'get_stock' then
            OpenGetStocksMenu()
        end
    end, function(menu)
        POLICE.CurrentAction     = 'menu_armory'
        POLICE.CurrentActionMsg  = TranslateCap('open_armory')
        POLICE.CurrentActionData = {station = station}
    end)
end

function OpenGetWeaponMenu()
    ESX.TriggerServerCallback('esx_policejob:getArmoryWeapons', function(weapons)
        local elements = {
            {unselectable = true, icon = "fas fa-gun", title = TranslateCap('get_weapon_menu')}
        }
        for i=1, #weapons do
            if weapons[i].count > 0 then
                elements[#elements+1] = {
                    icon = "fas fa-gun",
                    title = 'x' .. weapons[i].count .. ' ' .. ESX.GetWeaponLabel(weapons[i].name),
                    value = weapons[i].name
                }
            end
        end
        ESX.OpenContext("right", elements, function(menu,element)
            local data = {current = element}
            ESX.TriggerServerCallback('esx_policejob:removeArmoryWeapon', function()
                ESX.CloseContext()
                OpenGetWeaponMenu()
            end, data.current.value)
        end)
    end)
end

function OpenPutWeaponMenu()
    local elements   = {
        {unselectable = true, icon = "fas fa-gun", title = TranslateCap('put_weapon_menu')}
    }
    local playerPed  = PlayerPedId()
    local weaponList = ESX.GetWeaponList()

    for i=1, #weaponList do
        local weaponHash = joaat(weaponList[i].name)
        if HasPedGotWeapon(playerPed, weaponHash, false) and weaponList[i].name ~= 'WEAPON_UNARMED' then
            elements[#elements+1] = {
                icon = "fas fa-gun",
                title = weaponList[i].label,
                value = weaponList[i].name
            }
        end
    end

    ESX.OpenContext("right", elements, function(menu,element)
        local data = {current = element}
        ESX.TriggerServerCallback('esx_policejob:addArmoryWeapon', function()
            ESX.CloseContext()
            OpenPutWeaponMenu()
        end, data.current.value, true)
    end)
end

function OpenBuyWeaponsMenu()
    local elements = {
        {unselectable = true, icon = "fas fa-gun", title = TranslateCap('armory_weapontitle')}
    }
    local playerPed = PlayerPedId()

    for _,v in ipairs(Config.AuthorizedWeapons[ESX.PlayerData.job.grade_name]) do
        local weaponNum, weapon = ESX.GetWeapon(v.weapon)
        local components, label = {}, ''
        local hasWeapon = HasPedGotWeapon(playerPed, joaat(v.weapon), false)

        if v.components then
            for i=1, #v.components do
                if v.components[i] then
                    local component = weapon.components[i]
                    local hasComponent = HasPedGotWeaponComponent(playerPed, joaat(v.weapon), component.hash)
                    if hasComponent then
                        label = ('%s: <span style="color:green;">%s</span>'):format(component.label, TranslateCap('armory_owned'))
                    else
                        if v.components[i] > 0 then
                            label = ('%s: <span style="color:green;">%s</span>'):format(component.label, TranslateCap('armory_item', ESX.Math.GroupDigits(v.components[i])))
                        else
                            label = ('%s: <span style="color:green;">%s</span>'):format(component.label, TranslateCap('armory_free'))
                        end
                    end
                    components[#components+1] = {
                        icon = "fas fa-gun",
                        title = label,
                        componentLabel = component.label,
                        hash = component.hash,
                        name = component.name,
                        price = v.components[i],
                        hasComponent = hasComponent,
                        componentNum = i
                    }
                end
            end
        end

        if hasWeapon and v.components then
            label = ('%s: <span style="color:green;">▶</span>'):format(weapon.label)
        elseif hasWeapon and not v.components then
            label = ('%s: <span style="color:green;">%s</span>'):format(weapon.label, TranslateCap('armory_owned'))
        else
            if v.price > 0 then
                label = ('%s: <span style="color:green;">%s</span>'):format(weapon.label, TranslateCap('armory_item', ESX.Math.GroupDigits(v.price)))
            else
                label = ('%s: <span style="color:green;">%s</span>'):format(weapon.label, TranslateCap('armory_free'))
            end
        end

        elements[#elements+1] = {
            icon = "fas fa-gun",
            title = label,
            weaponLabel = weapon.label,
            name = weapon.name,
            components = components,
            price = v.price,
            hasWeapon = hasWeapon
        }
    end

    ESX.OpenContext("right", elements, function(menu,element)
        local data = {current = element}
        if data.current.hasWeapon then
            if #data.current.components > 0 then
                OpenWeaponComponentShop(data.current.components, data.current.name, menu)
            end
        else
            ESX.TriggerServerCallback('esx_policejob:buyWeapon', function(bought)
                if bought then
                    if data.current.price > 0 then
                        ESX.ShowNotification(TranslateCap('armory_bought', data.current.weaponLabel, ESX.Math.GroupDigits(data.current.price)))
                    end
                    ESX.CloseContext()
                    OpenBuyWeaponsMenu()
                else
                    ESX.ShowNotification(TranslateCap('armory_money'))
                end
            end, data.current.name, 1)
        end
    end)
end

function OpenWeaponComponentShop(components, weaponName, parentShop)
    ESX.OpenContext("right", components, function(menu,element)
        local data = {current = element}
        if data.current.hasComponent then
            ESX.ShowNotification(TranslateCap('armory_hascomponent'))
        else
            ESX.TriggerServerCallback('esx_policejob:buyWeapon', function(bought)
                if bought then
                    if data.current.price > 0 then
                        ESX.ShowNotification(TranslateCap('armory_bought', data.current.componentLabel, ESX.Math.GroupDigits(data.current.price)))
                    end
                    ESX.CloseContext()
                    parentShop.close()
                    OpenBuyWeaponsMenu()
                else
                    ESX.ShowNotification(TranslateCap('armory_money'))
                end
            end, weaponName, 2, data.current.componentNum)
        end
    end)
end

function OpenGetStocksMenu()
    ESX.TriggerServerCallback('esx_policejob:getStockItems', function(items)
        local elements = {
            {unselectable = true, icon = "fas fa-box", title = TranslateCap('police_stock')}
        }
        for i=1, #items do
            elements[#elements+1] = {
                icon = "fas fa-box",
                title = 'x' .. items[i].count .. ' ' .. items[i].label,
                value = items[i].name
            }
        end

        ESX.OpenContext("right", elements, function(menu,element)
            local data = {current = element}
            local itemName = data.current.value

            local elements2 = {
                {unselectable = true, icon = "fas fa-box", title = element.title},
                {title = TranslateCap('quantity'), input = true, inputType = "number", inputMin = 1, inputMax = 150, inputPlaceholder = TranslateCap('quantity_placeholder')},
                {icon = "fas fa-check-double", title = TranslateCap('confirm'), value = "confirm"}
            }

            ESX.OpenContext("right", elements2, function(menu2,element2)
                local data2 = {value = menu2.eles[2].inputValue}
                local count = tonumber(data2.value)
                if not count then
                    ESX.ShowNotification(TranslateCap('quantity_invalid'))
                else
                    ESX.CloseContext()
                    TriggerServerEvent('esx_policejob:getStockItem', itemName, count)
                    Wait(300)
                    OpenGetStocksMenu()
                end
            end)
        end)
    end)
end

function OpenPutStocksMenu()
    ESX.TriggerServerCallback('esx_policejob:getPlayerInventory', function(inventory)
        local elements = {
            {unselectable = true, icon = "fas fa-box", title = TranslateCap('inventory')}
        }
        for i=1, #inventory.items do
            local item = inventory.items[i]
            if item.count > 0 then
                elements[#elements+1] = {
                    icon = "fas fa-box",
                    title = item.label .. ' x' .. item.count,
                    type = 'item_standard',
                    value = item.name
                }
            end
        end

        ESX.OpenContext("right", elements, function(menu,element)
            local data = {current = element}
            local itemName = data.current.value

            local elements2 = {
                {unselectable = true, icon = "fas fa-box", title = element.title},
                {title = TranslateCap('quantity'), input = true, inputType = "number", inputMin = 1, inputMax = 150, inputPlaceholder = TranslateCap('quantity_placeholder')},
                {icon = "fas fa-check-double", title = TranslateCap('confirm'), value = "confirm"}
            }

            ESX.OpenContext("right", elements2, function(menu2,element2)
                local data2 = {value = menu2.eles[2].inputValue}
                local count = tonumber(data2.value)
                if not count then
                    ESX.ShowNotification(TranslateCap('quantity_invalid'))
                else
                    ESX.CloseContext()
                    TriggerServerEvent('esx_policejob:putStockItems', itemName, count)
                    Wait(300)
                    OpenPutStocksMenu()
                end
            end)
        end)
    end)
end
