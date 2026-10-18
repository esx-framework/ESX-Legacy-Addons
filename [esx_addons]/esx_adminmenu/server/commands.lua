-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--  VEC2
local allowedPermissions = Helpers.getAllowedPermissions()

local function showActionError(result, showError)
	if result and result.success then
		return
	end

	showError((result and result.err) or TranslateCap("action_failed"))
end

-- Helper commands that copy a computed string to the clipboard all share the
-- same player/permission/ped guards; only the computed text differs.
local function registerCopyCommand(names, help, computeText)
	ESX.RegisterCommand(names, allowedPermissions, function(xPlayer, args, showError)
		if not xPlayer or xPlayer.source == 0 then
			showError(TranslateCap("invalid_player"))
			return
		end

		if not Helpers.hasFeaturePermission(xPlayer.source, "helperCommands") then
			showError(TranslateCap("no_permission_command"))
			return
		end

		local ped = GetPlayerPed(xPlayer.source)
		if ped == 0 then
			showError(TranslateCap("failed_get_player_ped"))
			return
		end

		local text, err = computeText(xPlayer, ped)
		if not text then
			showError(err or TranslateCap("action_failed"))
			return
		end

		TriggerClientEvent("esx-adminmenu:client:copyToClipboard", xPlayer.source, text)
	end, false, { help = help })
end

registerCopyCommand("vec2", TranslateCap("copy_position_as_vec2"), function(_, ped)
	local coords = GetEntityCoords(ped)
	return string.format("vec2(%.2f, %.2f)", coords.x, coords.y)
end)

registerCopyCommand("vec3", TranslateCap("copy_position_as_vec3"), function(_, ped)
	local coords = GetEntityCoords(ped)
	return string.format("vec3(%.2f, %.2f, %.2f)", coords.x, coords.y, coords.z)
end)

registerCopyCommand("vec4", TranslateCap("copy_position_as_vec4"), function(_, ped)
	local coords = GetEntityCoords(ped)
	return string.format("vec4(%.2f, %.2f, %.2f, %.2f)", coords.x, coords.y, coords.z, GetEntityHeading(ped))
end)

registerCopyCommand("heading", TranslateCap("copy_heading"), function(_, ped)
	return string.format("%.2f", GetEntityHeading(ped))
end)

registerCopyCommand({ "copycoords" }, TranslateCap("copy_coords_and_heading"), function(_, ped)
	local coords = GetEntityCoords(ped)
	local heading = GetEntityHeading(ped)
	return string.format("x = %.2f, y = %.2f, z = %.2f, heading = %.2f", coords.x, coords.y, coords.z, heading)
end)

registerCopyCommand({ "rot", "rotation" }, TranslateCap("copy_rotation"), function(_, ped)
	local rotation = GetEntityRotation(ped, 2)
	return string.format("vec3(%.2f, %.2f, %.2f)", rotation.x, rotation.y, rotation.z)
end)

registerCopyCommand({ "model", "entitymodel" }, TranslateCap("copy_ped_or_vehicle_model"), function(_, ped)
	local vehicle = GetVehiclePedIsIn(ped, false)
	local entity = vehicle ~= 0 and vehicle or ped
	return tostring(GetEntityModel(entity))
end)

registerCopyCommand({ "vehplate", "copyplate" }, TranslateCap("copy_vehicle_plate"), function(_, ped)
	local vehicle = GetVehiclePedIsIn(ped, false)
	if vehicle == 0 then
		return nil, TranslateCap("must_be_in_vehicle")
	end
	return ESX.Math.Trim(GetVehicleNumberPlateText(vehicle))
end)

ESX.RegisterCommand(
	{ "admin" },
	allowedPermissions,
	function(xPlayer, args, showError)
		if not xPlayer or xPlayer.source == 0 then
			showError(TranslateCap("invalid_player"))
			return
		end

		if not Helpers.hasPermission(xPlayer.source) then
			showError(TranslateCap("no_permission_open_menu"))
			return
		end

		TriggerClientEvent("esx-adminmenu:client:openAdminMenu", xPlayer.source)
	end,
	true,
	{
		help = TranslateCap("open_admin_menu"),
	}
)

ESX.RegisterCommand(
	{ "information" },
	allowedPermissions,
	function(xPlayer, args, showError)
		if not xPlayer or xPlayer.source == 0 then
			showError(TranslateCap("invalid_player"))
			return
		end

		if not Helpers.hasPermission(xPlayer.source) then
			showError(TranslateCap("no_permission_open_player_info"))
			return
		end

		if not Helpers.isOnline(args.playerId) then
			showError(TranslateCap("player_not_online"))
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
		help = TranslateCap("open_admin_dashboard_player_info"),
		arguments = {
			{ name = "playerId", help = TranslateCap("target_player_id"), type = "number" },
		},
	}
)

ESX.RegisterCommand(
	{ "refreshbans", "refreshbancache" },
	allowedPermissions,
	function(xPlayer, args, showError)
		if not xPlayer or xPlayer.source == 0 then
			showError(TranslateCap("invalid_player"))
			return
		end

		if not Helpers.hasFeaturePermission(xPlayer.source, "banManagement") then
			showError(TranslateCap("no_permission_refresh_ban_cache"))
			return
		end
		BanCache.load()
	end,
	true,
	{
		help = TranslateCap("refreshes_ban_cache"),
	}
)

