--  VEC2
local allowedPermissions = Helpers.getAllowedPermissions()

local function showActionError(result, showError)
	if result and result.success then
		return
	end

	showError((result and result.err) or "Action failed.")
end

ESX.RegisterCommand(
	"vec2",
	allowedPermissions,
	function(xPlayer, args, showError)
		if not xPlayer or xPlayer.source == 0 then
			showError("Invalid player.")
			return
		end

		if not Helpers.hasFeaturePermission(xPlayer.source, "helperCommands") then
			showError("You do not have permission to use this command.")
			return
		end

		local ped = GetPlayerPed(xPlayer.source)
		if ped == 0 then
			showError("Failed to get player ped.")
			return
		end

		local coords = GetEntityCoords(ped)

		local text = string.format("vec2(%.2f, %.2f)", coords.x, coords.y)

		TriggerClientEvent("esx-adminmenu:client:copyToClipboard", xPlayer.source, text)
	end,
	false,
	{
		help = "Copy your current position as vec2(x, y)",
	}
)

--  VEC3

ESX.RegisterCommand(
	"vec3",
	allowedPermissions,
	function(xPlayer, args, showError)
		if not xPlayer or xPlayer.source == 0 then
			showError("Invalid player.")
			return
		end

		if not Helpers.hasFeaturePermission(xPlayer.source, "helperCommands") then
			showError("You do not have permission to use this command.")
			return
		end

		local ped = GetPlayerPed(xPlayer.source)
		if ped == 0 then
			showError("Failed to get player ped.")
			return
		end

		local coords = GetEntityCoords(ped)

		local text = string.format("vec3(%.2f, %.2f, %.2f)", coords.x, coords.y, coords.z)

		TriggerClientEvent("esx-adminmenu:client:copyToClipboard", xPlayer.source, text)
	end,
	false,
	{
		help = "Copy your current position as vec3(x, y, z)",
	}
)

--  VEC4

ESX.RegisterCommand(
	"vec4",
	allowedPermissions,
	function(xPlayer, args, showError)
		if not xPlayer or xPlayer.source == 0 then
			showError("Invalid player.")
			return
		end

		if not Helpers.hasFeaturePermission(xPlayer.source, "helperCommands") then
			showError("You do not have permission to use this command.")
			return
		end

		local ped = GetPlayerPed(xPlayer.source)
		if ped == 0 then
			showError("Failed to get player ped.")
			return
		end

		local coords = GetEntityCoords(ped)
		local heading = GetEntityHeading(ped)

		local text = string.format("vec4(%.2f, %.2f, %.2f, %.2f)", coords.x, coords.y, coords.z, heading)

		TriggerClientEvent("esx-adminmenu:client:copyToClipboard", xPlayer.source, text)
	end,
	false,
	{
		help = "Copy your current position as vec4(x, y, z, heading)",
	}
)

ESX.RegisterCommand(
	"heading",
	allowedPermissions,
	function(xPlayer, args, showError)
		if not xPlayer or xPlayer.source == 0 then
			showError("Invalid player.")
			return
		end

		if not Helpers.hasFeaturePermission(xPlayer.source, "helperCommands") then
			showError("You do not have permission to use this command.")
			return
		end

		local ped = GetPlayerPed(xPlayer.source)
		if ped == 0 then
			showError("Failed to get player ped.")
			return
		end

		TriggerClientEvent("esx-adminmenu:client:copyToClipboard", xPlayer.source, string.format("%.2f", GetEntityHeading(ped)))
	end,
	false,
	{
		help = "Copy your current heading.",
	}
)

ESX.RegisterCommand(
	{ "coords", "copycoords" },
	allowedPermissions,
	function(xPlayer, args, showError)
		if not xPlayer or xPlayer.source == 0 then
			showError("Invalid player.")
			return
		end

		if not Helpers.hasFeaturePermission(xPlayer.source, "helperCommands") then
			showError("You do not have permission to use this command.")
			return
		end

		local ped = GetPlayerPed(xPlayer.source)
		if ped == 0 then
			showError("Failed to get player ped.")
			return
		end

		local coords = GetEntityCoords(ped)
		local heading = GetEntityHeading(ped)
		local text = string.format("x = %.2f, y = %.2f, z = %.2f, heading = %.2f", coords.x, coords.y, coords.z, heading)

		TriggerClientEvent("esx-adminmenu:client:copyToClipboard", xPlayer.source, text)
	end,
	false,
	{
		help = "Copy your current coordinates and heading as fields.",
	}
)

ESX.RegisterCommand(
	{ "rot", "rotation" },
	allowedPermissions,
	function(xPlayer, args, showError)
		if not xPlayer or xPlayer.source == 0 then
			showError("Invalid player.")
			return
		end

		if not Helpers.hasFeaturePermission(xPlayer.source, "helperCommands") then
			showError("You do not have permission to use this command.")
			return
		end

		local ped = GetPlayerPed(xPlayer.source)
		if ped == 0 then
			showError("Failed to get player ped.")
			return
		end

		local rotation = GetEntityRotation(ped, 2)
		local text = string.format("vec3(%.2f, %.2f, %.2f)", rotation.x, rotation.y, rotation.z)

		TriggerClientEvent("esx-adminmenu:client:copyToClipboard", xPlayer.source, text)
	end,
	false,
	{
		help = "Copy your current rotation as vec3(x, y, z).",
	}
)

