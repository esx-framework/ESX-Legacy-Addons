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

-- Reading the log is gated on its own feature: it exposes who moderated whom,
-- which is more sensitive than most actions it records.
Helpers.registerCallback("esx-adminmenu:server:getAdminLogs", function(source, data)
	if not Helpers.hasFeaturePermission(source, "logViewer") then
		return { success = false, err = "Insufficient Permissions", logs = {} }
	end

	local result = Logs.query(data)
	result.success = true

	return result
end)

local MAX_RESULTS = tonumber(Config.AdminLimits and Config.AdminLimits.OfflineSearchResults) or 25
local MIN_QUERY_LENGTH = 2

local SEARCH_COLUMNS = [[SELECT identifier, firstname, lastname, sex, job, job_grade, accounts, metadata,
	last_seen, created_at, phone_number, `group`, disabled
	FROM users]]

--- Escapes LIKE metacharacters. Without this a query of "%" or "_" would match
--- every row in the table and leak the whole user base in one request.
local function escapeLike(value)
	return (value:gsub("([%%_\\])", "\\%1"))
end

local function decodeJson(raw)
	if not raw then
		return {}
	end

	local ok, decoded = pcall(json.decode, raw)
	return (ok and type(decoded) == "table") and decoded or {}
end

--- The bare id shared by a player's char/license identifiers.
local function getBase(identifier)
	if type(identifier) ~= "string" then
		return nil
	end

	local base = identifier:match("^[^:]+:(.+)$")
	if not base or base == "" or #base < 5 or #base > 80 then
		return nil
	end

	return base
end

local function buildOfflineEntry(row, canSeeSensitive)
	local accounts = decodeJson(row.accounts)
	local metadata = decodeJson(row.metadata)
	local base = getBase(row.identifier)

	return {
		status = "offline",
		id = nil,
		name = ((row.firstname or "") .. " " .. (row.lastname or "")):match("^%s*(.-)%s*$"),

		cash = tonumber(accounts.money) or 0,
		bank = tonumber(accounts.bank) or 0,
		alt_money = tonumber(accounts.black_money) or 0,

		health = metadata.health and metadata.health - 100 or 0,
		armor = metadata.armor or 0,

		char_identifier = canSeeSensitive and row.identifier or nil,
		identifier = canSeeSensitive and (base and ("license:" .. base) or row.identifier) or nil,
		phone_number = canSeeSensitive and row.phone_number or nil,

		play_time = Helpers.getFormattedPlayTime(metadata.lastPlaytime or 0),
		gender = row.sex == "f" and "f" or "m",
		job = row.job,
		job_grade = row.job_grade,
		group = row.group,
		disabled = row.disabled == 1 or row.disabled == true,
		last_join = row.last_seen,
		first_join = row.created_at,
	}
end

--- Online players matching the query, taken from the same source as the Online
--- Players tab so both views stay consistent in shape and sensitive-data gating.
local function findOnlineMatches(src, query)
	local matches = {}
	local list = Helpers.getPlayerList(src) or {}

	for i = 1, #list do
		local player = list[i]
		local haystack = {
			tostring(player.name or ""),
			tostring(player.id or ""),
			tostring(player.char_identifier or ""),
			tostring(player.identifier or ""),
		}

		for j = 1, #haystack do
			if haystack[j]:lower():find(query, 1, true) then
				matches[#matches + 1] = player
				break
			end
		end
	end

	return matches
end

Helpers.registerCallback("esx-adminmenu:server:searchOfflinePlayer", function(source, data)
	local src = source

	if not Helpers.hasPermission(src) then
		return { success = false, err = "Insufficient Permissions", players = {} }
	end

	local canSeeSensitive = Helpers.hasFeaturePermission(src, "sensitiveInfo")

	local raw = type(data) == "table" and data.identifier or data
	if type(raw) ~= "string" then
		return { success = true, players = {} }
	end

	local query = raw:match("^%s*(.-)%s*$")
	if #query < MIN_QUERY_LENGTH or #query > 100 then
		return { success = true, players = {} }
	end

	local lowered = query:lower()
	local players = findOnlineMatches(src, lowered)

	-- Track who is already listed as online so a player is never shown twice.
	local seen = {}
	for i = 1, #players do
		local key = players[i].char_identifier or players[i].identifier
		if key then
			seen[key] = true
		end
	end

	local rows
	local fullIdentifier = query:match("^license:[%w%-_]+$") or query:match("^char%d+:[%w%-_]+$")

	if fullIdentifier then
		-- Fast path: a complete identifier is matched against the PRIMARY key,
		-- so this stays sargable instead of degrading into a full scan.
		local base = getBase(query)
		local candidates = base and { query, "license:" .. base, "license2:" .. base } or { query }

		rows = Helpers.safeQuery(
			SEARCH_COLUMNS .. " WHERE identifier IN (?, ?, ?) LIMIT ?",
			{ candidates[1], candidates[2] or candidates[1], candidates[3] or candidates[1], MAX_RESULTS + 1 }
		)
	else
		-- Fuzzy path: name and partial identifier. firstname/lastname carry no
		-- index, so this scans; MIN_QUERY_LENGTH and LIMIT keep it bounded.
		local infix = "%" .. escapeLike(query) .. "%"

		rows = Helpers.safeQuery(
			SEARCH_COLUMNS .. [[ WHERE identifier LIKE ?
				OR firstname LIKE ?
				OR lastname LIKE ?
				OR CONCAT(firstname, ' ', lastname) LIKE ?
				OR phone_number LIKE ?
			LIMIT ?]],
			{ infix, infix, infix, infix, infix, MAX_RESULTS + 1 }
		)
	end

	if rows then
		for i = 1, #rows do
			if #players >= MAX_RESULTS then
				break
			end

			local row = rows[i]
			if not seen[row.identifier] then
				seen[row.identifier] = true
				players[#players + 1] = buildOfflineEntry(row, canSeeSensitive)
			end
		end
	end

	return { success = true, players = players }
end)
