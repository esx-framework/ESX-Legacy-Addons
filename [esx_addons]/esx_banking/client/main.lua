-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local BANK = {
    Data = {}
}

local activeBlips, bankPoints, atmPoints, markerPoints = {}, {}, {}, {}
local playerLoaded, uiActive, inMenu = false, false, false
local promptIsAtm, promptAtmData = false, nil

local function GetInteractionDistance()
    return tonumber(Config.InteractionDistance) or 1.5
end

function BANK:Thread()
    if playerLoaded then
        return
    end

    self:CreateBlips()
    playerLoaded = true

    CreateThread(function()
        local data = self.Data

        while playerLoaded do
            data.ped = PlayerPedId()
            data.coord = GetEntityCoords(data.ped)
            bankPoints, atmPoints, markerPoints = {}, {}, {}
            local closestAtmData, closestAtmDistance = nil, nil

            if IsPedOnFoot(data.ped) and not ESX.PlayerData.dead and not inMenu then
                for i = 1, #(Config.AtmModels or {}) do
                    local atm = GetClosestObjectOfType(data.coord.x, data.coord.y, data.coord.z, 0.7, Config.AtmModels[i], false, false, false)
                    if atm ~= 0 then
                        local atmCoords = GetEntityCoords(atm)
                        local atmDistance = #(data.coord - atmCoords)
                        atmPoints[#atmPoints + 1] = atmCoords

                        if not closestAtmDistance or atmDistance < closestAtmDistance then
                            closestAtmDistance = atmDistance
                            closestAtmData = {
                                model = GetEntityModel(atm),
                                coords = {
                                    x = atmCoords.x,
                                    y = atmCoords.y,
                                    z = atmCoords.z
                                }
                            }
                        end
                    end
                end

                for i = 1, #(Config.Banks or {}) do
                    local bankDistance = #(data.coord - Config.Banks[i].Position.xyz)
                    if bankDistance <= GetInteractionDistance() then
                        bankPoints[#bankPoints + 1] = Config.Banks[i].Position.xyz
                    end

                    if Config.ShowMarker and bankDistance <= (Config.DrawMarker or 10) then
                        markerPoints[#markerPoints + 1] = Config.Banks[i].Position.xyz
                    end
                end
            end

            if next(bankPoints) and not uiActive then
                self:TextUi(true, false)
            elseif next(atmPoints) and not uiActive then
                self:TextUi(true, true, closestAtmData)
            elseif next(atmPoints) and uiActive and promptIsAtm then
                promptAtmData = closestAtmData
            elseif not next(bankPoints) and not next(atmPoints) and uiActive then
                self:TextUi(false)
            end

            Wait(750)
        end
    end)

    if not Config.ShowMarker then
        return
    end

    CreateThread(function()
        while playerLoaded do
            local wait = 1000

            if next(markerPoints) then
                wait = 0
                for i = 1, #markerPoints do
                    DrawMarker(20, markerPoints[i].x, markerPoints[i].y, markerPoints[i].z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.2, 0.2, 251, 155, 4, 255, false, true, 2, false, nil, nil, false)
                end
            end

            Wait(wait)
        end
    end)
end

function BANK:TextUi(state, atm, atmData)
    uiActive = state
    promptIsAtm = atm or false
    promptAtmData = promptIsAtm and atmData or nil

    if not state then
        promptAtmData = nil
        return ESX.HideUI()
    end

    ESX.TextUI(TranslateCap("press_e_banking"))

    CreateThread(function()
        while uiActive do
            if IsControlJustReleased(0, 38) then
                local isAtm, atmAccessData = promptIsAtm, promptAtmData
                self:TextUi(false)
                self:HandleUi(true, isAtm, atmAccessData)
            end

            Wait(0)
        end
    end)
end

function BANK:CreateBlips()
    local tmpActiveBlips = {}

    for i = 1, #(Config.Banks or {}) do
        if type(Config.Banks[i].Blip) == "table" and Config.Banks[i].Blip.Enabled then
            local position = Config.Banks[i].Position
            local bInfo = Config.Banks[i].Blip
            local blip = xLib.blips.create({
                coords = position,
                sprite = bInfo.Sprite,
                scale = bInfo.Scale,
                color = bInfo.Color,
                shortRange = true,
                label = bInfo.Label
            })

            tmpActiveBlips[#tmpActiveBlips + 1] = blip
        end
    end

    activeBlips = tmpActiveBlips
end

function BANK:RemoveBlips()
    for i = 1, #activeBlips do
        if DoesBlipExist(activeBlips[i]) then
            RemoveBlip(activeBlips[i])
        end
    end

    activeBlips = {}
end

function BANK:HandleUi(state, atm, atmData)
    if not state then
        xLib.nui.focus(false, false)
        inMenu = false
        xLib.nui.send({
            action = "closeBanking"
        })
        return
    end

    if inMenu then
        return
    end

    inMenu = true
    local accessType = atm and "atm" or "bank"

    xLib.callback("esx_banking:getPlayerData", false, function(data)
        if not inMenu then
            return
        end

        if not data or data.success ~= true then
            inMenu = false
            ESX.ShowNotification(TranslateCap("cant_do_it"), "error")
            return
        end

        xLib.nui.focus(true, true)
        ClearPedTasks(PlayerPedId())

        xLib.nui.send({
            action = "openBanking",
            payload = {
                accessType = data.accessType,
                bankName = TranslateCap("bank_name"),
                playerName = data.playerName,
                cash = data.money,
                bank = data.bankMoney,
                hasPin = data.hasPin,
                transactions = data.transactionHistory or {}
            }
        })
    end, {
        accessType = accessType,
        atm = atm and atmData or nil
    })
end

function BANK:LoadNpc(index, netID)
    CreateThread(function()
        while not NetworkDoesEntityExistWithNetworkId(netID) do
            Wait(200)
        end

        local npc = NetworkGetEntityFromNetworkId(netID)
        TaskStartScenarioInPlace(npc, Config.Peds[index].Scenario, 0, true)
        SetEntityProofs(npc, true, true, true, true, true, true, true, true)
        SetBlockingOfNonTemporaryEvents(npc, true)
        FreezeEntityPosition(npc, true)
        SetPedCanRagdollFromPlayerImpact(npc, false)
        SetPedCanRagdoll(npc, false)
        SetEntityAsMissionEntity(npc, true, true)
        SetEntityDynamic(npc, false)
    end)
end

RegisterNetEvent("esx_banking:closebanking", function()
    BANK:HandleUi(false)
end)

RegisterNetEvent("esx_banking:pedHandler", function(netIdTable)
    for i = 1, #netIdTable do
        BANK:LoadNpc(i, netIdTable[i])
    end
end)

RegisterNetEvent("esx_banking:updateMoneyInUI", function(data, bankMoney, money)
    if type(data) == "table" then
        xLib.nui.send({
            action = "updateBanking",
            payload = data
        })
        return
    end

    xLib.nui.send({
        action = "updateBanking",
        payload = {
            actionType = data,
            bankMoney = bankMoney,
            money = money
        }
    })
end)

AddEventHandler("onResourceStart", function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    BANK:Thread()
end)

RegisterNetEvent("esx:playerLoaded", function()
    BANK:Thread()
end)

RegisterNetEvent("esx:onPlayerLogout", function()
    playerLoaded = false
    inMenu = false
    uiActive = false
    BANK:RemoveBlips()
    xLib.nui.focus(false, false)
    ESX.HideUI()
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    BANK:RemoveBlips()
    if uiActive then
        BANK:TextUi(false)
    end

    if inMenu then
        xLib.nui.focus(false, false)
    end
end)

RegisterNetEvent("esx:onPlayerDeath", function()
    BANK:TextUi(false)
    if inMenu then
        BANK:HandleUi(false)
    end
end)

xLib.nui.register("close", function()
    BANK:HandleUi(false)
    return "ok"
end)

xLib.nui.register("clickButton", function(data)
    if not data or not inMenu then
        return {ok = false}
    end

    TriggerServerEvent("esx_banking:doingType", data)
    return {ok = true}
end)

xLib.nui.register("checkPincode", function(data, reply)
    if not data or not inMenu then
        reply({error = true})
        return
    end

    xLib.callback("esx_banking:checkPincode", false, function(pincode)
        if pincode then
            reply({success = true})
            ESX.ShowNotification(TranslateCap("pincode_found"), "success")
        else
            reply({error = true})
            ESX.ShowNotification(TranslateCap("pincode_not_found"), "error")
        end
    end, data)

    return xLib.nui.defer
end)