ESX.RegisterCommand(
	{ "admincar" },
	allowedPermissions,
	function(xPlayer, args, showError)
		if not xPlayer or xPlayer.source == 0 then
			showError(TranslateCap("invalid_player"))
			return
		end

		if not Helpers.hasPermission(xPlayer.source) then
			showError(TranslateCap("insufficient_permissions"))
			return
		end

		if not Helpers.hasFeaturePermission(xPlayer.source, "vehicleOwnership") then
			showError(TranslateCap("no_permission_save_admin_vehicles"))
			return
		end

		local model = args and args.model or nil
		if type(model) == "string" then
			model = model:match("^%s*(.-)%s*$")
		end

		local ped = GetPlayerPed(xPlayer.source)
		local vehicle = GetVehiclePedIsIn(ped, false)

		if (not model or model == "") and (not vehicle or vehicle == 0) then
			showError(TranslateCap("must_be_in_vehicle"))
			return
		end

		if (not model or model == "") and GetPedInVehicleSeat(vehicle, -1) ~= ped then
			showError(TranslateCap("must_be_driver"))
			return
		end

		local plate = model and model ~= "" and Helpers.generatePlate() or ESX.Math.Trim(GetVehicleNumberPlateText(vehicle))

		if not plate or plate == "" or Helpers.isPlateTaken(plate) then
			plate = Helpers.generatePlate()
		end

		xLib.callback("esx-adminmenu:client:adminCarVehicleProps", xPlayer.source, function(props)
			if not props or type(props) ~= "table" then
				showError(TranslateCap("failed_get_vehicle_properties"))
				return
			end

			if Helpers.isPlateTaken(plate) then
				showError(TranslateCap("generated_plate_already_taken"))
				return
			end

			local currentVehicle = GetVehiclePedIsIn(ped, false)
			if currentVehicle ~= 0 then
				props.model = GetEntityModel(currentVehicle)
			end

			if not props.model then
				showError(TranslateCap("failed_validate_vehicle_model"))
				return
			end

			props.plate = plate

			local maxBytes = tonumber(Config.AdminLimits and Config.AdminLimits.MaxVehiclePropsBytes) or 16384
			local encoded = json.encode(props)
			if type(encoded) ~= "string" or #encoded > maxBytes then
				showError(TranslateCap("vehicle_properties_too_large"))
				return
			end

			MySQL.insert("INSERT INTO owned_vehicles (owner, plate, vehicle) VALUES (?, ?, ?)", {
				xPlayer.getIdentifier(),
				plate,
				encoded,
			}, function()
				xPlayer.showNotification(TranslateCap("vehicle_registered_to_you"))
			end)
		end, {
			model = model,
			plate = plate,
		})
	end,
	false,
	{
		help = TranslateCap("spawn_and_own_or_register_vehicle"),
		arguments = {
			{ name = "model", help = TranslateCap("vehicle_model_to_spawn"), type = "string" },
		},
	}
)

ESX.RegisterCommand({ "setmodel" }, allowedPermissions, function(xPlayer, args, showError)
	if not xPlayer or xPlayer.source == 0 then
		showError(TranslateCap("invalid_player"))
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
	help = TranslateCap("change_player_model"),
	arguments = {
		{ name = "playerId", help = TranslateCap("target_player_id"), type = "number" },
		{ name = "model",    help = TranslateCap("model_name"),       type = "string" },
	},
})

-- ADMINISTRATION COMMANDS

ESX.RegisterCommand({ "goto" }, allowedPermissions, function(xPlayer, args, showError)
	local result = Actions.Goto(xPlayer.source, { id = args.playerId })

	showActionError(result, showError)
end, true, {
	help = TranslateCap("teleport_to_player"),
	arguments = {
		{ name = "playerId", help = TranslateCap("target_player_id"), type = "number" },
	},
})

ESX.RegisterCommand({ "bring" }, allowedPermissions, function(xPlayer, args, showError)
	local result = Actions.Bring(xPlayer.source, { id = args.playerId })

	showActionError(result, showError)
end, true, {
	help = TranslateCap("bring_player_to_you"),
	arguments = {
		{ name = "playerId", help = TranslateCap("target_player_id"), type = "number" },
	},
})

ESX.RegisterCommand({ "spectate" }, allowedPermissions, function(xPlayer, args, showError)
	local result = Actions.Spectate(xPlayer.source, { id = args.playerId })

	showActionError(result, showError)
end, true, {
	help = TranslateCap("spectate_player"),
	arguments = {
		{ name = "playerId", help = TranslateCap("target_player_id"), type = "number" },
	},
})

ESX.RegisterCommand({ "stopspectate" }, allowedPermissions, function(xPlayer, args, showError)
	local result = Actions.StopSpectate(xPlayer.source)

	showActionError(result, showError)
end, true, {
	help = TranslateCap("stop_spectating"),
})

ESX.RegisterCommand({ "kick" }, allowedPermissions, function(xPlayer, args, showError)
	local result = Actions.Kick(xPlayer.source, {
		id = args.playerId,
		reason = args.reason,
	})

	showActionError(result, showError)
end, true, {
	help = TranslateCap("kick_player"),
	arguments = {
		{ name = "playerId", help = TranslateCap("target_player_id"), type = "number" },
		{ name = "reason",   help = TranslateCap("kick_reason"),      type = "string" },
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
	help = TranslateCap("ban_player"),
	arguments = {
		{ name = "playerId", help = TranslateCap("target_player_id"),    type = "number" },
		{ name = "duration", help = TranslateCap("duration_in_minutes"), type = "number" },
		{ name = "reason",   help = TranslateCap("ban_reason"),          type = "string" },
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
	help = TranslateCap("send_notification_to_player"),
	arguments = {
		{ name = "playerId", help = TranslateCap("target_player_id"),     type = "number" },
		{ name = "message",  help = TranslateCap("notification_message"), type = "string" },
		{ name = "type",     help = TranslateCap("notification_type"),    type = "string" },
		{ name = "duration", help = TranslateCap("duration_in_ms"),       type = "number" },
		{ name = "title",    help = TranslateCap("notification_title"),   type = "string" },
	},
})
