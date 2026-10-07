-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local ClothesPurchases = {}
local ClothesPayments = {}

local function isCurrentPlayer(source, player)
    return player and player.source == source and player.isCurrent and player.isCurrent() == true
end

local function isNearClothesShop(source)
    local ped = GetPlayerPed(source)
    if ped <= 0 then
        return false
    end

    local coords = GetEntityCoords(ped)
    for i = 1, #Config.Shops do
        if #(coords - Config.Shops[i]) <= (Config.ShopDistance or 3.0) then
            return true
        end
    end

    return false
end

local function sanitizeOutfitLabel(label)
    label = tostring(label or ''):gsub('[%c]', ' ')
    label = label:gsub('^%s+', ''):gsub('%s+$', '')

    if label == '' then
        return nil
    end

    return label:sub(1, Config.MaxOutfitLabelLength or 40)
end

local function calculatePurchaseCost(newSkin, oldSkin)
    if not Config.ChargePerPiece then
        return Config.Price
    end

    if type(newSkin) ~= 'table' or type(oldSkin) ~= 'table' then
        return Config.Price
    end

    local purchaseCost = 0
    for _, value in pairs(Config.SkinProps) do
        if
            (newSkin[value .. '_1'] ~= oldSkin[value .. '_1'])
            or (newSkin[value .. '_2'] ~= oldSkin[value .. '_2'])
        then
            purchaseCost = purchaseCost + Config.Price
        end
    end

    return math.max(Config.Price, purchaseCost)
end

RegisterServerEvent('esx_clotheshop:saveOutfit')
AddEventHandler('esx_clotheshop:saveOutfit', function(label, skin)
    local source = source
    local xPlayer = ESX.Player(source)
    label = sanitizeOutfitLabel(label)

    if
        not xPlayer
        or not label
        or type(skin) ~= 'table'
        or not ClothesPurchases[source]
        or not isCurrentPlayer(source, ClothesPurchases[source].player)
        or ClothesPurchases[source].expires < GetGameTimer()
    then
        return
    end

    local purchase = ClothesPurchases[source]
    ClothesPurchases[source] = nil
    skin = purchase.skin
    TriggerEvent('esx_datastore:getDataStore', 'property', xPlayer.getIdentifier(), function(store)
        if not store then
            return
        end

        local dressing = store.get('dressing')

        if dressing == nil then
            dressing = {}
        end

        if #dressing >= (Config.MaxOutfits or 20) then
            return
        end

        table.insert(dressing, {
            label = label,
            skin = skin,
        })

        store.set('dressing', dressing)
        store.save()
        ClothesPurchases[source] = nil
    end)
end)

xLib.callback.registerCompat('esx_clotheshop:buyClothes', function(source, cb, newSkin, oldSkin)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer or ClothesPayments[xPlayer.getIdentifier()] or not isNearClothesShop(source) then
        return cb(false)
    end

    newSkin = exports.esx_skin:ValidateSkin(newSkin)

    if not newSkin then
        return cb(false)
    end

    -- The client snapshot cannot determine the price of a purchase.
    oldSkin = exports.esx_skin:GetSkin(source)

    if not isCurrentPlayer(source, xPlayer) or type(oldSkin) ~= 'table' then
        return cb(false)
    end

    local purchaseCost = calculatePurchaseCost(newSkin, oldSkin)

    if not xPlayer or type(newSkin) ~= 'table' or not isNearClothesShop(source) then
        return cb(false)
    end

    if xPlayer.getMoney() < purchaseCost then
        return cb(false, 'not_enough_money')
    end

    local identifier = xPlayer.getIdentifier()

    if ClothesPayments[identifier] or xPlayer.beginAccountOperation() ~= true then
        return cb(false, 'save_failed')
    end

    ClothesPayments[identifier] = true

    if xPlayer.removeMoney(purchaseCost, 'Outfit Purchase') ~= true then
        ClothesPayments[identifier] = nil
        xPlayer.endAccountOperation()
        return cb(false, 'not_enough_money')
    end

    local finished = false

    local function finish(saved)
        if finished then
            return
        end

        finished = true
        ClothesPayments[identifier] = nil

        if saved ~= true then
            if xPlayer.addMoney(purchaseCost, 'Outfit Purchase Refund') ~= true then
                print(('[esx_clotheshop] Outfit refund failed for %s'):format(identifier))
            end
        elseif isCurrentPlayer(source, xPlayer) then
            ClothesPurchases[source] = {
                player = xPlayer,
                skin = newSkin,
                expires = GetGameTimer() + (Config.PurchaseSessionDuration or 60000),
            }
            TriggerClientEvent(
                'esx:showNotification',
                source,
                TranslateCap('you_paid', purchaseCost)
            )
        end

        xPlayer.endAccountOperation()
        cb(saved == true, saved ~= true and 'save_failed' or nil)
    end

    ClothesPayments[identifier] = finish

    local ok, accepted = pcall(function()
        return exports.esx_skin:SaveSkin(source, newSkin, finish, 'clothes')
    end)

    if not ok or accepted == false then
        finish(false)
    end
end)

xLib.callback.registerCompat('esx_clotheshop:checkPropertyDataStore', function(source, cb)
    local xPlayer = ESX.Player(source)
    local foundStore = false
    if not xPlayer then
        return cb(false)
    end

    TriggerEvent('esx_datastore:getDataStore', 'property', xPlayer.getIdentifier(), function(store)
        foundStore = store ~= nil
    end)

    cb(foundStore)
end)

AddEventHandler('esx:playerDropped', function(playerId)
    ClothesPurchases[playerId] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    for _, finish in pairs(ClothesPayments) do
        local ok, err = pcall(finish, false)

        if not ok then
            print(('[esx_clotheshop] Purchase cleanup failed: %s'):format(tostring(err)))
        end
    end
end)
