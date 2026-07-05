AdminOpen = false
AdminMode = nil

local function getCallbackError(res, fallback)
    if not res then
        return fallback or "No response from server."
    end

    return res.err or res.error or fallback or "Action failed."
end

local function respondFailure(cb, label, res, fallback)
    local err = getCallbackError(res, fallback)
    print(label, err)

    cb({
        success = false,
        err = err,
        playerOnline = res and res.playerOnline,
    })
end

local function sendQuickMenuState(action, active, value)
    SendNUIMessage({
        action = "adminMenuState",
        data = {
            action = action,
            active = active == true,
            value = value,
        },
    })
end

local function closeAdminUi()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    AdminOpen = false
    AdminMode = nil
    SendNUIMessage({ action = "closeAdmin" })

    CreateThread(function()
        Wait(0)
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end)
end

local function applyAdminFocus(mode)
    AdminOpen = true
    AdminMode = mode

    if mode == "dashboard" then
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
        return
    end

    SetNuiFocus(true, false)
    SetNuiFocusKeepInput(true)
end

function ToggleNUIFocus(bool, mode)
    if not bool then
        closeAdminUi()
        return
    end

    applyAdminFocus(mode or "dashboard")
end

local function notifyClientError(err)
    if ESX and ESX.ShowNotification then
        ESX.ShowNotification(err or "Action failed.", "error")
    end
end

local function openDashboard(cb)
    ESX.TriggerServerCallback("esx-adminmenu:server:openDashboard", function(res)
        if not res or not res.success then
            local err = getCallbackError(res, "You do not have permission to open the admin dashboard.")
            notifyClientError(err)

            if cb then
                cb({ success = false, err = err })
            end
            return
        end

        ToggleNUIFocus(true, "dashboard")
        SendNUIMessage({
            action = "openAdminDashboard",
            data = {
                players = res.players or {},
                serverData = res.serverData,
            },
        })

        if cb then
            cb({ success = true })
        end
    end)
end

local function openAdminMenu(cb)
    ESX.TriggerServerCallback("esx-adminmenu:server:canOpen", function(res)
        if not res or not res.success then
            local err = getCallbackError(res, "You do not have permission to open the admin menu.")
            notifyClientError(err)

            if cb then
                cb({ success = false, err = err })
            end
            return
        end

        ToggleNUIFocus(true, "menu")
        SendNUIMessage({
            action = "openAdminMenu",
            data = {
                serverData = res.serverData,
            },
        })

        if cb then
            cb({ success = true })
        end
    end)
end

local function pushServerData()
    if not AdminOpen then
        return
    end

    ESX.TriggerServerCallback("esx-adminmenu:server:canOpen", function(res)
        if not res or not res.success then
            return
        end

        SendNUIMessage({
            action = "updateServerData",
            data = res.serverData,
        })
    end)
end

local function checkAdminAction(action, cb)
    ESX.TriggerServerCallback("esx-adminmenu:server:canUseAdminAction", cb, { action = action })
end

local function runProtectedClientAction(cb, label, action, permissionAction)
    if not permissionAction then
        cb({ success = false, err = "Missing admin action permission." })
        return
    end

    checkAdminAction(permissionAction, function(res)
        if not res or not res.success then
            respondFailure(cb, label, res)
            return
        end

        local ok, success, err, extra = pcall(action)
        if not ok then
            cb({ success = false, err = success })
            return
        end

        if not success then
            cb({ success = false, err = err or "Action failed." })
            return
        end

        extra = extra or {}
        extra.success = true
        cb(extra)
    end)
end

function OpenAdminDashboard()
    openDashboard()
end

function OpenAdminMenu()
    openAdminMenu()
end

RegisterCommand("adminmenu", function()
    OpenAdminMenu()
end, false)

RegisterCommand("admindashboard", function()
    OpenAdminDashboard()
end, false)

local function runAdminCommandAction(action, handler)
    checkAdminAction(action, function(res)
        if not res or not res.success then
            notifyClientError(getCallbackError(res, "You do not have permission to use this command."))
            return
        end

        local active = handler()
        sendQuickMenuState(action, active)

        if action == "noclip" and ClientActions.IsInvisibleActive then
            sendQuickMenuState("invisible", ClientActions.IsInvisibleActive())
        end
    end)
end

RegisterCommand("noclip", function()
    runAdminCommandAction("noclip", ClientActions.ToggleNoClip)
end, false)

RegisterCommand("names", function()
    runAdminCommandAction("names", ClientActions.ToggleNames)
end, false)

