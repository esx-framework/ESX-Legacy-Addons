local A = POLICE

function OpenIdentityCardMenu(player)
    ESX.TriggerServerCallback('esx_policejob:getOtherPlayerData', function(data)
        local elements = {
            {icon = "fas fa-user", title = TranslateCap('name', data.name)},
            {icon = "fas fa-user", title = TranslateCap('job', ('%s - %s'):format(data.job, data.grade))}
        }

        if Config.EnableESXIdentity then
            elements[#elements+1] = {icon = "fas fa-user", title = TranslateCap('sex', TranslateCap(data.sex))}
            elements[#elements+1] = {icon = "fas fa-user", title = TranslateCap('dob', data.dob)}
            elements[#elements+1] = {icon = "fas fa-user", title = TranslateCap('height', data.height)}
        end

        if Config.EnableESXOptionalneeds and data.drunk then
            elements[#elements+1] = {icon = "fas fa-wine-bottle", title = TranslateCap('bac', data.drunk)}
        end

        if data.licenses then
            elements[#elements+1] = {unselectable = true, icon = "fas fa-scroll", title = TranslateCap('license_label')}
            for i=1, #data.licenses do
                elements[#elements+1] = {icon = "fas fa-scroll", title = data.licenses[i].label}
            end
        end

        ESX.OpenContext("right", elements, nil, function(menu)
            OpenPoliceActionsMenu()
        end)
    end, GetPlayerServerId(player))
end

function ShowPlayerLicense(player)
    local elements = {
        {unselectable = true, icon = "fas fa-scroll", title = TranslateCap('license_revoke')}
    }

    ESX.TriggerServerCallback('esx_policejob:getOtherPlayerData', function(playerData)
        if playerData.licenses then
            for i=1, #playerData.licenses do
                local lic = playerData.licenses[i]
                if lic.label and lic.type then
                    elements[#elements+1] = {
                        icon = "fas fa-scroll",
                        title = lic.label,
                        type  = lic.type
                    }
                end
            end
        end

        ESX.OpenContext("right", elements, function(menu,element)
            local data = {current = element}
            ESX.ShowNotification(TranslateCap('licence_you_revoked', data.current.title, playerData.name))
            TriggerServerEvent('esx_policejob:message', GetPlayerServerId(player), TranslateCap('license_revoked', data.current.title))
            TriggerServerEvent('esx_license:removeLicense', GetPlayerServerId(player), data.current.type)
            ESX.SetTimeout(300, function()
                ShowPlayerLicense(player)
            end)
        end)
    end, GetPlayerServerId(player))
end

function OpenUnpaidBillsMenu(player)
    local elements = {
        {unselectable = true, icon = "fas fa-scroll", title = TranslateCap('unpaid_bills')}
    }

    ESX.TriggerServerCallback('esx_billing:getTargetBills', function(bills)
        for _,bill in ipairs(bills) do
            elements[#elements+1] = {
                unselectable = true,
                icon = "fas fa-scroll",
                title = ('%s - <span style="color:red;">%s</span>'):format(bill.label, TranslateCap('armory_item', ESX.Math.GroupDigits(bill.amount))),
                billId = bill.id
            }
        end
        ESX.OpenContext("right", elements, nil, nil)
    end, GetPlayerServerId(player))
end

function OpenVehicleInfosMenu(vehicleData)
    ESX.TriggerServerCallback('esx_policejob:getVehicleInfos', function(retrivedInfo)
        local elements = {
            {unselectable = true, icon = "fas fa-car", title = TranslateCap('vehicle_info')},
            {icon = "fas fa-car", title = TranslateCap('plate', retrivedInfo.plate)}
        }
        if not retrivedInfo.owner then
            elements[#elements+1] = {unselectable = true, icon = "fas fa-user", title = TranslateCap('owner_unknown')}
        else
            elements[#elements+1] = {unselectable = true, icon = "fas fa-user", title = TranslateCap('owner', retrivedInfo.owner)}
        end
        ESX.OpenContext("right", elements, nil, nil)
    end, vehicleData.plate)
end

function LookupVehicle(elementF)
    local elements = {
        {unselectable = true, icon = "fas fa-car", title = elementF.title},
        {title = TranslateCap('search_plate'), input = true, inputType = "text", inputPlaceholder = "ABC 123"},
        {icon = "fas fa-check-double", title = TranslateCap('lookup_plate'), value = "lookup"}
    }

    ESX.OpenContext("right", elements, function(menu,element)
        local data = {value = menu.eles[2].inputValue}
        local length = data.value and string.len(data.value) or 0
        if not data.value or length < 2 or length > 8 then
            ESX.ShowNotification(TranslateCap('search_database_error_invalid'))
        else
            ESX.TriggerServerCallback('esx_policejob:getVehicleInfos', function(retrivedInfo)
                local el = {
                    {unselectable = true, icon = "fas fa-car", title = elementF.title},
                    {unselectable = true, icon = "fas fa-car", title = TranslateCap('plate', retrivedInfo.plate)}
                }
                if not retrivedInfo.owner then
                    el[#el+1] = {unselectable = true, icon = "fas fa-user", title = TranslateCap('owner_unknown')}
                else
                    el[#el+1] = {unselectable = true, icon = "fas fa-user", title = TranslateCap('owner', retrivedInfo.owner)}
                end
                ESX.OpenContext("right", el, nil, function()
                    OpenPoliceActionsMenu()
                end)
            end, data.value)
        end
    end)
end
