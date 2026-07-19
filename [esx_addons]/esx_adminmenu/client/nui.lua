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

RegisterKeyMapping("adminmenu", "Open Admin Menu", "keyboard", Config.Keybinds.AdminMenu)
RegisterKeyMapping("admindashboard", "Open Admin Dashboard", "keyboard", Config.Keybinds.AdminDashboard)

RegisterNUICallback("openDashboard", function(data, cb)
    openDashboard(cb)
end)

RegisterNUICallback("openAdminMenu", function(data, cb)
    openAdminMenu(cb)
end)

-- D2: quick-action / toggle registry ----------------------------------------
-- Simple toggles share one envelope: flip state, mirror it to the web via
-- sendQuickMenuState and return the { active } extra. Entries flagged with
-- command = true also expose the same permission-gated command path.
local toggleActions = {
    { action = "noclip", toggle = ClientActions.ToggleNoClip, command = true, mirrorInvisible = true },
    { action = "names", toggle = ClientActions.ToggleNames, command = true },
    { action = "blips", toggle = ClientActions.ToggleBlips, command = true },
    { action = "godmode", toggle = ClientActions.ToggleGodmode },
    { action = "invisible", toggle = ClientActions.ToggleInvisible },
    { action = "infiniteAmmo", toggle = ClientActions.ToggleInfiniteAmmo },
}

for _, entry in ipairs(toggleActions) do
    RegisterNUICallback("adminMenu:" .. entry.action, function(data, cb)
        runProtectedClientAction(cb, "[esx-adminmenu:" .. entry.action .. "]", function()
            local active = entry.toggle()
            sendQuickMenuState(entry.action, active)
            if entry.mirrorInvisible and ClientActions.IsInvisibleActive then
                sendQuickMenuState("invisible", ClientActions.IsInvisibleActive())
            end
            return true, nil, { active = active }
        end, entry.action)
    end)

    if entry.command then
        RegisterCommand(entry.action, function()
            runAdminCommandAction(entry.action, entry.toggle)
        end, false)
    end
end

-- Direct actions just run a ClientActions function under a permission gate.
-- run receives the raw NUI data; functions that ignore arguments are safe to
-- reference bare.
local directActions = {
    { name = "heal", permission = "heal", run = ClientActions.Heal },
    { name = "armor", permission = "armor", run = function() return ClientActions.SetArmor(100) end },
    { name = "repairVehicle", permission = "repairVehicle", run = ClientActions.RepairVehicle },
    { name = "cleanVehicle", permission = "cleanVehicle", run = ClientActions.CleanVehicle },
    { name = "deleteVehicle", permission = "deleteVehicle", run = ClientActions.DeleteVehicle },
    { name = "waypoint", permission = "waypoint", run = ClientActions.TeleportToWaypoint },
    { name = "spawnVehicle", permission = "spawnVehicle", run = function(data) return ClientActions.SpawnVehicle(data or {}) end },
    { name = "flipVehicle", permission = "flipVehicle", run = ClientActions.FlipVehicle },
    { name = "customizeVehicle", permission = "customizeVehicle", run = function(data) return ClientActions.CustomizeVehicle(data or {}) end },
    { name = "copyCoords", permission = "copyCoords", run = ClientActions.CopyCoords },
    { name = "cycleVehicleTransmission", permission = "transmissionLevel", run = ClientActions.CycleVehicleTransmission },
    { name = "cycleVehicleSuspension", permission = "suspensionLevel", run = ClientActions.CycleVehicleSuspension },
    { name = "cycleVehicleArmor", permission = "armorLevel", run = ClientActions.CycleVehicleArmor },
    { name = "cycleVehicleNeonColor", permission = "neonColorCycle", run = ClientActions.CycleVehicleNeonColor },
}

for _, entry in ipairs(directActions) do
    RegisterNUICallback("adminMenu:" .. entry.name, function(data, cb)
        runProtectedClientAction(cb, "[esx-adminmenu:" .. entry.name .. "]", function()
            return entry.run(data)
        end, entry.permission)
    end)
end

