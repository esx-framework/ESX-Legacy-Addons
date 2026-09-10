-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local Vehicles
local Customs = {}
local purchaseLimiter = xLib.rateLimiter({
	capacity = 1,
	refill = 1,
	interval = Config.Workshop and Config.Workshop.PurchaseCooldown or 1500
})

local function normalizePlate(plate)
	return xLib.vehiclePlate.normalize(plate, {
		maxLength = 0,
		uppercase = false
	})
end

local function isNearCustoms(source)
	local ped = GetPlayerPed(source)
	if not ped or ped == 0 then
		return false
	end

	local coords = GetEntityCoords(ped)
	for _, zone in pairs(Config.Zones) do
		if zone.Pos and #(coords - zone.Pos) <= 12.0 then
			return true
		end
	end

	return false
end

local function getCurrentVehicle(source)
	local ped = GetPlayerPed(source)
	if not ped or ped == 0 then
		return nil
	end

	local vehicle = GetVehiclePedIsIn(ped, false)
	if not vehicle or vehicle == 0 then
		return nil
	end

	return vehicle
end

local function getSession(source, plate)
	local sourceSessions = Customs[tostring(source)]
	return sourceSessions and sourceSessions[plate]
end

local function getVehicleBasePrice(model)
	if not Vehicles then
		Vehicles = MySQL.query.await('SELECT model, price FROM vehicles')
	end

	for i = 1, #Vehicles do
		if joaat(Vehicles[i].model) == model then
			return tonumber(Vehicles[i].price) or 50000
		end
	end

	return 50000
end

local function getPaymentDeadline()
	return os.time() + 45
end

local function decodeVehicleProps(vehicleJson)
	if type(vehicleJson) ~= 'string' then return nil end

	local ok, props = pcall(json.decode, vehicleJson)
	if not ok or type(props) ~= 'table' then return nil end

	return props
end

local function getOwnershipConfig()
	return Config.Workshop and Config.Workshop.Ownership or {}
end

local function isMechanic(xPlayer)
	local job = xPlayer and xPlayer.getJob()
	return job and job.name == 'mechanic'
end

local function canSaveOwnedVehicle(xPlayer, owner)
	if owner == xPlayer.getIdentifier() then
		return true
	end

	local ownership = getOwnershipConfig()
	return ownership.AllowMechanicCustomerVehicles == true and isMechanic(xPlayer)
end

local function getOwnedVehicleRecord(plate, model)
	local result = MySQL.single.await('SELECT owner, vehicle FROM owned_vehicles WHERE plate = ?', {plate})
	if not result then return nil, 'owner' end

	local storedProps = decodeVehicleProps(result.vehicle)
	if not storedProps or tonumber(storedProps.model) ~= model then
		return nil, 'model'
	end

	result.props = storedProps
	return result
end

local function validateRequiredOwnership(xPlayer, plate, model)
	local ownership = getOwnershipConfig()
	if ownership.RequireOwned ~= true then
		return true
	end

	local record, reason = getOwnedVehicleRecord(plate, model)
	if not record then
		return false, reason
	end

	if not canSaveOwnedVehicle(xPlayer, record.owner) then
		return false, 'owner'
	end

	return true
end

local function sendCartResult(source, success, message)
	TriggerClientEvent('esx_lscustom:cartPurchaseResult', source, {
		success = success,
		message = message
	})
end

RegisterNetEvent('esx_lscustom:startModing', function(props, netId)
	local src = tostring(source)
	local xPlayer = ESX.Player(source)

	local model = type(props) == 'table' and tonumber(props.model)
	if not xPlayer or type(props) ~= 'table' or not model or not netId or not isNearCustoms(source) then
		return
	end

	props.plate = normalizePlate(props.plate)
	if not props.plate then
		return
	end

	local vehicle = getCurrentVehicle(source)
	if not vehicle or GetEntityModel(vehicle) ~= model or normalizePlate(GetVehicleNumberPlateText(vehicle) or '') ~= props.plate then
		return
	end

	if Config.IsMechanicJobOnly and xPlayer.getJob().name ~= 'mechanic' then
		return
	end

	if Customs[src] then
		Customs[src][props.plate] = {props = props, netId = netId}
	else
		Customs[src] = {}
		Customs[src][props.plate] = {props = props, netId = netId}
	end
end)

