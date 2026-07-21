---@diagnostic disable: undefined-global
local ESX = exports['es_extended']:getSharedObject()
local isShopUiOpen = false

local function setShopUiVisible(visible)
    isShopUiOpen = visible
    SetNuiFocus(visible, visible)
    SendNUIMessage({ action = visible and 'show' or 'hide' })
end

local function openShopUi()
    if isShopUiOpen then return end
    setShopUiVisible(true)
end

local function closeShopUi()
    if not isShopUiOpen then return end
    setShopUiVisible(false)
end

RegisterNUICallback('close', function(_, cb)
    closeShopUi()
    if cb then cb({}) end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    SetNuiFocus(false, false)
end)


RegisterNUICallback('getShopData', function(_, cb)
    cb({
        categories = Config.Categories or {},
        items = Config.Items or {}
    })
end)

RegisterNUICallback('purchase', function(data, cb)
    local payload = data or {}
    ESX.TriggerServerCallback('esx_shops:purchase', function(success, message)
        cb({ success = success, message = message })
        if success then
            ESX.ShowNotification(message)
        else
            ESX.ShowNotification(message)
        end
    end, payload)
end)

---@param label any
local function showHelpText(label)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandDisplayHelp(0, false, true, 1)
end

CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local nearby = false
        local inInteractRange = false

        for _, loc in ipairs(Config.Locations or {}) do
            local coords = loc.coords
            local distance = #(playerCoords - coords)
            if distance < 20.0 then
                nearby = true
                if loc.marker ~= false then
                    DrawMarker(
                        2,
                        coords.x, coords.y, coords.z,
                        0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        0.2, 0.2, 0.2,
                        204, 153, 0, 200,
                        false, true, 2, true, nil, nil, false
                    )
                end
                if distance < 1.8 then
                    inInteractRange = true
                    if not isShopUiOpen then
                        local helpText = 'Press ~INPUT_CONTEXT~ to open shop'
                        if type(_U) == 'function' then
                            local translated = _U('open_shop_help')
                            if type(translated) == 'string' and translated ~= '' then
                                helpText = translated
                            end
                        end
                        showHelpText(helpText)
                    end
                    if IsControlJustPressed(0, 38) then -- INPUT_PICKUP (E)
                        openShopUi()
                    end
                end
            end
        end

        if nearby then
            Wait(0)
        else
            Wait(500)
        end
    end
end)
