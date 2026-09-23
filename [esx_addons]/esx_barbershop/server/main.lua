-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local function isNearBarberShop(source)
	local ped = GetPlayerPed(source)
	if ped <= 0 then return false end

	local coords = GetEntityCoords(ped)
	for i = 1, #Config.Shops do
		if #(coords - Config.Shops[i]) <= (Config.ShopDistance or 3.0) then
			return true
		end
	end

	return false
end

local function payHaircut(source)
	local xPlayer = ESX.Player(source)
		
	if not xPlayer then
		print(('^3[WARNING]^0 xPlayer for Id %s, couldn`t be found.'):format(source))
		return false
	end

	if not isNearBarberShop(source) or xPlayer.getMoney() < Config.Price then
		return false
	end

	xPlayer.removeMoney(Config.Price, "Haircut")
	TriggerClientEvent('esx:showNotification', source, TranslateCap('you_paid', ESX.Math.GroupDigits(Config.Price)))
	return true
end

RegisterNetEvent('esx_barbershop:pay', function()
	payHaircut(source)
end)

xLib.callback.registerCompat('esx_barbershop:pay', function(source, cb)
	cb(payHaircut(source))
end)

xLib.callback.registerCompat('esx_barbershop:checkMoney', function(source, cb)
	local xPlayer = ESX.Player(source)
		
	if not xPlayer then
		print(('^3[WARNING]^0 xPlayer for Id %s, couldn`t be found.'):format(source))
		return cb(false)
	end
		
	cb(isNearBarberShop(source) and xPlayer.getMoney() >= Config.Price)
end)