RegisterNetEvent('esx_lscustom:stopModing', function(plate)
	local src = tostring(source)
	if not plate then return end
	plate = normalizePlate(plate)
	if not plate then return end
	if Customs[src] then
		Customs[src][plate] = nil
	end
end)

RegisterNetEvent('esx_lscustom:buyCart', function(payload, netId)
	local source = source
	local xPlayer = ESX.Player(source)

	if not xPlayer then return print('^3[WARNING]^0 The player could\'nt be found.') end
	if Config.IsMechanicJobOnly and xPlayer.getJob().name ~= 'mechanic' then return end
	if type(payload) ~= 'table' or type(payload.vehicleProps) ~= 'table' then
		return sendCartResult(source, false, TranslateCap('purchase_invalid'))
	end

	local allowed = purchaseLimiter:consume(source)
	if not allowed then
		return sendCartResult(source, false, TranslateCap('purchase_wait'))
	end

	local vehicleProps = payload.vehicleProps
	vehicleProps.plate = normalizePlate(vehicleProps.plate)
	local model = tonumber(vehicleProps.model)
	local vehicle = getCurrentVehicle(source)

	if not vehicleProps.plate or not model or not netId or not vehicle or not isNearCustoms(source) then
		return sendCartResult(source, false, TranslateCap('workshop_session_invalid'))
	end

	if GetEntityModel(vehicle) ~= model or normalizePlate(GetVehicleNumberPlateText(vehicle) or '') ~= vehicleProps.plate then
		return sendCartResult(source, false, TranslateCap('vehicle_session_mismatch'))
	end

	local session = getSession(source, vehicleProps.plate)
	if not session or session.netId ~= netId then
		return sendCartResult(source, false, TranslateCap('workshop_session_missing'))
	end

	local validOwnership, ownershipError = validateRequiredOwnership(xPlayer, vehicleProps.plate, model)
	if not validOwnership then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to buy LS Customs changes for a blocked vehicle (^5%s^7)'):format(source, tostring(ownershipError)))
		return sendCartResult(source, false, TranslateCap('workshop_session_invalid'))
	end

	local total = WorkshopPricing.CalculateCartTotal(payload.cart, getVehicleBasePrice(model))
	if not total or total <= 0 then
		return sendCartResult(source, false, TranslateCap('no_valid_changes'))
	end

	local validProps, invalidProp = WorkshopValidation.VehiclePropsMatchPaidCart(session.props, vehicleProps, payload.cart)
	if not validProps then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to save unpaid LS Customs property ^5%s^7'):format(source, tostring(invalidProp)))
		return sendCartResult(source, false, TranslateCap('purchase_invalid_changes'))
	end

	local validValues, invalidValue = WorkshopValidation.CartValuesMatchVehicleProps(vehicleProps, payload.cart)
	if not validValues then
		print(('[^3WARNING^7] Player ^5%s^7 attempted LS Customs cart mismatch on ^5%s^7'):format(source, tostring(invalidValue)))
		return sendCartResult(source, false, TranslateCap('purchase_vehicle_mismatch'))
	end

	if Config.IsMechanicJobOnly then
		local societyAccount

		TriggerEvent('esx_addonaccount:getSharedAccount', 'society_mechanic', function(account)
			societyAccount = account
		end)

		if societyAccount and total <= societyAccount.money then
			societyAccount.removeMoney(total)
			session.paidUntil = getPaymentDeadline()
			session.paidProps = vehicleProps
			sendCartResult(source, true, TranslateCap('tuning_applied', Config.Currency or '$', ESX.Math.GroupDigits(total)))
		else
			sendCartResult(source, false, TranslateCap('not_enough_money'))
		end
	elseif total <= xPlayer.getMoney() then
		xPlayer.removeMoney(total, "LSC Purchase")
		session.paidUntil = getPaymentDeadline()
		session.paidProps = vehicleProps
		sendCartResult(source, true, TranslateCap('tuning_applied', Config.Currency or '$', ESX.Math.GroupDigits(total)))
	else
		sendCartResult(source, false, TranslateCap('not_enough_money'))
	end
end)

