local spawnedVehicles = spawnedVehicles or {}
isInShopMenu = isInShopMenu or false

local function safeGetJobGrade()
    return (ESX and ESX.PlayerData and ESX.PlayerData.job and ESX.PlayerData.job.grade_name) or 'recruit'
end

local function modelToLabel(model)
    local display = GetDisplayNameFromVehicleModel(model)
    local label = (display and display ~= '' and GetLabelText(display)) or tostring(model)
    if not label or label == 'NULL' then label = tostring(model) end
    return label
end

local function ensureModelLoaded(modelHash, spinnerText)
    modelHash = (type(modelHash) == 'number' and modelHash or joaat(modelHash))
    if HasModelLoaded(modelHash) then return true end

    RequestModel(modelHash)

    BeginTextCommandBusyspinnerOn('STRING')
    AddTextComponentSubstringPlayerName(spinnerText or TranslateCap('vehicleshop_awaiting_model'))
    EndTextCommandBusyspinnerOn(4)

    local tries = 0
    while not HasModelLoaded(modelHash) do
        Wait(0)
        DisableAllControlActions(0)
        tries = tries + 1
        if tries > 1000 then
            break
        end
    end

    BusyspinnerOff()
    return HasModelLoaded(modelHash)
end

local function safeInsideShopCoords(station, part, partNum)
    local cfg = Config.PoliceStations[station][part][partNum]
    local shop = cfg.InsideShop
    if shop and shop.x then
        local heading = shop.w or 0.0
        return vector3(shop.x, shop.y, shop.z), heading
    end
    if type(shop) == 'vector4' then
        return vector3(shop.x, shop.y, shop.z), shop.w
    elseif type(shop) == 'vector3' then
        return shop, 0.0
    end
    local sp = cfg.SpawnPoints and cfg.SpawnPoints[1]
    if sp then return sp.coords, (sp.heading or 0.0) end
    return GetEntityCoords(PlayerPedId()), 0.0
end

local function getAuthorizedVehiclesFor(typeKey, grade)
    local byType = Config.AuthorizedVehicles and Config.AuthorizedVehicles[typeKey]
    if not byType then return {} end
    return byType[grade] or {}
end

local function tryGeneratePlateFallback()
    local plate = ('%s%03d%s'):format(string.char(math.random(65,90), math.random(65,90)),
        math.random(0,999),
        string.char(math.random(65,90), math.random(65,90)))
    return ESX and ESX.Math and ESX.Math.Trim and ESX.Math.Trim(plate:upper()) or plate:upper()
end

local function deleteSpawnedPreview()
    while #spawnedVehicles > 0 do
        local veh = spawnedVehicles[1]
        ESX.Game.DeleteVehicle(veh)
        table.remove(spawnedVehicles, 1)
    end
end

local function getAvailableSpawnPoint(station, part, partNum)
    local spawnPoints = (Config.PoliceStations[station] and Config.PoliceStations[station][part]
        and Config.PoliceStations[station][part][partNum]
        and Config.PoliceStations[station][part][partNum].SpawnPoints) or {}

    for i=1, #spawnPoints do
        local sp = spawnPoints[i]
        if ESX.Game.IsSpawnPointClear(sp.coords, sp.radius) then
            return true, sp
        end
    end

    ESX.ShowNotification(TranslateCap('vehicle_blocked'))
    return false
end

