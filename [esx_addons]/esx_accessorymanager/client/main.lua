-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local Radial = { isOpen = false, ready = false, busy = false, lastAction = -10000, generation = 0 }
Accessories.Radial = Radial
local Wardrobe = Accessories.Wardrobe
local themeDefaults = { backgroundColor = '#121414', secondaryColor = '#1a1c1c', accentColor = '#a28d7a' }

local function canUse()
    local ped = PlayerPedId()
    return ESX.IsPlayerLoaded() and not ESX.PlayerData.dead and not IsEntityDead(ped)
        and not IsPedRagdoll(ped) and not IsPedFalling(ped) and not IsPedCuffed(ped)
        and not IsPauseMenuActive() and not LocalPlayer.state.invBusy
        and (Config.Radial.AllowInVehicle or not IsPedInAnyVehicle(ped, false))
end

function Radial.Refresh()
    if Radial.isOpen then
        xLib.nui.send('accessories:state', { states = Wardrobe.States() })
    end
end

function Radial.Close()
    if not Radial.isOpen then return end
    Radial.isOpen = false
    xLib.nui.close({ action = 'accessories:close' })
end

function Radial.Open()
    if Radial.isOpen then Radial.Close() return end
    if not Radial.ready or not canUse() or IsNuiFocused() then return end
    if not Wardrobe.IsSupported() then
        ESX.ShowNotification(Accessories.Translate('unsupported'))
        return
    end
    Radial.isOpen = true
    Radial.generation = Radial.generation + 1
    local generation = Radial.generation
    Radial.ped = PlayerPedId()
    Radial.model = GetEntityModel(Radial.ped)
    xLib.nui.open({ action = 'accessories:open', data = {
        labels = Accessories.GetLabels(), states = Wardrobe.States(), locale = Config.Locale,
        theme = xLib.colors.getESXTheme(themeDefaults)
    } }, true, true, false)
    -- This loop exists only while the menu is visible; no idle frame polling.
    CreateThread(function()
        while Radial.isOpen and generation == Radial.generation do
            if not canUse() or Radial.ped ~= PlayerPedId() or Radial.model ~= GetEntityModel(PlayerPedId()) then
                Radial.Close()
                break
            end
            Radial.Refresh()
            Wait(200)
        end
    end)
end

function Radial.Act(id)
    if Radial.busy or not canUse() then return xLib.nui.fail(Accessories.Translate('blocked')) end
    local now = GetGameTimer()
    if now - Radial.lastAction < Config.Radial.ActionCooldown then
        return xLib.nui.fail(Accessories.Translate('busy'))
    end
    Radial.lastAction, Radial.busy = now, true
    local actions = { reset = Wardrobe.Restore, repairProps = Wardrobe.RepairProps, repairHair = Wardrobe.ToggleFixHair }
    local ok, success, reason = pcall(function()
        if actions[id] then return actions[id]() end
        return Wardrobe.Toggle(id)
    end)
    Radial.busy = false
    if not ok then
        print(('[esx_accessorymanager] Wardrobe action failed: %s'):format(success))
        return xLib.nui.fail(Accessories.Translate('failed'))
    end
    if not success then return xLib.nui.fail(Accessories.Translate(reason or 'unavailable')) end
    Radial.Refresh()
    return xLib.nui.ok({ states = Wardrobe.States() })
end

xLib.nui.register('ready', function()
    Radial.ready = true
    if Radial.isOpen then Radial.Close() end
    return xLib.nui.ok()
end)

xLib.nui.register('close', function()
    Radial.Close()
    return xLib.nui.ok()
end)

xLib.nui.register('accessoryAction', function(data)
    if not Radial.isOpen or type(data.id) ~= 'string' or #data.id > 32 then
        return xLib.nui.fail(Accessories.Translate('blocked'))
    end
    return Radial.Act(data.id)
end)

RegisterCommand(Config.Radial.Command, Radial.Open, false)
exports('OpenAccessoryMenu', Radial.Open)
exports('CloseAccessoryMenu', Radial.Close)
AddEventHandler('esx_accessorymanager:openMenu', Radial.Open)

if Config.EnableControls then
    xLib.addKeybind({
        name = 'accessorymanager',
        description = Accessories.Translate('title'),
        defaultMapper = 'keyboard',
        defaultKey = Config.Radial.DefaultKey,
        onPressed = Radial.Open
    })
end

local function clearSession()
    Radial.Close()
    Wardrobe.Clear()
end

RegisterNetEvent('esx:onPlayerLogout', clearSession)
RegisterNetEvent('esx:playerLoaded', clearSession)
AddEventHandler('esx:onPlayerDeath', Radial.Close)
AddEventHandler('skinchanger:loadSkin', Radial.Close)
AddEventHandler('skinchanger:loadClothes', Radial.Close)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Radial.Close()
    if GetResourceState('skinchanger') == 'started' then Wardrobe.Restore() end
end)
