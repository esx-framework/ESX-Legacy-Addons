ESX.RegisterServerCallback("esx-adminmenu:server:getInitData", function(source, cb)
	if not Helpers.hasPermission(source) then
		cb({ error = "Insufficient Permissions." })
		return
	end

	local translations = Helpers.getTranslations()
	local impounds = Helpers.getImpounds()
	local vehicleConfig = Config.VehicleSpawner or {}

	cb({
		translations = translations, -- can be empty safely
		serverData = Helpers.getServerData(),
		impounds = impounds,
		vehicleConfig = {
			defaultModel = vehicleConfig.DefaultModel or "sultan",
			defaultColor = vehicleConfig.DefaultColor or "black",
			colorPresets = vehicleConfig.ColorPresets or {},
			neonPresets = vehicleConfig.NeonPresets or {},
			windowTints = vehicleConfig.WindowTints or {},
			wheelCategories = vehicleConfig.WheelCategories or {},
			wheelDesigns = vehicleConfig.WheelDesigns or {},
		},
	})
end)

ESX.RegisterServerCallback("esx-adminmenu:server:canOpen", function(source, cb)
	if not Helpers.hasPermission(source) then
		cb({ success = false, err = "Insufficient Permissions." })
		return
	end

	cb({
		success = true,
		serverData = Helpers.getServerData(),
	})
end)

ESX.RegisterServerCallback("esx-adminmenu:server:canUseAdminAction", function(source, cb, data)
	if not Helpers.hasPermission(source) then
		cb({ success = false, err = "Insufficient Permissions." })
		return
	end

	local action = type(data) == "table" and data.action or data
	if type(action) ~= "string" or action == "" then
		cb({ success = false, err = "Invalid admin action." })
		return
	end

	local actionPermissions = Config.AdminMenu and Config.AdminMenu.ActionPermissions or {}
	local feature = actionPermissions[action]

	if not feature then
		cb({ success = false, err = "Invalid admin action." })
		return
	end

	if feature and not Helpers.hasFeaturePermission(source, feature) then
		cb({ success = false, err = "Insufficient Permissions." })
		return
	end

	cb({
		success = true,
		serverData = Helpers.getServerData(),
	})
end)

ESX.RegisterServerCallback("esx-adminmenu:server:openDashboard", function(source, cb)
	if not Helpers.hasPermission(source) then
		cb({ success = false, err = "Insufficient Permissions." })
		return
	end

	cb({
		success = true,
		players = Helpers.getPlayerList(source) or {},
		serverData = Helpers.getServerData(),
	})
end)

ESX.RegisterServerCallback("esx-adminmenu:server:getVehicles", function(source, cb, data)
	if not Helpers.hasPermission(source) then
		cb({ success = false, err = "Insufficient Permissions." })
		return
	end

	local result = Helpers.getVehiclesPage(data)
	result.success = true

	cb(result)
end)

ESX.RegisterServerCallback("esx-adminmenu:server:getBans", function(source, cb, data)
	if not Helpers.hasFeaturePermission(source, "banManagement") then
		cb({ success = false, err = "Insufficient Permissions." })
		return
	end

	local result = Helpers.getActiveBansPage(data)
	result.success = true

	cb(result)
end)

ESX.RegisterServerCallback("esx-adminmenu:server:getRecentPlayers", function(source, cb)
	if not Helpers.hasPermission(source) then
		cb({ success = false, err = "Insufficient Permissions." })
		return
	end

	cb({
		success = true,
		players = Helpers.getRecentPlayers(source),
	})
end)

ESX.RegisterServerCallback("esx-adminmenu:server:getRadioChannelPlayers", function(source, cb, data)
	if not Helpers.hasFeaturePermission(source, "radioLookup") then
		cb({ success = false, err = "Insufficient Permissions." })
		return
	end

	local channel = tonumber(data and data.channel) or 0
	if channel <= 0 then
		cb({ success = false, err = "Enter a valid radio channel." })
		return
	end

	local players = {}
	local canSeeSensitive = Helpers.hasFeaturePermission(source, "sensitiveInfo")

	for _, playerSource in ipairs(GetPlayers()) do
		local targetId = tonumber(playerSource)

		if targetId and Helpers.getPlayerRadioChannel(targetId) == channel then
			local xPlayer = ESX.GetPlayerFromId(targetId)

			players[#players + 1] = {
				id = targetId,
				name = xPlayer and xPlayer.getName() or GetPlayerName(targetId) or "Unknown",
				char_identifier = canSeeSensitive and xPlayer and xPlayer.identifier or nil,
			}
		end
	end

	cb({ success = true, players = players })
end)

