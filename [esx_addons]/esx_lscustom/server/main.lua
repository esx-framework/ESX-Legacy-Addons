-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local Vehicles
local VehiclesSignature
local VehiclePricesRefreshInterval = 600000
local Customs = {}
local PurchasingPlayers, PurchasingPlates = {}, {}
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

local function isCurrentVehicleNetId(source, netId)
	local vehicle = getCurrentVehicle(source)
	netId = tonumber(netId)
	return vehicle ~= nil and netId ~= nil and NetworkGetEntityFromNetworkId(netId) == vehicle
end

local function getSession(source, plate)
	local sourceSessions = Customs[tostring(source)]
	return sourceSessions and sourceSessions[plate]
end

local function loadVehiclePrices()
	MySQL.query('SELECT model, price FROM vehicles ORDER BY model', function(result)
		if type(result) ~= 'table' then return end

		local signature = json.encode(result)
		if signature == VehiclesSignature then return end

		Vehicles = result
		VehiclesSignature = signature
		TriggerClientEvent('esx_lscustom:setVehiclesPrices', -1, Vehicles)
	end)
end

MySQL.ready(function()
	while true do
		loadVehiclePrices()
		Wait(VehiclePricesRefreshInterval)
	end
end)

local function getVehicleBasePrice(model)
	if not Vehicles then
		return nil
	end

	for i = 1, #Vehicles do
		if joaat(Vehicles[i].model) == model then
			return tonumber(Vehicles[i].price) or 50000
		end
	end

	return 50000
end

local function getPaidCartProps(cart)
	local paid = {}
	if type(cart) ~= 'table' then return paid end

	for i = 1, #cart do
		local normalized = WorkshopPricing.NormalizeCartItem(cart[i])
		if normalized then
			local modType = normalized.modType
			paid[modType] = true

			if modType == 'modFrontWheels' or modType == 'modBackWheels' then
				paid.wheels = true
			elseif modType == 'neonColor' then
				paid.neonEnabled = true
			elseif modType == 'tyreSmokeColor' then
				paid.modSmokeEnabled = true
			elseif modType == 'xenonColor' then
				paid.modXenon = true
			end
		end
	end

	return paid
end

local function restoreUnpaidWatchedProps(vehicleProps, originalProps, paidProps)
	if type(vehicleProps) ~= 'table' or type(originalProps) ~= 'table' then return end

	local watchedProps = WorkshopValidation.GetWatchedVehicleProps()
	for watchedKey in pairs(watchedProps) do
		if not paidProps[watchedKey] then
			vehicleProps[watchedKey] = originalProps[watchedKey]
		end
	end
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

local function isExtendedVehicleEntity(vehicle, plate, storedPlate)
	local xVehicle = ESX.GetExtendedVehicleFromPlate(storedPlate)
	if not xVehicle and storedPlate ~= plate then
		xVehicle = ESX.GetExtendedVehicleFromPlate(plate)
	end

	return not xVehicle or xVehicle:getEntity() == vehicle
end

local function canSaveOwnedVehicle(xPlayer, record, plate, vehicle)
	if record.owner == xPlayer.getIdentifier() then
		return true
	end

	local ownership = getOwnershipConfig()
	return ownership.AllowMechanicCustomerVehicles == true and isMechanic(xPlayer) and isExtendedVehicleEntity(vehicle, plate, record.plate)
end

local function getOwnedVehicleRecord(plate, model)
	local result = MySQL.single.await('SELECT owner, plate, vehicle FROM owned_vehicles WHERE plate = ?', {plate})
	if not result then return nil, 'owner' end

	local storedProps = decodeVehicleProps(result.vehicle)
	if not storedProps or tonumber(storedProps.model) ~= model then
		return nil, 'model'
	end

	result.props = storedProps
	return result
end

local function getPurchaseSession(source, xPlayer, plate, model, netId)
	if Config.IsMechanicJobOnly and not isMechanic(xPlayer) then
		return nil, 'workshop_session_invalid'
	end

	local vehicle = getCurrentVehicle(source)
	if not vehicle or not isNearCustoms(source) then
		return nil, 'workshop_session_invalid'
	end

	if GetEntityModel(vehicle) ~= model or normalizePlate(GetVehicleNumberPlateText(vehicle) or '') ~= plate then
		return nil, 'vehicle_session_mismatch'
	end

	local session = getSession(source, plate)
	if not session or session.netId ~= netId or not isCurrentVehicleNetId(source, netId) then
		return nil, 'workshop_session_missing'
	end

	return session, nil, vehicle
end

local function chargeCartPurchase(xPlayer, total)
	if Config.IsMechanicJobOnly then
		local societyAccount

		TriggerEvent('esx_addonaccount:getSharedAccount', 'society_mechanic', function(account)
			societyAccount = account
		end)

		if not societyAccount or total > societyAccount.money then
			return false
		end

		societyAccount.removeMoney(total)
		return true
	end

	if total > xPlayer.getMoney() then
		return false
	end

	xPlayer.removeMoney(total, "LSC Purchase")
	return true
end

