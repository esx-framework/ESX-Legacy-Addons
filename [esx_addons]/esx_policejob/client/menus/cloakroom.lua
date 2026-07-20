local A = POLICE

function OpenCloakroomMenu()
    local playerPed = PlayerPedId()
    local grade = ESX.PlayerData.job.grade_name

    local elements = {
        {unselectable = true, icon = "fas fa-shirt", title = TranslateCap("cloakroom")},
        {icon = "fas fa-shirt", title = TranslateCap('citizen_wear'), value = 'citizen_wear'},
        {icon = "fas fa-shirt", title = TranslateCap('bullet_wear'), uniform = 'bullet_wear'},
        {icon = "fas fa-shirt", title = TranslateCap('gilet_wear'), uniform = 'gilet_wear'},
        {icon = "fas fa-shirt", title = TranslateCap('police_wear'), uniform = grade}
    }

    if Config.EnableCustomPeds then
        if Config.CustomPeds and Config.CustomPeds.shared then
            for _,v in ipairs(Config.CustomPeds.shared) do
                elements[#elements+1] = {
                    icon = "fas fa-shirt",
                    title = v.label,
                    value = 'freemode_ped',
                    maleModel = v.maleModel,
                    femaleModel = v.femaleModel
                }
            end
        end
        if Config.CustomPeds and Config.CustomPeds[grade] then
            for _,v in ipairs(Config.CustomPeds[grade]) do
                elements[#elements+1] = {
                    icon = "fas fa-shirt",
                    title = v.label,
                    value = 'freemode_ped',
                    maleModel = v.maleModel,
                    femaleModel = v.femaleModel
                }
            end
        end
    end

    ESX.OpenContext("right", elements, function(menu,element)
        POLICE.cleanPlayer(playerPed)
        local data = {current = element}

        if data.current.value == 'citizen_wear' then
            if Config.EnableCustomPeds then
                ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
                    local isMale = skin.sex == 0
                    TriggerEvent('skinchanger:loadDefaultModel', isMale, function()
                        ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin2)
                            TriggerEvent('skinchanger:loadSkin', skin2)
                            TriggerEvent('esx:restoreLoadout')
                        end)
                    end)
                end)
            else
                ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
                    TriggerEvent('skinchanger:loadSkin', skin)
                end)
            end

            if Config.EnableESXService then
                ESX.TriggerServerCallback('esx_service:isInService', function(isInService)
                    if isInService then
                        POLICE.playerInService = false
                        local notification = {
                            title    = TranslateCap('service_anonunce'),
                            subject  = '',
                            msg      = TranslateCap('service_out_announce', GetPlayerName(PlayerId())),
                            iconType = 1
                        }
                        TriggerServerEvent('esx_service:notifyAllInService', notification, 'police')
                        TriggerServerEvent('esx_service:disableService', 'police')
                        ESX.ShowNotification(TranslateCap('service_out'))
                    end
                end, 'police')
            end
        end

        if Config.EnableESXService and data.current.value ~= 'citizen_wear' then
            local awaitService
            ESX.TriggerServerCallback('esx_service:isInService', function(isInService)
                if not isInService then
                    if Config.MaxInService ~= -1 then
                        ESX.TriggerServerCallback('esx_service:enableService', function(canTakeService, maxInService, inServiceCount)
                            if not canTakeService then
                                ESX.ShowNotification(TranslateCap('service_max', inServiceCount, maxInService))
                            else
                                awaitService = true
                                POLICE.playerInService = true
                                local notification = {
                                    title    = TranslateCap('service_anonunce'),
                                    subject  = '',
                                    msg      = TranslateCap('service_in_announce', GetPlayerName(PlayerId())),
                                    iconType = 1
                                }
                                TriggerServerEvent('esx_service:notifyAllInService', notification, 'police')
                                ESX.ShowNotification(TranslateCap('service_in'))
                            end
                        end, 'police')
                    else
                        awaitService = true
                        POLICE.playerInService = true
                        local notification = {
                            title    = TranslateCap('service_anonunce'),
                            subject  = '',
                            msg      = TranslateCap('service_in_announce', GetPlayerName(PlayerId())),
                            iconType = 1
                        }
                        TriggerServerEvent('esx_service:notifyAllInService', notification, 'police')
                        ESX.ShowNotification(TranslateCap('service_in'))
                    end
                else
                    awaitService = true
                end
            end, 'police')

            while awaitService == nil do Wait(0) end
            if not awaitService then return end
        end

        if data.current.uniform then
            POLICE.setUniform(data.current.uniform, playerPed)
        elseif data.current.value == 'freemode_ped' then
            ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
                local modelHash = skin.sex == 0 and joaat(data.current.maleModel) or joaat(data.current.femaleModel)
                ESX.Streaming.RequestModel(modelHash, function()
                    SetPlayerModel(PlayerId(), modelHash)
                    SetModelAsNoLongerNeeded(modelHash)
                    SetPedDefaultComponentVariation(PlayerPedId())
                    TriggerEvent('esx:restoreLoadout')
                end)
            end)
        end
    end, function(menu)
        POLICE.CurrentAction     = 'menu_cloakroom'
        POLICE.CurrentActionMsg  = TranslateCap('open_cloackroom')
        POLICE.CurrentActionData = {}
    end)
end