local MAX_RESULTS = 25

ESX.RegisterServerCallback("esx-adminmenu:server:searchOfflinePlayer", function(source, cb, data)
	local src = source

	if not Helpers.hasPermission(src) then
		cb({ err = "Insufficient Permissions" })
		return
	end

	local canSeeSensitive = Helpers.hasFeaturePermission(src, "sensitiveInfo")

	if not data or type(data.identifier) ~= "string" then
		cb({ players = {} })
		return
	end

	local inputIdentifier = data.identifier:match("^%s*(.-)%s*$")
	if inputIdentifier == "" then
		cb({ players = {} })
		return
	end

	if #inputIdentifier > 100 then
		cb({ players = {} })
		return
	end

	local function getBase(identifier)
		local base = identifier:match("^[^:]+:(.+)$")
		if not base or base == "" then
			return nil
		end
		if #base < 5 or #base > 80 then
			return nil
		end
		return base
	end

	local rows

	-- LICENSE SEARCH (In cases of license identifier being inputted)
	if inputIdentifier:match("^license:[%w%-_]+$") then
		local base = getBase(inputIdentifier)
		if not base then
			cb({ players = {} })
			return
		end

		rows = MySQL.query.await(
			[[SELECT identifier, firstname, lastname, sex, job, job_grade, accounts, metadata, last_seen
			FROM users
			WHERE SUBSTRING_INDEX(identifier, ':', -1) = ?
			LIMIT ?]],
			{ base, MAX_RESULTS + 1 }
		)

	-- CHAR SEARCH (In cases of char identifier being inputted)
	elseif inputIdentifier:match("^char%d+:[%w%-_]+$") then
		rows = MySQL.query.await(
			[[SELECT identifier, firstname, lastname, sex, job, job_grade, accounts, metadata, last_seen
			FROM users
			WHERE identifier = ?
			LIMIT ?]],
			{ inputIdentifier, MAX_RESULTS + 1 }
		)
	else
		cb({ players = {} })
		return
	end

	if not rows or #rows == 0 then
		cb({ players = {} })
		return
	end

	local players = {}

	for i = 1, #rows do
		if #players >= MAX_RESULTS then
			break
		end

		local r = rows[i]

		local base = getBase(r.identifier)
		if not base then
			goto continue
		end

		local accounts = {}
		if r.accounts then
			local ok, decoded = pcall(json.decode, r.accounts)
			if ok and type(decoded) == "table" then
				accounts = decoded
			end
		end

		local metadata = {}
		if r.metadata then
			local ok, decoded = pcall(json.decode, r.metadata)
			if ok and type(decoded) == "table" then
				metadata = decoded
			end
		end

		local health = metadata.health and metadata.health - 100 or 0
		local armor = metadata and metadata.armor or 0
		local playTime = Helpers.getFormattedPlayTime(metadata and metadata.lastPlaytime or 0)

		players[#players + 1] = {
			status = "offline",
			id = nil,
			name = (r.firstname or "") .. " " .. (r.lastname or ""),

			cash = tonumber(accounts.money) or 0,
			bank = tonumber(accounts.bank) or 0,
			alt_money = tonumber(accounts.black_money) or 0,

			health = health,
			armor = armor,

			char_identifier = canSeeSensitive and r.identifier or nil,
			identifier = canSeeSensitive and ("license:" .. base) or nil,

			play_time = playTime,
			gender = r.sex == "m" and "m" or "f",
			job = r.job,
			job_grade = r.job_grade,
			last_join = r.last_seen,
		}
		::continue::
	end

	cb({ players = players })
end)