RegisterCommand("blips", function()
    runAdminCommandAction("blips", ClientActions.ToggleBlips)
end, false)

RegisterKeyMapping("adminmenu", "Open Admin Menu", "keyboard", Config.Keybinds.AdminMenu)
RegisterKeyMapping("admindashboard", "Open Admin Dashboard", "keyboard", Config.Keybinds.AdminDashboard)

RegisterNUICallback("openDashboard", function(data, cb)
    openDashboard(cb)
end)

RegisterNUICallback("openAdminMenu", function(data, cb)
    openAdminMenu(cb)
end)

RegisterNUICallback("adminMenu:noclip", function(data, cb)
    runProtectedClientAction(cb, "[esx-adminmenu:noclip]", function()
        local active = ClientActions.ToggleNoClip()
        sendQuickMenuState("noclip", active)
        if ClientActions.IsInvisibleActive then
            sendQuickMenuState("invisible", ClientActions.IsInvisibleActive())
        end
        return true, nil, { active = active }
    end, "noclip")
end)

RegisterNUICallback("adminMenu:names", function(data, cb)
    runProtectedClientAction(cb, "[esx-adminmenu:names]", function()
        local active = ClientActions.ToggleNames()
        sendQuickMenuState("names", active)
        return true, nil, { active = active }
    end, "names")
end)

RegisterNUICallback("adminMenu:blips", function(data, cb)
    runProtectedClientAction(cb, "[esx-adminmenu:blips]", function()
        local active = ClientActions.ToggleBlips()
        sendQuickMenuState("blips", active)
        return true, nil, { active = active }
    end, "blips")
end)

RegisterNUICallback("adminMenu:godmode", function(data, cb)
    runProtectedClientAction(cb, "[esx-adminmenu:godmode]", function()
        local active = ClientActions.ToggleGodmode()
        sendQuickMenuState("godmode", active)
        return true, nil, { active = active }
    end, "godmode")
end)

RegisterNUICallback("adminMenu:invisible", function(data, cb)
    runProtectedClientAction(cb, "[esx-adminmenu:invisible]", function()
        local active = ClientActions.ToggleInvisible()
        sendQuickMenuState("invisible", active)
        return true, nil, { active = active }
    end, "invisible")
end)

RegisterNUICallback("adminMenu:infiniteAmmo", function(data, cb)
    runProtectedClientAction(cb, "[esx-adminmenu:infiniteAmmo]", function()
        local active = ClientActions.ToggleInfiniteAmmo()
        sendQuickMenuState("infiniteAmmo", active)
        return true, nil, { active = active }
    end, "infiniteAmmo")
end)

RegisterNUICallback("adminMenu:revive", function(data, cb)
    ESX.TriggerServerCallback("esx-adminmenu:server:selfAction", function(res)
        if not res or not res.success then
            respondFailure(cb, "[esx-adminmenu:revive]", res)
            return
        end

        cb({ success = true })
    end, { action = "revive" })
end)

RegisterNUICallback("adminMenu:heal", function(data, cb)
    runProtectedClientAction(cb, "[esx-adminmenu:heal]", ClientActions.Heal, "heal")
end)

RegisterNUICallback("adminMenu:armor", function(data, cb)
    runProtectedClientAction(cb, "[esx-adminmenu:armor]", function()
        return ClientActions.SetArmor(100)
    end, "armor")
end)

RegisterNUICallback("adminMenu:repairVehicle", function(data, cb)
    runProtectedClientAction(cb, "[esx-adminmenu:repairVehicle]", ClientActions.RepairVehicle, "repairVehicle")
end)

RegisterNUICallback("adminMenu:cleanVehicle", function(data, cb)
    runProtectedClientAction(cb, "[esx-adminmenu:cleanVehicle]", ClientActions.CleanVehicle, "cleanVehicle")
end)

RegisterNUICallback("adminMenu:deleteVehicle", function(data, cb)
    runProtectedClientAction(cb, "[esx-adminmenu:deleteVehicle]", ClientActions.DeleteVehicle, "deleteVehicle")
end)

RegisterNUICallback("adminMenu:waypoint", function(data, cb)
    runProtectedClientAction(cb, "[esx-adminmenu:waypoint]", ClientActions.TeleportToWaypoint, "waypoint")
end)

RegisterNUICallback("adminMenu:spawnVehicle", function(data, cb)
    runProtectedClientAction(cb, "[esx-adminmenu:spawnVehicle]", function()
        return ClientActions.SpawnVehicle(data or {})
    end, "spawnVehicle")
end)

