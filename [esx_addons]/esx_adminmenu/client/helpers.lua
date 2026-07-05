Helpers = {}

function Helpers.resolveVehicleName(hash)
	if not hash then
		return "Unknown"
	end

	local display = GetDisplayNameFromVehicleModel(hash)
	if not display or display == "CARNOTFOUND" then
		return tostring(hash)
	end

	local label = GetLabelText(display)
	if label and label ~= "NULL" then
		return label
	end

	return display
end

-- Callback helper for the /admincar command.
ESX.RegisterClientCallback("esx-adminmenu:client:getVehicleProps", function(cb)
	local ped = PlayerPedId()
	local vehicle = GetVehiclePedIsIn(ped, false)

	if vehicle == 0 then
		cb(nil)
		return
	end

	local props = ESX.Game.GetVehicleProperties(vehicle)
	cb(props)
end)

ESX.RegisterClientCallback("esx-adminmenu:client:adminCarVehicleProps", function(cb, data)
	data = data or {}
	local ped = PlayerPedId()
	local vehicle = GetVehiclePedIsIn(ped, false)
	local plate = data.plate

	if data.model and data.model ~= "" then
		local model = joaat(data.model)
		if not IsModelInCdimage(model) or not IsModelAVehicle(model) then
			cb(nil)
			return
		end

		RequestModel(model)
		local timeout = GetGameTimer() + 5000
		while not HasModelLoaded(model) do
			Wait(0)
			if GetGameTimer() > timeout then
				cb(nil)
				return
			end
		end

		local coords = GetEntityCoords(ped)
		local heading = GetEntityHeading(ped)
		vehicle = CreateVehicle(model, coords.x, coords.y, coords.z, heading, true, false)
		SetEntityAsMissionEntity(vehicle, true, true)
		SetVehicleOnGroundProperly(vehicle)
		SetPedIntoVehicle(ped, vehicle, -1)
		SetModelAsNoLongerNeeded(model)
	end

	if vehicle == 0 then
		cb(nil)
		return
	end

	if plate and plate ~= "" then
		SetVehicleNumberPlateText(vehicle, plate)
	end

	local props = ESX.Game.GetVehicleProperties(vehicle)
	props.model = GetEntityModel(vehicle)
	props.plate = ESX.Math.Trim(GetVehicleNumberPlateText(vehicle))

	cb(props)
end)
