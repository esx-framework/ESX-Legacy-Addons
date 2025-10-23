do
    local isPickingUp, isProcessing = false, false
    local processPoint = ESX.Point:new({
        coords = Config.CircleZones.WeedProcessing.coords,
        distance = 2,
        enter = function()
            if not isProcessing then
                ESX.TextUI(TranslateCap('weed_processprompt'))
            end
        end,
        leave = function()
            ESX.HideUI()
        end,
        inside = function(self)
            if IsControlJustReleased(0, 38) and not isProcessing then
                ESX.TriggerServerCallback('esx_drugs:cannabis_count', function(xCannabis)
                    if Config.LicenseEnable then
                        ESX.TriggerServerCallback('esx_license:checkLicense', function(hasProcessingLicense)
                            if hasProcessingLicense then
                                ProcessWeed(xCannabis)
                            else
                                OpenBuyLicenseMenu('weed_processing')
                            end
                        end, GetPlayerServerId(PlayerId()), 'weed_processing')
                    else
                        ProcessWeed(xCannabis)
                    end
                end)
            end
        end
    })

    local pickupTextShown = false

    local pickupPoint = ESX.Point:new({
        coords = Config.CircleZones.WeedField.coords,
        distance = 100.0,
        inside = function(self)
            local playerPed = PlayerPedId()
            local coords = GetEntityCoords(playerPed)
            local modelHash = GetHashKey('prop_weed_02')
            local nearbyObject = GetClosestObjectOfType(coords.x, coords.y, coords.z, 10.0, modelHash, false, false, false)
            if DoesEntityExist(nearbyObject) then
                PlaceObjectOnGroundProperly(nearbyObject)
                local plantId = Entity(nearbyObject).state.plantId
                local active = Entity(nearbyObject).state.active
                if plantId and active then
                    local dist = #(coords - GetEntityCoords(nearbyObject))
                    if dist < 1.5 then
                        if not isPickingUp and not pickupTextShown then
                            ESX.TextUI(TranslateCap('weed_pickupprompt'))
                            pickupTextShown = true
                        end
                        if IsControlJustReleased(0, 38) and not isPickingUp then
                            isPickingUp = true
                            ESX.TriggerServerCallback('esx_drugs:canPickUp', function(canPickUp, qty)
                                if canPickUp then
                                    TaskStartScenarioInPlace(playerPed, 'world_human_gardener_plant', 0, false)
                                    Wait(2000)
                                    ClearPedTasks(playerPed)
                                    Wait(1500)
                                    TriggerServerEvent('esx_drugs:pickupWeedPlant', plantId, qty)
                                    if pickupTextShown then
                                        ESX.HideUI()
                                        pickupTextShown = false
                                    end
                                else
                                    ESX.ShowNotification(TranslateCap('weed_inventoryfull'))
                                end
                                isPickingUp = false
                            end, 'cannabis')
                        end
                    else
                        if pickupTextShown then
                            ESX.HideUI()
                            pickupTextShown = false
                        end
                    end
                end
            else
                if pickupTextShown then
                    ESX.HideUI()
                    pickupTextShown = false
                end
            end
        end,
        leave = function()
            if pickupTextShown then
                ESX.HideUI()
                pickupTextShown = false
            end
        end
    })
    
    function ProcessWeed(xCannabis)
        isProcessing = true
        ESX.ShowNotification(TranslateCap('weed_processingstarted'))
        TriggerServerEvent('esx_drugs:processCannabis')
        if xCannabis <= 3 then
            xCannabis = 0
        end
        local timeLeft = (Config.Delays.WeedProcessing * xCannabis) / 1000
        local playerPed = PlayerPedId()
        while timeLeft > 0 do
            Wait(1000)
            timeLeft = timeLeft - 1
            if #(GetEntityCoords(playerPed) - Config.CircleZones.WeedProcessing.coords) > 4 then
                ESX.ShowNotification(TranslateCap('weed_processingtoofar'))
                TriggerServerEvent('esx_drugs:cancelProcessing')
                TriggerServerEvent('esx_drugs:outofbound')
                break
            end
        end
        isProcessing = false
    end
end