-- Bespoke closures: quick actions that emit extra menu state on success.
RegisterNUICallback("adminMenu:revive", function(data, cb)
    ESX.TriggerServerCallback("esx-adminmenu:server:selfAction", function(res)
        if not res or not res.success then
            respondFailure(cb, "[esx-adminmenu:revive]", res)
            return
        end

        cb({ success = true })
    end, { action = "revive" })
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

RegisterNUICallback("adminMenu:cycleVehicleColor", function(data, cb)
    runProtectedClientAction(cb, "[esx-adminmenu:cycleVehicleColor]", function()
        local success, err, extra = ClientActions.CycleVehicleColor()
        if success then
            sendQuickMenuState("colorCycle", extra and extra.active or true, extra and extra.value)
        end
        return success, err, extra
    end, "colorCycle")
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

-- D1: server-callback bridge factory ----------------------------------------
-- The proxy callbacks all share one shape: trigger a server callback, on error
-- report + respond, on success forward a fixed subset of fields to the web.
-- Soft entries return an empty collection (with optional paging) instead of a
-- hard failure, and special cases hook in via onSuccess / mapItem.
local function registerServerBridge(spec)
    RegisterNUICallback(spec.name, function(data, cb)
        local function handler(res)
            if not res or res.err then
                if spec.soft then
                    print(spec.label, res and res.err)
                    local out = { success = false, err = getCallbackError(res, spec.softError) }
                    out[spec.collection] = {}
                    cb(out)
                else
                    respondFailure(cb, spec.label, res)
                end
                return
            end

            if spec.onSuccess then
                spec.onSuccess(res, cb, data)
                return
            end

            if spec.soft then
                local coll = res[spec.collection] or {}
                if spec.mapItem then
                    for i = 1, #coll do
                        spec.mapItem(coll[i])
                    end
                end

                local out = { success = true }
                out[spec.collection] = coll
                if spec.paging then
                    out.hasMore = res.hasMore == true
                    out.nextOffset = res.nextOffset or #coll
                    out.limit = res.limit
                end
                cb(out)
                return
            end

            local out = { success = spec.successTrue and true or res.success }
            if spec.forward then
                for _, field in ipairs(spec.forward) do
                    if type(field) == "table" then
                        local val = res[field.key]
                        if val == nil then
                            val = field.default
                        end
                        out[field.key] = val
                    else
                        out[field] = res[field]
                    end
                end
            end
            cb(out)
        end

        if spec.passData == false then
            ESX.TriggerServerCallback(spec.event, handler)
        else
            ESX.TriggerServerCallback(spec.event, handler, data)
        end
    end)
end

local serverBridges = {
    {
        name = "server:action",
        event = "esx-adminmenu:server:serverAction",
        label = "[esx-adminmenu:serverAction]",
        forward = { "serverData" },
    },
    {
        name = "server:radioPlayers",
        event = "esx-adminmenu:server:getRadioChannelPlayers",
        label = "[esx-adminmenu:radioPlayers]",
        successTrue = true,
        forward = { { key = "players", default = {} } },
    },
    {
        name = "player:action",
        event = "esx-adminmenu:server:playerAction",
        label = "[esx-adminmenu:playerAction]",
        forward = { "playerOnline" },
    },
    {
        name = "goto",
        event = "esx-adminmenu:server:goto",
        label = "[esx-adminmenu:goto]",
        forward = { "playerOnline" },
    },
    {
        name = "bring",
        event = "esx-adminmenu:server:bring",
        label = "[esx-adminmenu:bring]",
        forward = { "playerOnline" },
    },
    {
        name = "spectate",
        event = "esx-adminmenu:server:spectate",
        label = "[esx-adminmenu:spectate]",
        onSuccess = function(res, cb, data)
            if not res.isAdmin or not res.playerOnline then
                cb({ success = false, err = getCallbackError(res), playerOnline = res.playerOnline })
                return
            end

            cb({ success = true, playerOnline = res.playerOnline })
            Spectate(data.id, res.targetCoords)
        end,
    },
    {
        name = "kick",
        event = "esx-adminmenu:server:kick",
        label = "[esx-adminmenu:kick]",
        forward = { "playerOnline" },
    },
    {
        name = "ban",
        event = "esx-adminmenu:server:ban",
        label = "[esx-adminmenu:ban]",
        forward = { "playerOnline" },
    },
    {
        name = "ban:offline",
        event = "esx-adminmenu:server:ban:offline",
        label = "[esx-adminmenu:banOffline]",
    },
    {
        name = "ban:changeExpiry",
        event = "esx-adminmenu:server:ban:changeExpiry",
        label = "[esx-adminmenu:changeExpiry]",
    },
    {
        name = "ban:revoke",
        event = "esx-adminmenu:server:ban:revoke",
        label = "[esx-adminmenu:revokeBan]",
    },
    {
        name = "player:notify",
        event = "esx-adminmenu:server:notify",
        label = "[esx-adminmenu:notifyPlayer]",
        forward = { "playerOnline" },
    },
    {
        name = "vehicle:impound",
        event = "esx-adminmenu:server:vehicleImpound",
        label = "[esx-adminmenu:vehicleImpound]",
    },
    {
        name = "vehicle:unimpound",
        event = "esx-adminmenu:server:vehicleUnimpound",
        label = "[esx-adminmenu:vehicleUnimpound]",
    },
    {
        name = "vehicle:delete",
        event = "esx-adminmenu:server:vehicleDelete",
        label = "[esx-adminmenu:vehicleDelete]",
    },
    {
        name = "getBans",
        event = "esx-adminmenu:server:getBans",
        label = "[esx-adminmenu:getBans]",
        soft = true,
        collection = "bans",
        softError = "Failed to fetch bans.",
        paging = true,
    },
    {
        name = "getVehicles",
        event = "esx-adminmenu:server:getVehicles",
        label = "[esx-adminmenu:getVehicles]",
        soft = true,
        collection = "vehicles",
        softError = "Failed to fetch vehicles.",
        paging = true,
        mapItem = function(v)
            v.name = Helpers.resolveVehicleName(v.model)
        end,
    },
    {
        name = "getRecentPlayers",
        event = "esx-adminmenu:server:getRecentPlayers",
        label = "[esx-adminmenu:getRecentPlayers]",
        soft = true,
        collection = "players",
        softError = "Failed to fetch recent players.",
        passData = false,
    },
    {
        name = "player:searchOffline",
        event = "esx-adminmenu:server:searchOfflinePlayer",
        label = "[esx-adminmenu:searchOffline]",
        soft = true,
        collection = "players",
        softError = "Failed to search offline players.",
    },
}

for _, spec in ipairs(serverBridges) do
    registerServerBridge(spec)
end

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
    local interval = (Config.AdminMenu and Config.AdminMenu.ServerDataInterval) or 60000
    while true do
        Wait(interval)
        pushServerData()
    end
end)
