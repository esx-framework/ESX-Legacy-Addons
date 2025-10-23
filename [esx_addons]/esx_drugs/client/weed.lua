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

            if not DoesEntityExist(nearbyObject) then
                ESX.HideUI()
                pickupTextShown = false
                return
            end

            PlaceObjectOnGroundProperly(nearbyObject)

            local entity = Entity(nearbyObject)
            local plantId, active = entity.state.plantId, entity.state.active

            if not plantId or not active then
                ESX.HideUI()
                pickupTextShown = false
                return
            end

            local dist = #(coords - GetEntityCoords(nearbyObject))

            if dist >= 1.5 then
                ESX.HideUI()
                pickupTextShown = false
                return
            end

            if not isPickingUp and not pickupTextShown then
                ESX.TextUI(TranslateCap('weed_pickupprompt'))
                pickupTextShown = true
            end

            if not IsControlJustReleased(0, 38) or isPickingUp then
                return
            end

            isPickingUp = true
            ESX.TriggerServerCallback('esx_drugs:canPickUp', function(canPickUp, qty)
                if not canPickUp then
                    ESX.ShowNotification(TranslateCap('weed_inventoryfull'))
                    isPickingUp = false
                    return
                end

                TaskStartScenarioInPlace(playerPed, 'world_human_gardener_plant', 0, false)
                Wait(2000)
                ClearPedTasks(playerPed)
                Wait(1500)

                TriggerServerEvent('esx_drugs:pickupWeedPlant', plantId, qty)
                ESX.HideUI()
                pickupTextShown = false
                isPickingUp = false
            end, 'cannabis')
        end,

        leave = function()
            ESX.HideUI()
            pickupTextShown = false
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