AddEventHandler('esx:playerDropped', function(src)
    src = tostring(src)
	local playersCount = #GetPlayers()
    if Customs[src] then
        for k, v in pairs(Customs[src]) do
            local entity = NetworkGetEntityFromNetworkId(v.netId)
            if DoesEntityExist(entity) then
                if playersCount > 0 then
                    TriggerClientEvent('esx_lscustom:restoreMods', -1, v.netId, v.props)
                else
                    DeleteEntity(entity)
                end
            end
        end
        Customs[src] = nil
    end
end)

RegisterNetEvent('esx_lscustom:buyMod', function()
	local source = source
	local xPlayer = ESX.Player(source)
	if not xPlayer then return print('^3[WARNING]^0 The player could\'nt be found.') end
	print(('[^3WARNING^7] Player ^5%s^7 attempted to use deprecated LS Customs buyMod event'):format(source))
	TriggerClientEvent('esx_lscustom:cancelInstallMod', source)
end)

RegisterNetEvent('esx_lscustom:refreshOwnedVehicle', function(vehicleProps, netId)
	local src = tostring(source)
	local xPlayer = ESX.Player(source)

  if not vehicleProps then return print('^3[WARNING]^0 The vehicle Props could\'nt be found.') end
  if not vehicleProps.plate then return print('^3[WARNING]^0 The vehicle plate could\'nt be found.') end
  if not vehicleProps.model then return print('^3[WARNING]^0 The vehicle model could\'nt be found.') end

  if not xPlayer then return print('^3[WARNING]^0 The player could\'nt be found.') end
  if Config.IsMechanicJobOnly and xPlayer.getJob().name ~= 'mechanic' then return end

	vehicleProps.plate = normalizePlate(vehicleProps.plate)
	local model = tonumber(vehicleProps.model)
	if not vehicleProps.plate or not model or not isNearCustoms(source) then return end

	local session = getSession(source, vehicleProps.plate)
	if not session or session.netId ~= netId or not session.paidUntil or session.paidUntil < os.time() then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to save LS Customs changes without a valid payment'):format(source))
		return
	end

	if Config.Workshop and Config.Workshop.UseCart then
		local validPaidProps, invalidPaidProp = WorkshopValidation.WatchedVehiclePropsEqual(session.paidProps, vehicleProps)
		if not validPaidProps then
			print(('[^3WARNING^7] Player ^5%s^7 attempted to save unpaid LS Customs property ^5%s^7'):format(source, tostring(invalidPaidProp)))
			return
		end
	end

	local currentVehicle = getCurrentVehicle(source)
	if not currentVehicle or GetEntityModel(currentVehicle) ~= model or normalizePlate(GetVehicleNumberPlateText(currentVehicle) or '') ~= vehicleProps.plate then
		return
	end

	local ownership = getOwnershipConfig()
	local record = getOwnedVehicleRecord(vehicleProps.plate, model)
	local shouldSaveOwnedVehicle = ownership.SaveOwnedVehicles ~= false and record and canSaveOwnedVehicle(xPlayer, record.owner)

	if ownership.RequireOwned == true and not shouldSaveOwnedVehicle then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to save LS Customs changes for a blocked vehicle'):format(source))
		return
	end

	if shouldSaveOwnedVehicle then
		MySQL.update('UPDATE owned_vehicles SET vehicle = ? WHERE owner = ? AND plate = ?', {json.encode(vehicleProps), record.owner, vehicleProps.plate})
	end

	session.paidUntil = nil
	session.paidProps = nil
	if Customs[src] then
		if Customs[src][tostring(vehicleProps.plate)] then
			Customs[src][tostring(vehicleProps.plate)].props = vehicleProps
		else
			Customs[src][tostring(vehicleProps.plate)] = {props = vehicleProps, netId = netId}
		end
	else
		Customs[src] = {}
		Customs[src][tostring(vehicleProps.plate)] = {props = vehicleProps, netId = netId}
	end

	local veh = NetworkGetEntityFromNetworkId(netId)
	if veh and veh ~= 0 and DoesEntityExist(veh) then
		local vehState = Entity(veh).state
		if vehState.VehicleProperties then
			vehState:set("VehicleProperties", vehicleProps, true)
		end
	end
end)

xLib.callback.registerCompat('esx_lscustom:getVehiclesPrices', function(source, cb)
	if not Vehicles then
		Vehicles = MySQL.query.await('SELECT model, price FROM vehicles')
	end
	cb(Vehicles)
end)
