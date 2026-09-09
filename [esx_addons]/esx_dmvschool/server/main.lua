-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local PaidTests = {}
local PaidTestDuration = 15 * 60 * 1000

local function isValidTestType(type)
	return type and Config.Prices[type] ~= nil and (type == 'dmv' or Config.VehicleModels[type] ~= nil)
end

local function getPlayerCoords(source)
	local ped = GetPlayerPed(source)
	if ped <= 0 then return nil end

	return GetEntityCoords(ped)
end

local function isNearPosition(source, position, distance)
	local coords = getPlayerCoords(source)
	if not coords or not position then return false end

	return #(coords - vector3(position.x, position.y, position.z)) <= distance
end

local function isNearDmv(source)
	return isNearPosition(source, Config.Zones.DMVSchool.Pos, 20.0)
end

local function isNearFinish(source)
	local checkpoint = Config.CheckPoints[#Config.CheckPoints]

	return checkpoint and isNearPosition(source, checkpoint.Pos, 35.0)
end

xLib.callback.registerCompat('esx_dmvschool:canYouPay', function(source, cb, type)
	local xPlayer = ESX.Player(source)
	type = tostring(type or '')

	if not xPlayer or not isValidTestType(type) or not isNearDmv(source) then
		return cb(false)
	end

	local price = Config.Prices[type]
	TriggerEvent('esx_license:checkLicense', source, type, function(hasLicense)
		if hasLicense or xPlayer.getMoney() < price then return cb(false) end

		xPlayer.removeMoney(price, "DMV Purchase")
		PaidTests[source] = PaidTests[source] or {}
		PaidTests[source][type] = GetGameTimer() + PaidTestDuration

		TriggerClientEvent('esx:showNotification', source, TranslateCap('you_paid', price))
		cb(true)
	end)
end)

AddEventHandler('esx:playerLoaded', function(source)
	TriggerEvent('esx_license:getLicenses', source, function(licenses)
		TriggerClientEvent('esx_dmvschool:loadLicenses', source, licenses)
	end)
end)

RegisterNetEvent('esx_dmvschool:addLicense')
AddEventHandler('esx_dmvschool:addLicense', function(type)
	local source = source
	type = tostring(type or '')
	local paidTest = PaidTests[source] and PaidTests[source][type]

	if not isValidTestType(type) or not paidTest or paidTest < GetGameTimer() then
		return
	end

	if type == 'dmv' and not isNearDmv(source) then return end
	if type ~= 'dmv' and not isNearFinish(source) then return end

	PaidTests[source][type] = nil
	TriggerEvent('esx_license:addLicense', source, type, function()
		TriggerEvent('esx_license:getLicenses', source, function(licenses)
			TriggerClientEvent('esx_dmvschool:loadLicenses', source, licenses)
		end)
	end)
end)

AddEventHandler('esx:playerDropped', function(playerId)
	PaidTests[playerId] = nil
end)
