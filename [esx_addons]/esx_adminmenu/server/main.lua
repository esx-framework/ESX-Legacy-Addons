Helpers.registerCallback("esx-adminmenu:server:getInitData", function(source)
	if not Helpers.hasPermission(source) then
		return { err = "Insufficient Permissions." }
	end

	local translations = Helpers.getTranslations()
	local impounds = Helpers.getImpounds()
	local vehicleConfig = Config.VehicleSpawner or {}

	return {
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
	}
end)

Helpers.registerCallback("esx-adminmenu:server:canOpen", function(source)
	if not Helpers.hasPermission(source) then
		return { success = false, err = "Insufficient Permissions." }
	end

	return {
		success = true,
		serverData = Helpers.getServerData(),
	}
end)

Helpers.registerCallback("esx-adminmenu:server:canUseAdminAction", function(source, data)
	if not Helpers.hasPermission(source) then
		return { success = false, err = "Insufficient Permissions." }
	end

	local action = type(data) == "table" and data.action or data
	if type(action) ~= "string" or action == "" then
		return { success = false, err = "Invalid admin action." }
	end

	local feature = Helpers.getActionPermission("adminMenu", action)
	if not feature then
		return { success = false, err = "Invalid admin action." }
	end

	if not Helpers.hasFeaturePermission(source, feature) then
		return { success = false, err = "Insufficient Permissions." }
	end

	return {
		success = true,
		serverData = Helpers.getServerData(),
	}
end)

Helpers.registerCallback("esx-adminmenu:server:openDashboard", function(source)
	if not Helpers.hasPermission(source) then
		return { success = false, err = "Insufficient Permissions." }
	end

	return {
		success = true,
		players = Helpers.getPlayerList(source) or {},
		serverData = Helpers.getServerData(),
	}
end)

Helpers.registerCallback("esx-adminmenu:server:getVehicles", function(source, data)
	if not Helpers.hasPermission(source) then
		return { success = false, err = "Insufficient Permissions." }
	end

	local canSeeSensitive = Helpers.hasFeaturePermission(source, "sensitiveInfo")
	local result = Helpers.getVehiclesPage(data, canSeeSensitive)
	result.success = true

	return result
end)

Helpers.registerCallback("esx-adminmenu:server:getBans", function(source, data)
	if not Helpers.hasFeaturePermission(source, "banManagement") then
		return { success = false, err = "Insufficient Permissions." }
	end

	local result = Helpers.getActiveBansPage(data)
	result.success = true

	return result
end)

Helpers.registerCallback("esx-adminmenu:server:getRecentPlayers", function(source)
	if not Helpers.hasPermission(source) then
		return { success = false, err = "Insufficient Permissions." }
	end

	return {
		success = true,
		players = Helpers.getRecentPlayers(source),
	}
end)

Helpers.registerCallback("esx-adminmenu:server:getRadioChannelPlayers", function(source, data)
	if not Helpers.hasFeaturePermission(source, "radioLookup") then
		return { success = false, err = "Insufficient Permissions." }
	end

	local channel = tonumber(data and data.channel) or 0
	if channel <= 0 then
		return { success = false, err = "Enter a valid radio channel." }
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

	return { success = true, players = players }
end)

local MAX_RESULTS = tonumber(Config.AdminLimits and Config.AdminLimits.OfflineSearchResults) or 25

Helpers.registerCallback("esx-adminmenu:server:searchOfflinePlayer", function(source, data)
	local src = source

	if not Helpers.hasPermission(src) then
		return { err = "Insufficient Permissions" }
	end

	local canSeeSensitive = Helpers.hasFeaturePermission(src, "sensitiveInfo")

	if not data or type(data.identifier) ~= "string" then
		return { players = {} }
	end

	local inputIdentifier = data.identifier:match("^%s*(.-)%s*$")
	if inputIdentifier == "" then
		return { players = {} }
	end

	if #inputIdentifier > 100 then
		return { players = {} }
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
			return { players = {} }
		end

		rows = Helpers.safeQuery(
			[[SELECT identifier, firstname, lastname, sex, job, job_grade, accounts, metadata, last_seen
			FROM users
			WHERE SUBSTRING_INDEX(identifier, ':', -1) = ?
			LIMIT ?]],
			{ base, MAX_RESULTS + 1 }
		)

	-- CHAR SEARCH (In cases of char identifier being inputted)
	elseif inputIdentifier:match("^char%d+:[%w%-_]+$") then
		rows = Helpers.safeQuery(
			[[SELECT identifier, firstname, lastname, sex, job, job_grade, accounts, metadata, last_seen
			FROM users
			WHERE identifier = ?
			LIMIT ?]],
			{ inputIdentifier, MAX_RESULTS + 1 }
		)
	else
		return { players = {} }
	end

	if not rows or #rows == 0 then
		return { players = {} }
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

	return { players = players }
end)