local function prepareCartPurchase(source, payload, netId)
	local xPlayer = ESX.Player(source)

	if not xPlayer then
		print('^3[WARNING]^0 The player could\'nt be found.')
		return nil, 'purchase_invalid'
	end

	if type(payload) ~= 'table' or type(payload.vehicleProps) ~= 'table' then
		return nil, 'purchase_invalid'
	end

	if not purchaseLimiter:consume(source) then
		return nil, 'purchase_wait'
	end

	local vehicleProps = payload.vehicleProps
	vehicleProps.plate = normalizePlate(vehicleProps.plate)
	local model = tonumber(vehicleProps.model)

	if not vehicleProps.plate or not model or not netId then
		return nil, 'workshop_session_invalid'
	end

	local session, sessionError = getPurchaseSession(source, xPlayer, vehicleProps.plate, model, netId)
	if not session then
		return nil, sessionError
	end

	local basePrice = getVehicleBasePrice(model)
	if not basePrice then
		return nil, 'purchase_wait'
	end

	local total = WorkshopPricing.CalculateCartTotal(payload.cart, basePrice)
	if not total or total <= 0 then
		return nil, 'no_valid_changes'
	end

	return {
		cart = payload.cart,
		vehicleProps = vehicleProps,
		plate = vehicleProps.plate,
		model = model,
		netId = netId,
		total = total
	}
end

local function completeCartPurchase(source, purchase)
	local record, recordError = getOwnedVehicleRecord(purchase.plate, purchase.model)

	local xPlayer = ESX.Player(source)
	if not xPlayer then
		return false, TranslateCap('purchase_invalid')
	end

	local session, sessionError, vehicle = getPurchaseSession(source, xPlayer, purchase.plate, purchase.model, purchase.netId)
	if not session then
		return false, TranslateCap(sessionError)
	end

	local ownership = getOwnershipConfig()
	local canSave = record and canSaveOwnedVehicle(xPlayer, record, purchase.plate, vehicle)

	if ownership.RequireOwned == true and not canSave then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to buy LS Customs changes for a blocked vehicle (^5%s^7)'):format(source, tostring(record and 'owner' or recordError)))
		return false, TranslateCap('workshop_session_invalid')
	end

	local vehicleProps = purchase.vehicleProps
	local referenceProps = record and record.props or session.props
	local paidKeys = getPaidCartProps(purchase.cart)

	restoreUnpaidWatchedProps(vehicleProps, referenceProps, paidKeys)

	local validProps, invalidProp = WorkshopValidation.VehiclePropsMatchPaidCart(referenceProps, vehicleProps, purchase.cart)
	if not validProps then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to save unpaid LS Customs property ^5%s^7'):format(source, tostring(invalidProp)))
		return false, TranslateCap('purchase_invalid_changes')
	end

	local validValues, invalidValue = WorkshopValidation.CartValuesMatchVehicleProps(vehicleProps, purchase.cart, referenceProps)
	if not validValues then
		print(('[^3WARNING^7] Player ^5%s^7 attempted LS Customs cart mismatch on ^5%s^7'):format(source, tostring(invalidValue)))
		return false, TranslateCap('purchase_vehicle_mismatch')
	end

	if not chargeCartPurchase(xPlayer, purchase.total) then
		return false, TranslateCap('not_enough_money')
	end

	local savedProps = vehicleProps
	if record then
		savedProps = record.props
		for key in pairs(paidKeys) do
			savedProps[key] = vehicleProps[key]
		end
	end

	if canSave and ownership.SaveOwnedVehicles ~= false then
		MySQL.update('UPDATE owned_vehicles SET vehicle = ? WHERE owner = ? AND plate = ?', {json.encode(savedProps), record.owner, purchase.plate})
	end

	Customs[tostring(source)][purchase.plate] = nil

	local vehState = Entity(vehicle).state
	if vehState.VehicleProperties then
		vehState:set("VehicleProperties", savedProps, true)
	end

	return true, TranslateCap('tuning_applied', Config.Currency or '$', ESX.Math.GroupDigits(purchase.total))
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

	if not isCurrentVehicleNetId(source, netId) then
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

xLib.callback.register('esx_lscustom:buyCart', function(source, payload, netId)
	local purchase, purchaseError = prepareCartPurchase(source, payload, netId)
	if not purchase then
		return false, TranslateCap(purchaseError)
	end

	if PurchasingPlayers[source] or PurchasingPlates[purchase.plate] then
		return false, TranslateCap('purchase_wait')
	end

	PurchasingPlayers[source] = true
	PurchasingPlates[purchase.plate] = true

	local ok, success, message = pcall(completeCartPurchase, source, purchase)

	PurchasingPlayers[source] = nil
	PurchasingPlates[purchase.plate] = nil

	if not ok then
		print(('[^1ERROR^7] LS Customs purchase failed for player ^5%s^7: %s'):format(source, tostring(success)))
		return false, TranslateCap('purchase_invalid')
	end

	return success, message
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

xLib.callback.registerCompat('esx_lscustom:getVehiclesPrices', function(source, cb)
	cb(Vehicles or {})
end)