RegisterNUICallback("adminMenu:flipVehicle", function(data, cb)
    runProtectedClientAction(cb, "[esx-adminmenu:flipVehicle]", ClientActions.FlipVehicle, "flipVehicle")
end)

RegisterNUICallback("adminMenu:setVehiclePerformance", function(data, cb)
    runProtectedClientAction(cb, "[esx-adminmenu:setVehiclePerformance]", function()
        local success, err, extra = ClientActions.SetVehiclePerformance(data or {})
        if success then
            sendQuickMenuState("engineLevel", true,
                data and data.engineLevel and (tostring(data.engineLevel) .. "/5") or nil)
            sendQuickMenuState("brakeLevel", true,
                data and data.brakeLevel and (tostring(data.brakeLevel) .. "/5") or nil)
        end

        return success, err, extra
    end, "customizeVehicle")
end)

RegisterNUICallback("adminMenu:customizeVehicle", function(data, cb)
    runProtectedClientAction(cb, "[esx-adminmenu:customizeVehicle]", function()
        return ClientActions.CustomizeVehicle(data or {})
    end, "customizeVehicle")
end)

RegisterNUICallback("adminMenu:cycleVehicleEngine", function(data, cb)
    runProtectedClientAction(cb, "[esx-adminmenu:cycleVehicleEngine]", function()
        local success, err, extra = ClientActions.CycleVehicleEngine()
        if success then
            sendQuickMenuState("engineLevel", extra and extra.active or true, extra and extra.value)
        end
        return success, err, extra
    end, "engineLevel")
end)

RegisterNUICallback("adminMenu:cycleVehicleBrakes", function(data, cb)
    runProtectedClientAction(cb, "[esx-adminmenu:cycleVehicleBrakes]", function()
        local success, err, extra = ClientActions.CycleVehicleBrakes()
        if success then
            sendQuickMenuState("brakeLevel", extra and extra.active or true, extra and extra.value)
        end
        return success, err, extra
    end, "brakeLevel")
end)

RegisterNUICallback("adminMenu:cycleVehicleTransmission", function(data, cb)
    runProtectedClientAction(cb, "[esx-adminmenu:cycleVehicleTransmission]", function()
        return ClientActions.CycleVehicleTransmission()
    end, "transmissionLevel")
end)

RegisterNUICallback("adminMenu:cycleVehicleSuspension", function(data, cb)
    runProtectedClientAction(cb, "[esx-adminmenu:cycleVehicleSuspension]", function()
        return ClientActions.CycleVehicleSuspension()
    end, "suspensionLevel")
end)

RegisterNUICallback("adminMenu:cycleVehicleArmor", function(data, cb)
    runProtectedClientAction(cb, "[esx-adminmenu:cycleVehicleArmor]", function()
        return ClientActions.CycleVehicleArmor()
    end, "armorLevel")
end)

RegisterNUICallback("adminMenu:cycleVehicleColor", function(data, cb)
    runProtectedClientAction(cb, "[esx-adminmenu:cycleVehicleColor]", function()
        local success, err, extra = ClientActions.CycleVehicleColor()
        if success then
            sendQuickMenuState("colorCycle", extra and extra.active or true, extra and extra.value)
        end
        return success, err, extra
    end, "colorCycle")
end)

RegisterNUICallback("adminMenu:cycleVehicleNeonColor", function(data, cb)
    runProtectedClientAction(cb, "[esx-adminmenu:cycleVehicleNeonColor]", function()
        return ClientActions.CycleVehicleNeonColor()
    end, "neonColorCycle")
end)

RegisterNUICallback("adminMenu:maxVehiclePerformance", function(data, cb)
    runProtectedClientAction(cb, "[esx-adminmenu:maxVehiclePerformance]", function()
        local success, err, extra = ClientActions.MaxVehiclePerformance()
        if success then
            sendQuickMenuState("maxPerformance", extra and extra.active or true, extra and extra.value)
        end
        return success, err, extra
    end, "maxPerformance")
end)

RegisterNUICallback("adminMenu:copyCoords", function(data, cb)
    runProtectedClientAction(cb, "[esx-adminmenu:copyCoords]", ClientActions.CopyCoords, "copyCoords")
end)

