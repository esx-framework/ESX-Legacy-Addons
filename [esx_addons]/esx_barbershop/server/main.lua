-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local payments = {}
local limiter = xLib.rateLimiter({ capacity = 2, refill = 1, interval = 2000 })

local function isNearBarberShop(source)
    local ped = GetPlayerPed(source)

    if ped <= 0 then return false end

    local coords = GetEntityCoords(ped)

    for i = 1, #Config.Shops do
        if #(coords - Config.Shops[i]) <= (Config.ShopDistance or 3.0) then return true end
    end

    return false
end

local function payHaircut(source, cb, skin, account)
    local player = ESX.GetPlayerFromId(source)

    if not player then return cb(false, 'player_unavailable') end

    if not limiter:consume(source) then return cb(false, 'rate_limited') end

    if not isNearBarberShop(source) then return cb(false, 'not_near_shop') end

    if type(skin) ~= 'table' then return cb(false, 'invalid_appearance:payload:expected_table') end

    if payments[player.identifier] then return cb(false, 'payment_pending') end

    local identifier = player.identifier

    if player.beginAccountOperation() ~= true then return cb(false, 'player_unavailable') end

    payments[identifier] = true

    local charged, failure = PaymentGateway.Charge(player, account, Config.Price, 'Haircut')

    if not charged then
        payments[identifier] = nil
        player.endAccountOperation()
        return cb(false, failure)
    end

    local finished = false

    local function finish(saved, reason)
        if finished then return end

        finished = true
        payments[identifier] = nil

        if saved ~= true then
            reason = reason or 'appearance_save_failed'

            if PaymentGateway.Refund(player, account, Config.Price, 'Haircut Refund') ~= true then
                print(('[esx_barbershop] Refund failed for %s'):format(identifier))
            end

            print(('[esx_barbershop] Appearance save failed for player %s: %s'):format(source, reason))
        elseif player.isCurrent() == true then
            TriggerClientEvent('esx:showNotification', source, TranslateCap('you_paid', ESX.Math.GroupDigits(Config.Price)))
        end

        player.endAccountOperation()
        cb(saved == true, saved ~= true and reason or nil)
    end

    payments[identifier] = finish

    local ok, accepted = pcall(function()
        return exports.esx_skin:SaveSkin(source, skin, finish, 'barber')
    end)

    if not ok then
        print(('[esx_barbershop] SaveSkin export failed: %s'):format(tostring(accepted)))
        finish(false, 'appearance_save_error')
    elseif accepted == false then
        finish(false, 'appearance_save_rejected')
    end
end

RegisterNetEvent('esx_barbershop:pay', function(skin)
    payHaircut(source, function() end, skin)
end)

xLib.callback.registerCompat('esx_barbershop:pay', payHaircut)

xLib.callback.registerCompat('esx_barbershop:checkMoney', function(source, cb)
    local player = ESX.GetPlayerFromId(source)
    cb(player and isNearBarberShop(source) and player.getMoney() >= Config.Price or false)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, finish in pairs(payments) do
        if type(finish) == 'function' then finish(false, 'resource_stopped') end
    end
end)
