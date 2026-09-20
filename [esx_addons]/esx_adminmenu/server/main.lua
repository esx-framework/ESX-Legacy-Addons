-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Helpers.registerCallback("esx-adminmenu:server:getInitData", function(source)
	if not Helpers.hasPermission(source) then
		return { err = "Insufficient Permissions." }
	end

	local impounds = Helpers.getImpounds()
	local vehicleConfig = Config.VehicleSpawner or {}

	return {
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
		impounds = Helpers.getImpounds(),
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
		impounds = Helpers.getImpounds(),
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
local MIN_QUERY_LENGTH = math.max(
	3,
	math.floor(tonumber(Config.AdminLimits and Config.AdminLimits.MinOfflineSearchLength) or 3)
)
local OFFLINE_SEARCH_COOLDOWN_MS = math.max(
	0,
	math.floor(tonumber(Config.AdminLimits and Config.AdminLimits.OfflineSearchCooldownMs) or 1000)
)

local offlineSearchLimiter = xLib.rateLimiter({
	capacity = 1,
	refill = 1,
	interval = math.max(1, OFFLINE_SEARCH_COOLDOWN_MS > 0 and OFFLINE_SEARCH_COOLDOWN_MS or 1),
	staleMs = 60000
})

local SEARCH_COLUMNS = [[
	SELECT
		identifier,
		firstname,
		lastname,
		sex,
		job,
		job_grade,
		accounts,
		metadata,
		last_seen,
		created_at,
		phone_number,
		`group`,
		disabled
	FROM users
]]

-- Escape LIKE metacharacters while still allowing us to append
-- a trailing % for an indexed prefix search: "pepe%".
local function escapeLike(value)
	return (value:gsub("([%%_\\\\])", "\\\\%1"))
end

local function decodeJson(raw)
	if not raw then
		return {}
	end

	local ok, decoded = pcall(json.decode, raw)

	if not ok or type(decoded) ~= "table" then
		return {}
	end

	return decoded
end
--[[
Bare identifier shared by char/license forms.
Returns the underlying FiveM/ESX identifier without assuming
a specific multicharacter prefix
]]--
local function getUnderlyingIdentifier(identifier)
	if type(identifier) ~= "string" or identifier == "" then
		return nil
	end

	if #identifier > 150 then
		return nil
	end

	local firstColon = identifier:find(":", 1, true)

	if not firstColon then
		return nil
	end

	local remainder = identifier:sub(firstColon + 1)

	if remainder:find(":", 1, true) then
		return remainder
	end

	return identifier
end

local function isOfflineSearchRateLimited(src)
	if OFFLINE_SEARCH_COOLDOWN_MS <= 0 then
		return false
	end

	local allowed = offlineSearchLimiter:consume(src)
	return not allowed
end

local function buildOfflineEntry(row, canSeeSensitive)
	local accounts = decodeJson(row.accounts)
	local metadata = decodeJson(row.metadata)
	local underlyingIdentifier = getUnderlyingIdentifier(row.identifier)
	local storedHealth = tonumber(metadata.health)
	local storedArmor = tonumber(metadata.armor)

	return {
		status = "offline",
		id = nil,

		name = (
			(row.firstname or "") ..
			" " ..
			(row.lastname or "")
		):match("^%s*(.-)%s*$"),

		cash = tonumber(accounts.money) or 0,
		bank = tonumber(accounts.bank) or 0,
		alt_money = tonumber(accounts.black_money) or 0,

		health = storedHealth and math.max(0, storedHealth - 100) or 0,
		armor = storedArmor or 0,

		char_identifier = canSeeSensitive and row.identifier or nil,

		identifier = canSeeSensitive
			and (underlyingIdentifier or row.identifier)
			or nil,

		phone_number = canSeeSensitive and row.phone_number or nil,

		play_time = Helpers.getFormattedPlayTime(
			tonumber(metadata.lastPlaytime) or 0
		),

		gender = row.sex == "f" and "f" or "m",
		job = row.job,
		job_grade = row.job_grade,

		group = canSeeSensitive and row.group or nil,

		disabled = row.disabled == 1 or row.disabled == true,

		last_join = row.last_seen,
		first_join = row.created_at,
	}
end

--[[ 
We only need this to prevent currently-online characters from also
appearing as OFFLINE results.
]]--
local function getOnlineCharacterIdentifiers()
	local identifiers = {}
	local count = 0

	local players = GetPlayers()

	for i = 1, #players do
		local src = tonumber(players[i])

		if src then
			local xPlayer = ESX.GetPlayerFromId(src)
			local identifier = xPlayer and xPlayer.identifier

			if type(identifier) == "string"
				and identifier ~= ""
				and not identifiers[identifier]
			then
				identifiers[identifier] = true
				count = count + 1
			end
		end
	end

	return identifiers, count
end

local function searchOfflineDatabase(query, canSeeSensitive, limit)
	local lowered = query:lower()

	local fullIdentifier =
		lowered:match("^license:[%w%-_]+$")
		or lowered:match("^license2:[%w%-_]+$")
		or lowered:match("^char%d+:[%w%-_]+$")

	if fullIdentifier then
		if not canSeeSensitive then
			return {}
		end

		return Helpers.safeQuery(
			SEARCH_COLUMNS .. [[
				WHERE identifier = ?
				LIMIT ?
			]],
			{
				lowered,
				limit,
			}
		)
	end

	local identifierSearch =
		lowered:match("^license:")
		or lowered:match("^license2:")
		or lowered:match("^char%d+:")

	if identifierSearch then
		if not canSeeSensitive then
			return {}
		end

		return Helpers.safeQuery(
			SEARCH_COLUMNS .. [[
				WHERE identifier LIKE ?
				LIMIT ?
			]],
			{
				escapeLike(lowered) .. "%",
				limit,
			}
		)
	end

	local looksLikePhone =
		query:match("^[%d%+%-%s%(%)]+$") ~= nil

	if looksLikePhone then
		if not canSeeSensitive then
			return {}
		end

		return Helpers.safeQuery(
			SEARCH_COLUMNS .. [[
				WHERE phone_number LIKE ?
				LIMIT ?
			]],
			{
				escapeLike(query) .. "%",
				limit,
			}
		)
	end

	local firstPart, secondPart =
		query:match("^(%S+)%s+(.+)$")

	if firstPart and secondPart then
		local firstPrefix =
			escapeLike(firstPart) .. "%"

		local secondPrefix =
			escapeLike(secondPart) .. "%"

		return Helpers.safeQuery(
			SEARCH_COLUMNS .. [[
				WHERE
					(
						firstname LIKE ?
						AND lastname LIKE ?
					)
					OR
					(
						firstname LIKE ?
						AND lastname LIKE ?
					)
				LIMIT ?
			]],
			{
				firstPrefix,
				secondPrefix,

				secondPrefix,
				firstPrefix,

				limit,
			}
		)
	end

	local prefix = escapeLike(query) .. "%"

	return Helpers.safeQuery(
		SEARCH_COLUMNS .. [[
			WHERE firstname LIKE ?
				OR lastname LIKE ?
			LIMIT ?
		]],
		{
			prefix,
			prefix,
			limit,
		}
	)
end

Helpers.registerCallback(
	"esx-adminmenu:server:searchOfflinePlayer",
	function(source, data)
		local src = source

		if not Helpers.hasPermission(src) then
			return {
				success = false,
				err = "Insufficient Permissions",
				players = {},
			}
		end

		local raw =
			type(data) == "table"
			and data.identifier
			or data

		if type(raw) ~= "string" then
			return {
				success = true,
				players = {},
			}
		end

		local query =
			raw:match("^%s*(.-)%s*$")

		if #query < MIN_QUERY_LENGTH
			or #query > 100
		then
			return {
				success = true,
				players = {},
			}
		end

		if isOfflineSearchRateLimited(src) then
			return {
				success = false,
				err = "Search rate limited.",
				players = {},
			}
		end

		local canSeeSensitive =
			Helpers.hasFeaturePermission(
				src,
				"sensitiveInfo"
			)

		local onlineIdentifiers, onlineCount =
			getOnlineCharacterIdentifiers()

		local databaseLimit =
			MAX_RESULTS
			+ math.min(onlineCount, 256)
			+ 1

		local rows =
			searchOfflineDatabase(
				query,
				canSeeSensitive,
				databaseLimit
			)

		if rows == nil then
			return {
				success = false,
				err = "Database unavailable.",
				players = {},
			}
		end

		local players = {}

		for i = 1, #rows do
			if #players >= MAX_RESULTS then
				break
			end

			local row = rows[i]

			if row.identifier
				and not onlineIdentifiers[row.identifier]
			then
				players[#players + 1] =
					buildOfflineEntry(
						row,
						canSeeSensitive
					)
			end
		end

		return {
			success = true,
			players = players,
		}
	end
)
