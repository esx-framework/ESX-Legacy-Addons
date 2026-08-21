Helpers = {}

function Helpers.trim(value)
	if type(value) ~= "string" then
		return ""
	end

	return value:match("^%s*(.-)%s*$")
end

-- Consolidated RequestModel + poll helper.
-- opts = { timeout = <ms>, requireVehicle = <bool> }
-- Returns (hash) on success or (nil, errString) on failure.
function Helpers.loadModel(model, opts)
	opts = opts or {}

	local hash = model
	if type(model) == "string" then
		hash = joaat(model)
	end

	if not IsModelInCdimage(hash) or not IsModelValid(hash) then
		return nil, "invalid_model"
	end

	if opts.requireVehicle and not IsModelAVehicle(hash) then
		return nil, "invalid_model"
	end

	local timeout = tonumber(opts.timeout) or (Config.AdminMenu and Config.AdminMenu.ModelLoadTimeout) or 5000

	RequestModel(hash)
	local deadline = GetGameTimer() + timeout
	while not HasModelLoaded(hash) do
		Wait(0)
		if GetGameTimer() > deadline then
			return nil, "model_load_timeout"
		end
	end

	return hash
end

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
ESX.RegisterClientCallback("esx-adminmenu:client:adminCarVehicleProps", function(cb, data)
	data = data or {}
	local ped = PlayerPedId()
	local vehicle = GetVehiclePedIsIn(ped, false)
	local plate = data.plate

	if data.model and data.model ~= "" then
		local model = Helpers.loadModel(data.model, { requireVehicle = true })
		if not model then
			cb(nil)
			return
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

	local props = xLib.game.getVehicleProperties(vehicle)
	props.model = GetEntityModel(vehicle)
	props.plate = ESX.Math.Trim(GetVehicleNumberPlateText(vehicle))

	cb(props)
end)
