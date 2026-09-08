local Vehicles
local Customs = {}

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
	plate = normalizePlate(plate)
	if Customs[src] then
		Customs[src][plate] = nil
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

RegisterNetEvent('esx_lscustom:buyMod', function(price)
	local source = source
	local xPlayer = ESX.Player(source)
	local vehicle = getCurrentVehicle(source)
	local plate = vehicle and normalizePlate(GetVehicleNumberPlateText(vehicle) or '')
	local session = plate and getSession(source, plate)

	if not xPlayer then return print('^3[WARNING]^0 The player could\'nt be found.') end
	if Config.IsMechanicJobOnly and xPlayer.getJob().name ~= 'mechanic' then return end
	if not vehicle or not session or not isNearCustoms(source) then return end

	price = ESX.Math.Round(tonumber(price) or 0)
	local vehiclePrice = getVehicleBasePrice(GetEntityModel(vehicle))
	local minPrice = math.max(1, math.floor(vehiclePrice * 0.0025))
	local maxPrice = math.max(100000, math.floor(vehiclePrice * 1.5))
	if price < minPrice or price > maxPrice then
		print(('[^3WARNING^7] Player ^5%s^7 attempted invalid LS Customs price ^5%s^7!'):format(source, tostring(price)))
		return
	end

	if Config.IsMechanicJobOnly then
		local societyAccount

		TriggerEvent('esx_addonaccount:getSharedAccount', 'society_mechanic', function(account)
			societyAccount = account
		end)

		if societyAccount and price <= societyAccount.money then
			TriggerClientEvent('esx_lscustom:installMod', source)
			TriggerClientEvent('esx:showNotification', source, TranslateCap('purchased'))
			societyAccount.removeMoney(price)
			session.paidUntil = os.clock() + 45
		else
			TriggerClientEvent('esx_lscustom:cancelInstallMod', source)
			TriggerClientEvent('esx:showNotification', source, TranslateCap('not_enough_money'))
		end
	else
		if price <= xPlayer.getMoney() then
			TriggerClientEvent('esx_lscustom:installMod', source)
			TriggerClientEvent('esx:showNotification', source, TranslateCap('purchased'))
			xPlayer.removeMoney(price, "LSC Purchase")
			session.paidUntil = os.clock() + 45
		else
			TriggerClientEvent('esx_lscustom:cancelInstallMod', source)
			TriggerClientEvent('esx:showNotification', source, TranslateCap('not_enough_money'))
		end
	end
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
	if not session or session.netId ~= netId or not session.paidUntil or session.paidUntil < os.clock() then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to save LS Customs changes without a valid payment'):format(source))
		return
	end

	local currentVehicle = getCurrentVehicle(source)
	if not currentVehicle or GetEntityModel(currentVehicle) ~= model or normalizePlate(GetVehicleNumberPlateText(currentVehicle) or '') ~= vehicleProps.plate then
		return
	end

	MySQL.single('SELECT owner, vehicle FROM owned_vehicles WHERE owner = ? AND plate = ?', {xPlayer.getIdentifier(), vehicleProps.plate},
	function(result)
		if result then
			local vehicle = json.decode(result.vehicle)
			if tonumber(vehicleProps.model) == tonumber(vehicle.model) then
				MySQL.update('UPDATE owned_vehicles SET vehicle = ? WHERE owner = ? AND plate = ?', {json.encode(vehicleProps), xPlayer.getIdentifier(), vehicleProps.plate})
				session.paidUntil = nil
				if Customs[src] then
					if Customs[src][tostring(vehicleProps.plate)]  then
						Customs[src][tostring(vehicleProps.plate)].props = vehicleProps
					else
						Customs[src][tostring(vehicleProps.plate)] = {props = vehicleProps, netId = netId}
					end
				else
					Customs[src] = {}
					Customs[src][tostring(vehicleProps.plate)] = {props = vehicleProps, netId = netId}
				end
        local veh = NetworkGetEntityFromNetworkId(netId)
				local Veh_State = Entity(veh).state.VehicleProperties
				if Veh_State then
					Entity(veh).state:set("VehicleProperties", vehicleProps, true)
        end
			else
				print(('[^3WARNING^7] Player ^5%s^7 Attempted To upgrade with mismatching vehicle model'):format(xPlayer.src))
			end
		end
	end)
end)

xLib.callback.registerCompat('esx_lscustom:getVehiclesPrices', function(source, cb)
	if not Vehicles then
		Vehicles = MySQL.query.await('SELECT model, price FROM vehicles')
	end
	cb(Vehicles)
end)