function OpenVehicleSpawnerMenu(typeKey, station, part, partNum)
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)

    local menuEls = {
        {unselectable = true, icon = "fas fa-car", title = TranslateCap('garage_title')},
        {icon = "fas fa-car", title = TranslateCap('garage_storeditem'), action = 'garage'},
        {icon = "fas fa-car", title = TranslateCap('garage_storeitem'), action = 'store_garage'},
        {icon = "fas fa-car", title = TranslateCap('garage_buyitem'),   action = 'buy_vehicle'}
    }

    ESX.OpenContext("right", menuEls, function(_, element)
        if element.action == "buy_vehicle" then
            local grade = safeGetJobGrade()
            local auth = getAuthorizedVehiclesFor(typeKey, grade)
            local shopElements = {}

            if auth and #auth > 0 then
                for _, vehicle in ipairs(auth) do
                    if vehicle.model and IsModelInCdimage(joaat(vehicle.model)) then
                        local label = modelToLabel(joaat(vehicle.model))
                        shopElements[#shopElements+1] = {
                            icon  = 'fas fa-car',
                            title = ('%s - <span style="color:green;">%s</span>')
                                :format(label, TranslateCap('shop_item', ESX.Math.GroupDigits(vehicle.price))),
                            name  = label,
                            model = vehicle.model,
                            price = vehicle.price or 0,
                            props = vehicle.props,
                            type  = typeKey
                        }
                    end
                end
            end

            if #shopElements > 0 then
                local shopPos, _ = safeInsideShopCoords(station, part, partNum)
                OpenShopMenu(shopElements, playerCoords, shopPos, station, part, partNum)
            else
                ESX.ShowNotification(TranslateCap('garage_notauthorized'))
            end

        elseif element.action == "garage" then
            local list = {
                {unselectable = true, icon = "fas fa-car", title = "Garage"}
            }

            ESX.TriggerServerCallback('esx_vehicleshop:retrieveJobVehicles', function(jobVehicles)
                if jobVehicles and #jobVehicles > 0 then
                    local allPropsByPlate = {}

                    for _, v in ipairs(jobVehicles) do
                        local props = v.vehicle and json.decode(v.vehicle)
                        if props and props.model and IsModelInCdimage(props.model) then
                            local label = modelToLabel(props.model)
                            local part1 = ('%s - <span style="color:darkgoldenrod;">%s</span>: '):format(label, props.plate)
                            local stored = (v.stored == 1 or v.stored == true)
                            local part2 = stored and
                                ('<span style="color:green;">%s</span>'):format(TranslateCap('garage_stored')) or
                                ('<span style="color:darkred;">%s</span>'):format(TranslateCap('garage_notstored'))

                            list[#list+1] = {
                                icon   = 'fas fa-car',
                                title  = part1 .. part2,
                                stored = stored,
                                model  = props.model,
                                plate  = props.plate
                            }
                            allPropsByPlate[props.plate] = props
                        end
                    end

                    if #list > 1 then
                        ESX.OpenContext("right", list, function(_, elementG)
                            if elementG.stored then
                                local ok, sp = getAvailableSpawnPoint(station, part, partNum)
                                if ok then
                                    ESX.CloseContext()
                                    ESX.Game.SpawnVehicle(elementG.model, sp.coords, sp.heading or 0.0, function(vehicle)
                                        local props = allPropsByPlate[elementG.plate]
                                        if props then ESX.Game.SetVehicleProperties(vehicle, props) end
                                        SetVehicleOnGroundProperly(vehicle)
                                        SetVehicleEngineOn(vehicle, true, true, false)
                                        TriggerServerEvent('esx_vehicleshop:setJobVehicleState', elementG.plate, false)
                                        ESX.ShowNotification(TranslateCap('garage_released'))
                                    end)
                                end
                            else
                                ESX.ShowNotification(TranslateCap('garage_notavailable'))
                            end
                        end)
                    else
                        ESX.ShowNotification(TranslateCap('garage_empty'))
                    end
                else
                    ESX.ShowNotification(TranslateCap('garage_empty'))
                end
            end, typeKey)

        elseif element.action == "store_garage" then
            StoreNearbyVehicle(playerCoords)
        end
    end)
end

