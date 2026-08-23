local A = POLICE
local fineList = {}

function OpenFineMenu(player)
    if Config.EnableFinePresets then
        local elements = {
            {unselectable = true, icon = "fas fa-scroll", title = TranslateCap('fine')},
            {icon = "fas fa-scroll", title = TranslateCap('traffic_offense'), value = 0},
            {icon = "fas fa-scroll", title = TranslateCap('minor_offense'),   value = 1},
            {icon = "fas fa-scroll", title = TranslateCap('average_offense'), value = 2},
            {icon = "fas fa-scroll", title = TranslateCap('major_offense'),   value = 3}
        }
        ESX.OpenContext("right", elements, function(menu,element)
            local data = {current = element}
            OpenFineCategoryMenu(player, data.current.value)
        end)
    else
        ESX.CloseContext()
        OpenFineTextInput(player)
    end
end

function OpenFineCategoryMenu(player, category)
    if not fineList[category] then
        local p = promise.new()
        ESX.TriggerServerCallback('esx_policejob:getFineList', function(fines)
            p:resolve(fines)
        end, category)
        fineList[category] = Citizen.Await(p)
    end

    local elements = {
        {unselectable = true, icon = "fas fa-scroll", title = TranslateCap('fine')}
    }

    for _,fine in ipairs(fineList[category]) do
        elements[#elements+1] = {
            icon = "fas fa-scroll",
            title     = ('%s <span style="color:green;">%s</span>'):format(fine.label, TranslateCap('armory_item', ESX.Math.GroupDigits(fine.amount))),
            value     = fine.id,
            amount    = fine.amount,
            fineLabel = fine.label
        }
    end

    ESX.OpenContext("right", elements, function(menu,element)
        local data = {current = element}
        if Config.EnablePlayerManagement then
            TriggerServerEvent('esx_billing:sendBill', GetPlayerServerId(player), 'society_police', TranslateCap('fine_total', data.current.fineLabel), data.current.amount)
        else
            TriggerServerEvent('esx_billing:sendBill', GetPlayerServerId(player), '', TranslateCap('fine_total', data.current.fineLabel), data.current.amount)
        end

        ESX.SetTimeout(300, function()
            OpenFineCategoryMenu(player, category)
        end)
    end)
end

function OpenFineTextInput(player)
    Citizen.CreateThread(function()
        local amount = 0
        local reason = ''
        AddTextEntry('FMMC_KEY_TIP1', TranslateCap('fine_enter_amount'))
        Citizen.Wait(0)
        DisplayOnscreenKeyboard(1, 'FMMC_KEY_TIP1', '', '', '', '', '', 30)
        while UpdateOnscreenKeyboard() ~= 1 and UpdateOnscreenKeyboard() ~= 2 do
            Citizen.Wait(0)
        end
        if UpdateOnscreenKeyboard() ~= 2 then
            amount = tonumber(GetOnscreenKeyboardResult())
            if amount == nil or amount <= 0 then
                ESX.ShowNotification(TranslateCap('invalid_amount'))
                return
            end
        end
        AddTextEntry('FMMC_KEY_TIP1', TranslateCap('fine_enter_text'))
        Citizen.Wait(0)
        DisplayOnscreenKeyboard(1, 'FMMC_KEY_TIP1', '', '', '', '', '', 120)
        while UpdateOnscreenKeyboard() ~= 1 and UpdateOnscreenKeyboard() ~= 2 do
            Citizen.Wait(0)
        end
        if UpdateOnscreenKeyboard() ~= 2 then
            reason = GetOnscreenKeyboardResult()
        end
        Citizen.Wait(500)
        TriggerServerEvent('esx_billing:sendBill', GetPlayerServerId(player), 'society_police', reason, amount)
        OpenPoliceActionsMenu()
    end)
end
