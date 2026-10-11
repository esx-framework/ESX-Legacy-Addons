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

local function payHaircut(source, cb, skin)
    local player = ESX.GetPlayerFromId(source)

    if not player or not limiter:consume(source) or not isNearBarberShop(source) or type(skin) ~= 'table' or payments[player.identifier] then 
        return cb(false) 
    end

    local identifier = player.identifier

    if player.getMoney() < Config.Price or player.beginAccountOperation() ~= true then return cb(false) end

    payments[identifier] = true

    if player.removeMoney(Config.Price, 'Haircut') ~= true then
        payments[identifier] = nil
        player.endAccountOperation()
        return cb(false)
    end

    local finished = false

    local function finish(saved)
        if finished then return end

        finished = true
        payments[identifier] = nil

        if saved ~= true then
            if player.addMoney(Config.Price, 'Haircut Refund') ~= true then
                print(('[esx_barbershop] Refund failed for %s'):format(identifier))
            end
        elseif ESX.GetPlayerFromId(source) == player then
            TriggerClientEvent('esx:showNotification', source, TranslateCap('you_paid', ESX.Math.GroupDigits(Config.Price)))
        end

        player.endAccountOperation()
        cb(saved == true)
    end

    payments[identifier] = finish

    local ok, accepted = pcall(function()
        return exports.esx_skin:SaveSkin(source, skin, finish, 'barber')
    end)

    if not ok or accepted == false then finish(false) end
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
        if type(finish) == 'function' then finish(false) end
    end
end)