function StoreNearbyVehicle(playerCoords)
    local vehicles, plates, index = ESX.Game.GetVehiclesInArea(playerCoords, 30.0), {}, {}

    if not vehicles or #vehicles == 0 then
        ESX.ShowNotification(TranslateCap('garage_store_nearby'))
        return
    end

    for i=1, #vehicles do
        local veh = vehicles[i]
        if GetVehicleNumberOfPassengers(veh) == 0 and IsVehicleSeatFree(veh, -1) then
            local plate = ESX.Math.Trim(GetVehicleNumberPlateText(veh))
            plates[#plates+1] = plate
            index[plate] = veh
        end
    end

    ESX.TriggerServerCallback('esx_policejob:storeNearbyVehicle', function(plate)
        if plate then
            local vehicleId = index[plate]
            local attempts = 0
            ESX.Game.DeleteVehicle(vehicleId)
            local isBusy = true

            CreateThread(function()
                BeginTextCommandBusyspinnerOn('STRING')
                AddTextComponentSubstringPlayerName(TranslateCap('garage_storing'))
                EndTextCommandBusyspinnerOn(4)
                while isBusy do Wait(100) end
                BusyspinnerOff()
            end)

            while DoesEntityExist(vehicleId) do
                Wait(500)
                attempts = attempts + 1
                if attempts > 30 then break end

                local around = ESX.Game.GetVehiclesInArea(playerCoords, 30.0)
                for i=1, #around do
                    local veh = around[i]
                    if ESX.Math.Trim(GetVehicleNumberPlateText(veh)) == plate then
                        ESX.Game.DeleteVehicle(veh)
                        break
                    end
                end
            end

            isBusy = false
            ESX.ShowNotification(TranslateCap('garage_has_stored'))
        else
            ESX.ShowNotification(TranslateCap('garage_has_notstored'))
        end
    end, plates)
end

function OpenShopMenu(elements, restoreCoords, shopCoords, station, part, partNum)
    local playerPed = PlayerPedId()
    isInShopMenu = true

    ESX.OpenContext("right", elements, function(_, element)
        local actions = {
            {unselectable = true, icon = "fas fa-car", title = element.title},
            {icon = "fas fa-eye", title = TranslateCap('view'), value = "view"}
        }

        ESX.OpenContext("right", actions, function(_, element2)
            if element2.value ~= "view" then return end

            deleteSpawnedPreview()
            SetEntityCoordsNoOffset(playerPed, shopCoords.x, shopCoords.y, shopCoords.z, false, false, false)
            SetEntityHeading(playerPed, 0.0)
            FreezeEntityPosition(playerPed, true)
            SetEntityVisible(playerPed, false, false)

            if not ensureModelLoaded(element.model, TranslateCap('vehicleshop_awaiting_model')) then
                FreezeEntityPosition(playerPed, false)
                SetEntityVisible(playerPed, true, false)
                ESX.ShowNotification(TranslateCap('garage_notauthorized'))
                return
            end

            ESX.Game.SpawnLocalVehicle(element.model, shopCoords, 0.0, function(vehicle)
                table.insert(spawnedVehicles, vehicle)
                SetModelAsNoLongerNeeded(joaat(element.model))
                if element.props then
                    ESX.Game.SetVehicleProperties(vehicle, element.props)
                end
                SetVehicleOnGroundProperly(vehicle)
                FreezeEntityPosition(vehicle, true)
                TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
            end)

            local confirm = {
                {unselectable = true, icon = "fas fa-car", title = element.title},
                {icon = "fas fa-check-double", title = TranslateCap('buy_car'),  value = "buy"},
                {icon = "fas fa-eye",          title = TranslateCap('stop_view'), value = "stop"}
            }

            ESX.OpenContext("right", confirm, function(_, choose)
                if choose.value == 'stop' then
                    isInShopMenu = false
                    ESX.CloseContext()
                    deleteSpawnedPreview()
                    FreezeEntityPosition(playerPed, false)
                    SetEntityVisible(playerPed, true, false)
                    ESX.Game.Teleport(playerPed, restoreCoords)

                elseif choose.value == "buy" then
                    local newPlate
                    if exports and exports['esx_vehicleshop'] and exports['esx_vehicleshop'].GeneratePlate then
                        newPlate = exports['esx_vehicleshop']:GeneratePlate()
                    else
                        newPlate = tryGeneratePlateFallback()
                    end

                    local vehicle  = GetVehiclePedIsIn(playerPed, false)
                    local props    = ESX.Game.GetVehicleProperties(vehicle)
                    props.plate    = newPlate

                    ESX.TriggerServerCallback('esx_policejob:buyJobVehicle', function (bought)
                        if bought then
                            ESX.ShowNotification(TranslateCap('vehicleshop_bought', element.name, ESX.Math.GroupDigits(element.price)))
                            isInShopMenu = false
                            ESX.CloseContext()
                            deleteSpawnedPreview()
                            FreezeEntityPosition(playerPed, false)
                            SetEntityVisible(playerPed, true, false)
                            ESX.Game.Teleport(playerPed, restoreCoords)
                        else
                            ESX.ShowNotification(TranslateCap('vehicleshop_money'))
                            ESX.CloseContext()
                        end
                    end, props, element.type)
                end
            end, function()
                isInShopMenu = false
                ESX.CloseContext()
                deleteSpawnedPreview()
                FreezeEntityPosition(playerPed, false)
                SetEntityVisible(playerPed, true, false)
                ESX.Game.Teleport(playerPed, restoreCoords)
            end)
        end)
    end)
end

CreateThread(function()
    while true do
        if isInShopMenu then
            DisableControlAction(0, 75, true)   -- Exit vehicle
            DisableControlAction(27, 75, true)
            DisableControlAction(0, 63, true)   -- Turn left
            DisableControlAction(0, 64, true)   -- Turn right
            DisableControlAction(0, 71, true)   -- Forward
            DisableControlAction(0, 72, true)   -- Backward
            DisableControlAction(0, 69, true)   -- Attack
            DisableControlAction(0, 70, true)
            Wait(0)
        else
            Wait(400)
        end
    end
end)