ESX.RegisterCommand(
	{ "model", "entitymodel" },
	allowedPermissions,
	function(xPlayer, args, showError)
		if not xPlayer or xPlayer.source == 0 then
			showError("Invalid player.")
			return
		end

		if not Helpers.hasFeaturePermission(xPlayer.source, "helperCommands") then
			showError("You do not have permission to use this command.")
			return
		end

		local ped = GetPlayerPed(xPlayer.source)
		if ped == 0 then
			showError("Failed to get player ped.")
			return
		end

		local vehicle = GetVehiclePedIsIn(ped, false)
		local entity = vehicle ~= 0 and vehicle or ped

		TriggerClientEvent("esx-adminmenu:client:copyToClipboard", xPlayer.source, tostring(GetEntityModel(entity)))
	end,
	false,
	{
		help = "Copy your current ped or vehicle model hash.",
	}
)

ESX.RegisterCommand(
	{ "vehplate", "copyplate" },
	allowedPermissions,
	function(xPlayer, args, showError)
		if not xPlayer or xPlayer.source == 0 then
			showError("Invalid player.")
			return
		end

		if not Helpers.hasFeaturePermission(xPlayer.source, "helperCommands") then
			showError("You do not have permission to use this command.")
			return
		end

		local ped = GetPlayerPed(xPlayer.source)
		local vehicle = GetVehiclePedIsIn(ped, false)

		if vehicle == 0 then
			showError("You must be in a vehicle.")
			return
		end

		TriggerClientEvent("esx-adminmenu:client:copyToClipboard", xPlayer.source, ESX.Math.Trim(GetVehicleNumberPlateText(vehicle)))
	end,
	false,
	{
		help = "Copy the current vehicle plate.",
	}
)

ESX.RegisterCommand(
	{ "admin" },
	allowedPermissions,
	function(xPlayer, args, showError)
		if not xPlayer or xPlayer.source == 0 then
			showError("Invalid player.")
			return
		end

		if not Helpers.hasPermission(xPlayer.source) then
			showError("You do not have permission to open the admin menu.")
			return
		end

		TriggerClientEvent("esx-adminmenu:client:openAdminMenu", xPlayer.source)
	end,
	true,
	{
		help = "Opens the ESX Admin Menu",
	}
)

ESX.RegisterCommand(
	{ "information" },
	allowedPermissions,
	function(xPlayer, args, showError)
		if not xPlayer or xPlayer.source == 0 then
			showError("Invalid player.")
			return
		end

		if not Helpers.hasPermission(xPlayer.source) then
			showError("You do not have permission to open player information.")
			return
		end

		if not Helpers.isOnline(args.playerId) then
			showError("Player is not online.")
			return
		end

		TriggerClientEvent("esx-adminmenu:client:openInformation", xPlayer.source, {
			players = Helpers.getPlayerList(xPlayer.source) or {},
			selectedPlayerId = args.playerId,
			serverData = Helpers.getServerData(),
		})
	end,
	true,
	{
		help = "Open the admin dashboard directly to a player's information panel.",
		arguments = {
			{ name = "playerId", help = "Target player ID", type = "number" },
		},
	}
)

ESX.RegisterCommand(
	{ "refreshbans", "refreshbancache" },
	allowedPermissions,
	function(xPlayer, args, showError)
		if not xPlayer or xPlayer.source == 0 then
			showError("Invalid player.")
			return
		end

		if not Helpers.hasFeaturePermission(xPlayer.source, "banManagement") then
			showError("You do not have permission to refresh the ban cache.")
			return
		end
		BanCache.load()
	end,
	true,
	{
		help = "Refreshes the ban cache if manual changes were made to the database.",
	}
)

