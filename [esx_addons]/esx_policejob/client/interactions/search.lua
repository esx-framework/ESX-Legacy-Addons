local A = POLICE

function OpenBodySearchMenu(player)
    if Config.OxInventory then
        ESX.CloseContext()
        exports.ox_inventory:openInventory('player', GetPlayerServerId(player))
        return
    end

    ESX.TriggerServerCallback('esx_policejob:getOtherPlayerData', function(data)
        local elements = {
            {unselectable = true, icon = "fas fa-user", title = TranslateCap('search')}
        }

        for i=1, #data.accounts do
            if data.accounts[i].name == 'black_money' and data.accounts[i].money > 0 then
                elements[#elements+1] = {
                    icon = "fas fa-money-bill",
                    title    = TranslateCap('confiscate_dirty', ESX.Math.Round(data.accounts[i].money)),
                    value    = 'black_money',
                    itemType = 'item_account',
                    amount   = data.accounts[i].money
                }
                break
            end
        end

        elements[#elements+1] = {unselectable = true, icon = "fas fa-gun", title = TranslateCap('guns_label')}

        for i=1, #data.weapons do
            elements[#elements+1] = {
                icon = "fas fa-gun",
                title    = TranslateCap('confiscate_weapon', ESX.GetWeaponLabel(data.weapons[i].name), data.weapons[i].ammo),
                value    = data.weapons[i].name,
                itemType = 'item_weapon',
                amount   = data.weapons[i].ammo
            }
        end

        elements[#elements+1] = {unselectable = true, icon = "fas fa-box", title = TranslateCap('inventory_label')}

        for i=1, #data.inventory do
            if data.inventory[i].count > 0 then
                elements[#elements+1] = {
                    icon = "fas fa-box",
                    title    = TranslateCap('confiscate_inv', data.inventory[i].count, data.inventory[i].label),
                    value    = data.inventory[i].name,
                    itemType = 'item_standard',
                    amount   = data.inventory[i].count
                }
            end
        end

        ESX.OpenContext("right", elements, function(menu,element)
            local dataEl = {current = element}
            if dataEl.current.value then
                TriggerServerEvent('esx_policejob:confiscatePlayerItem', GetPlayerServerId(player), dataEl.current.itemType, dataEl.current.value, dataEl.current.amount)
                OpenBodySearchMenu(player)
            end
        end)
    end, GetPlayerServerId(player))
end