RegisterNUICallback("server:action", function(data, cb)
    ESX.TriggerServerCallback("esx-adminmenu:server:serverAction", function(res)
        if not res or res.err then
            respondFailure(cb, "[esx-adminmenu:serverAction]", res)
            return
        end

        cb({ success = res.success, serverData = res.serverData })
    end, data)
end)

RegisterNUICallback("server:radioPlayers", function(data, cb)
    ESX.TriggerServerCallback("esx-adminmenu:server:getRadioChannelPlayers", function(res)
        if not res or res.err then
            respondFailure(cb, "[esx-adminmenu:radioPlayers]", res)
            return
        end

        cb({ success = true, players = res.players or {} })
    end, data)
end)

RegisterNUICallback("player:action", function(data, cb)
    ESX.TriggerServerCallback("esx-adminmenu:server:playerAction", function(res)
        if not res or res.err then
            respondFailure(cb, "[esx-adminmenu:playerAction]", res)
            return
        end

        cb({ success = res.success, playerOnline = res.playerOnline })
    end, data)
end)

RegisterNUICallback("goto", function(data, cb)
    ESX.TriggerServerCallback("esx-adminmenu:server:goto", function(res)
        if not res or res.err then
            respondFailure(cb, "[esx-adminmenu:goto]", res)
            return
        end

        cb({ success = res.success, playerOnline = res.playerOnline })
    end, data)
end)

RegisterNUICallback("bring", function(data, cb)
    ESX.TriggerServerCallback("esx-adminmenu:server:bring", function(res)
        if not res or res.err then
            respondFailure(cb, "[esx-adminmenu:bring]", res)
            return
        end

        cb({ success = res.success, playerOnline = res.playerOnline })
    end, data)
end)

RegisterNUICallback("spectate", function(data, cb)
    ESX.TriggerServerCallback("esx-adminmenu:server:spectate", function(res)
        if not res or res.err then
            respondFailure(cb, "[esx-adminmenu:spectate]", res)
            return
        end

        if not res.isAdmin or not res.playerOnline then
            cb({ success = false, err = getCallbackError(res), playerOnline = res.playerOnline })
            return
        end

        cb({ success = true, playerOnline = res.playerOnline })
        Spectate(data.id, res.targetCoords)
    end, data)
end)

RegisterNUICallback("kick", function(data, cb)
    ESX.TriggerServerCallback("esx-adminmenu:server:kick", function(res)
        if not res or res.err then
            respondFailure(cb, "[esx-adminmenu:kick]", res)
            return
        end

        cb({ success = res.success, playerOnline = res.playerOnline })
    end, data)
end)

RegisterNUICallback("ban", function(data, cb)
    ESX.TriggerServerCallback("esx-adminmenu:server:ban", function(res)
        if not res or res.err then
            respondFailure(cb, "[esx-adminmenu:ban]", res)
            return
        end

        cb({ success = res.success, playerOnline = res.playerOnline })
    end, data)
end)

RegisterNUICallback("ban:offline", function(data, cb)
    ESX.TriggerServerCallback("esx-adminmenu:server:ban:offline", function(res)
        if not res or res.err then
            respondFailure(cb, "[esx-adminmenu:banOffline]", res)
            return
        end

        cb({ success = res.success })
    end, data)
end)

RegisterNUICallback("ban:changeExpiry", function(data, cb)
    ESX.TriggerServerCallback("esx-adminmenu:server:ban:changeExpiry", function(res)
        if not res or res.err then
            respondFailure(cb, "[esx-adminmenu:changeExpiry]", res)
            return
        end

        cb({ success = res.success })
    end, data)
end)

RegisterNUICallback("ban:revoke", function(data, cb)
    ESX.TriggerServerCallback("esx-adminmenu:server:ban:revoke", function(res)
        if not res or res.err then
            respondFailure(cb, "[esx-adminmenu:revokeBan]", res)
            return
        end

        cb({ success = res.success })
    end, data)
end)

RegisterNUICallback("releaseFocus", function(data, cb)
    ToggleNUIFocus(false)
    cb({ success = true })
end)

RegisterNUICallback("adminMenu:setInputFocus", function(data, cb)
    local enabled = data and data.enabled == true

    if AdminOpen and AdminMode == "menu" then
        if enabled then
            SetNuiFocus(true, true)
            SetNuiFocusKeepInput(false)
        else
            SetNuiFocus(true, false)
            SetNuiFocusKeepInput(true)
        end
    end

    cb({ success = true })
end)