ESX.RegisterCommand(
	{ "admincar" },
	allowedPermissions,
	function(xPlayer, args, showError)
		if not xPlayer or xPlayer.source == 0 then
			showError("Invalid player.")
			return
		end

		if not Helpers.hasPermission(xPlayer.source) then
			showError("No permission.")
			return
		end

		if not Helpers.hasFeaturePermission(xPlayer.source, "vehicleOwnership") then
			showError("You do not have permission to save admin vehicles.")
			return
		end

		local model = args and args.model or nil
		if type(model) == "string" then
			model = model:match("^%s*(.-)%s*$")
		end

		local ped = GetPlayerPed(xPlayer.source)
		local vehicle = GetVehiclePedIsIn(ped, false)

		if (not model or model == "") and (not vehicle or vehicle == 0) then
			showError("You must be in a vehicle.")
			return
		end

		if (not model or model == "") and GetPedInVehicleSeat(vehicle, -1) ~= ped then
			showError("You must be the driver.")
			return
		end

		local plate = model and model ~= "" and Helpers.generatePlate() or ESX.Math.Trim(GetVehicleNumberPlateText(vehicle))

		if not plate or plate == "" or Helpers.isPlateTaken(plate) then
			plate = Helpers.generatePlate()
		end

		ESX.TriggerClientCallback(xPlayer.source, "esx-adminmenu:client:adminCarVehicleProps", function(props)
			if not props then
				showError("Failed to get vehicle properties.")
				return
			end

			if Helpers.isPlateTaken(plate) then
				showError("Generated plate was already taken. Try again.")
				return
			end

			local currentVehicle = GetVehiclePedIsIn(ped, false)
			if currentVehicle ~= 0 then
				props.model = GetEntityModel(currentVehicle)
			end

			if not props.model then
				showError("Failed to validate vehicle model.")
				return
			end

			props.plate = plate

			MySQL.insert("INSERT INTO owned_vehicles (owner, plate, vehicle) VALUES (?, ?, ?)", {
				xPlayer.getIdentifier(),
				plate,
				json.encode(props),
			}, function()
				Helpers.invalidateVehicles()
				xPlayer.showNotification("Vehicle registered to you.")
			end)
		end, {
			model = model,
			plate = plate,
		})
	end,
	false,
	{
		help = "Spawn and own a vehicle, or register the vehicle you are driving.",
		arguments = {
			{ name = "model", help = "Vehicle model to spawn (optional)", type = "string" },
		},
	}
)

ESX.RegisterCommand({ "setmodel" }, allowedPermissions, function(xPlayer, args, showError)
	if not xPlayer or xPlayer.source == 0 then
		showError("Invalid player.")
		return
	end

	local result = Actions.PlayerAction(xPlayer.source, {
		id = args.playerId,
		action = "setModel",
		payload = {
			model = args.model,
		},
	})

	showActionError(result, showError)
end, true, {
	help = "Change a player's model.",
	arguments = {
		{ name = "playerId", help = "Target player ID", type = "number" },
		{ name = "model", help = "Model name", type = "string" },
	},
})

-- ADMINISTRATION COMMANDS

ESX.RegisterCommand({ "goto" }, allowedPermissions, function(xPlayer, args, showError)
	local result = Actions.Goto(xPlayer.source, { id = args.playerId })

	showActionError(result, showError)
end, true, {
	help = "Teleport to a player.",
	arguments = {
		{ name = "playerId", help = "Target player ID", type = "number" },
	},
})

ESX.RegisterCommand({ "bring" }, allowedPermissions, function(xPlayer, args, showError)
	local result = Actions.Bring(xPlayer.source, { id = args.playerId })

	showActionError(result, showError)
end, true, {
	help = "Bring a player to you.",
	arguments = {
		{ name = "playerId", help = "Target player ID", type = "number" },
	},
})

ESX.RegisterCommand({ "spectate" }, allowedPermissions, function(xPlayer, args, showError)
	local result = Actions.Spectate(xPlayer.source, { id = args.playerId })

	showActionError(result, showError)
end, true, {
	help = "Spectate a player.",
	arguments = {
		{ name = "playerId", help = "Target player ID", type = "number" },
	},
})

ESX.RegisterCommand({ "stopspectate" }, allowedPermissions, function(xPlayer, args, showError)
	local result = Actions.StopSpectate(xPlayer.source)

	showActionError(result, showError)
end, true, {
	help = "Stop spectating.",
})

ESX.RegisterCommand({ "kick" }, allowedPermissions, function(xPlayer, args, showError)
	local result = Actions.Kick(xPlayer.source, {
		id = args.playerId,
		reason = args.reason,
	})

	showActionError(result, showError)
end, true, {
	help = "Kick a player.",
	arguments = {
		{ name = "playerId", help = "Target player ID", type = "number" },
		{ name = "reason", help = "Reason for kick", type = "string" },
	},
})

ESX.RegisterCommand({ "ban" }, allowedPermissions, function(xPlayer, args, showError)
	local result = Actions.Ban(xPlayer.source, {
		id = args.playerId,
		reason = args.reason,
		duration = args.duration,
	})

	showActionError(result, showError)
end, true, {
	help = "Ban a player.",
	arguments = {
		{ name = "playerId", help = "Target player ID", type = "number" },
		{ name = "duration", help = "Duration in minutes", type = "number" },
		{ name = "reason", help = "Reason for ban", type = "string" },
	},
})

ESX.RegisterCommand({ "notify" }, allowedPermissions, function(xPlayer, args, showError)
	local result = Actions.Notify(xPlayer.source, {
		id = args.playerId,
		notificationContent = args.message,
		notificationType = args.type,
		duration = args.duration,
		notificationTitle = args.title,
	})

	showActionError(result, showError)
end, true, {
	help = "Send a notification to a player.",
	arguments = {
		{ name = "playerId", help = "Target player ID", type = "number" },
		{ name = "message", help = "Notification message", type = "string" },
		{ name = "type", help = "Notification type (info, error, success)", type = "string" },
		{ name = "duration", help = "Duration in ms", type = "number" },
		{ name = "title", help = "Notification title", type = "string" },
	},
})
