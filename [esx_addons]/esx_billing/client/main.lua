-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local isDead = false

local function showBillsMenu(afterId, history)
    afterId, history = afterId or 0, history or {}
    xLib.callback('esx_billing:getBills', false, function(bills, hasNext)
        if type(bills) ~= 'table' then
            return
        end

        if #bills <= 0 then
            if #history > 0 then
                local previous = table.remove(history)
                return SetTimeout(1000, function()
                    showBillsMenu(previous, history)
                end)
            end

            return ESX.ShowNotification(TranslateCap('no_invoices'))
        end

        local elements = {
            { unselectable = true, icon = 'fas fa-scroll', title = TranslateCap('invoices') },
        }

        for _, v in ipairs(bills) do
            elements[#elements + 1] = {
                icon = 'fas fa-scroll',
                title = ('%s - <span style="color:red;">%s</span>'):format(
                    v.label,
                    TranslateCap('invoices_item', ESX.Math.GroupDigits(v.amount))
                ),
                billId = v.id,
            }
        end

        if #history > 0 then
            elements[#elements + 1] = { title = '‹', previousPage = true }
        end

        if hasNext then
            elements[#elements + 1] = { title = '›', nextPage = bills[#bills].id }
        end

        ESX.OpenContext('right', elements, function(menu, element)
            if element.previousPage then
                return showBillsMenu(table.remove(history), history)
            end

            if element.nextPage then
                history[#history + 1] = afterId
                return showBillsMenu(element.nextPage, history)
            end

            local billId = element.billId

            if not billId then
                return
            end

            xLib.callback('esx_billing:payBill', false, function(resp)
                SetTimeout(1000, function()
                    showBillsMenu(afterId, history)
                end)

                if not resp then
                    return
                end
                TriggerEvent('esx_billing:paidBill', billId)
            end, billId)
        end)
    end, afterId)
end

RegisterCommand('showbills', function()
    if not isDead then
        showBillsMenu()
    end
end, false)

RegisterKeyMapping('showbills', TranslateCap('keymap_showbills'), 'keyboard', 'F7')

RegisterNetEvent('esx_billing:confirmHighBill', function(token, label, amount, senderName)
    local elements = {
        {
            unselectable = true,
            icon = 'fas fa-scroll',
            title = ('%s - %s'):format(label, ESX.Math.GroupDigits(amount)),
        },
        { icon = 'fas fa-check', title = 'Accept invoice', value = true },
        { icon = 'fas fa-times', title = 'Decline invoice', value = false },
    }

    ESX.ShowNotification(
        ('High invoice from %s requires confirmation'):format(senderName or 'unknown')
    )

    ESX.OpenContext('right', elements, function(menu, element)
        if element.value == nil then
            return
        end

        xLib.callback(
            'esx_billing:respondHighBill',
            false,
            function() end,
            token,
            element.value == true
        )
        ESX.CloseContext()
    end, function()
        xLib.callback('esx_billing:respondHighBill', false, function() end, token, false)
    end)
end)

AddEventHandler('esx:onPlayerDeath', function()
    isDead = true
end)
AddEventHandler('esx:onPlayerSpawn', function()
    isDead = false
end)