RegisterNUICallback("getVehicles", function(data, cb)
    ESX.TriggerServerCallback("esx-adminmenu:server:getVehicles", function(res)
        if not res or res.err then
            print("[esx-adminmenu:getVehicles]", res and res.err)
            cb({ success = false, err = getCallbackError(res, "Failed to fetch vehicles."), vehicles = {} })
            return
        end

        local vehicles = res.vehicles or {}

        for i = 1, #vehicles do
            local v = vehicles[i]
            v.name = Helpers.resolveVehicleName(v.model)
        end

        cb({
            success = true,
            vehicles = vehicles,
            hasMore = res.hasMore == true,
            nextOffset = res.nextOffset or #vehicles,
            limit = res.limit,
        })
    end, data)
end)

RegisterNUICallback("player:notify", function(data, cb)
    ESX.TriggerServerCallback("esx-adminmenu:server:notify", function(res)
        if not res or res.err then
            respondFailure(cb, "[esx-adminmenu:notifyPlayer]", res)
            return
        end

        cb({ success = res.success, playerOnline = res.playerOnline })
    end, data)
end)

RegisterNUICallback("getBans", function(data, cb)
    ESX.TriggerServerCallback("esx-adminmenu:server:getBans", function(res)
        if not res or res.err then
            print("[esx-adminmenu:getBans]", res and res.err)
            cb({ success = false, err = getCallbackError(res, "Failed to fetch bans."), bans = {} })
            return
        end

        cb({
            success = true,
            bans = res.bans or {},
            hasMore = res.hasMore == true,
            nextOffset = res.nextOffset or #(res.bans or {}),
            limit = res.limit,
        })
    end, data)
end)

RegisterNUICallback("getRecentPlayers", function(data, cb)
    ESX.TriggerServerCallback("esx-adminmenu:server:getRecentPlayers", function(res)
        if not res or res.err then
            print("[esx-adminmenu:getRecentPlayers]", res and res.err)
            cb({ success = false, err = getCallbackError(res, "Failed to fetch recent players."), players = {} })
            return
        end

        cb({ success = true, players = res.players or {} })
    end)
end)

RegisterNUICallback("player:searchOffline", function(data, cb)
    ESX.TriggerServerCallback("esx-adminmenu:server:searchOfflinePlayer", function(res)
        if not res or res.err then
            print("[esx-adminmenu:searchOffline]", res and res.err)
            cb({ success = false, err = getCallbackError(res, "Failed to search offline players."), players = {} })
            return
        end

        cb({ success = true, players = res.players or {} })
    end, data)
end)

RegisterNUICallback("vehicle:impound", function(data, cb)
    ESX.TriggerServerCallback("esx-adminmenu:server:vehicleImpound", function(res)
        if not res or res.err then
            respondFailure(cb, "[esx-adminmenu:vehicleImpound]", res)
            return
        end

        cb({ success = res.success })
    end, data)
end)

RegisterNUICallback("vehicle:unimpound", function(data, cb)
    ESX.TriggerServerCallback("esx-adminmenu:server:vehicleUnimpound", function(res)
        if not res or res.err then
            respondFailure(cb, "[esx-adminmenu:vehicleUnimpound]", res)
            return
        end

        cb({ success = res.success })
    end, data)
end)

RegisterNUICallback("vehicle:delete", function(data, cb)
    ESX.TriggerServerCallback("esx-adminmenu:server:vehicleDelete", function(res)
        if not res or res.err then
            respondFailure(cb, "[esx-adminmenu:vehicleDelete]", res)
            return
        end

        cb({ success = res.success })
    end, data)
end)

RegisterNetEvent("esx-adminmenu:client:copyToClipboard", function(text)
    SendNUIMessage({
        action = "copyToClipboard",
        data = text,
    })
end)

RegisterNetEvent("esx-adminmenu:client:open", function(data)
    ToggleNUIFocus(true, "dashboard")
    SendNUIMessage({
        action = "openAdminDashboard",
        data = {
            players = data or {},
        },
    })
end)

RegisterNetEvent("esx-adminmenu:client:openAdminMenu", function()
    openAdminMenu()
end)

RegisterNetEvent("esx-adminmenu:client:openInformation", function(data)
    data = data or {}
    ToggleNUIFocus(true, "dashboard")
    SendNUIMessage({
        action = "openAdminDashboard",
        data = {
            players = data.players or {},
            selectedPlayerId = data.selectedPlayerId,
            serverData = data.serverData,
        },
    })
end)

CreateThread(function()
    while true do
        Wait(60000)
        pushServerData()
    end
end)
