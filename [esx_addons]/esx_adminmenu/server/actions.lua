Actions = Actions or {}

---@class AdminActionResult
---@field success boolean
---@field err string?
---@field playerOnline boolean?
---@field isAdmin boolean?

local function async(fn)
	CreateThread(function()
		local ok, err = pcall(fn)
		if not ok then
			print("[esx-adminmenu] async error:", err)
		end
	end)
end

local function getTargetId(data)
	return tonumber(data and data.id)
end

local function getBoolean(value)
	return value == true or value == "true" or value == 1 or value == "1"
end

local function clampNumber(value, min, max, fallback)
	local number = tonumber(value) or fallback

	if not number then
		return min
	end

	if number < min then
		return min
	end

	if number > max then
		return max
	end

	return number
end

local trimString = Helpers.trim

local function limitString(value, maxLength, fallback)
	local text = trimString(value)
	if text == "" then
		text = fallback or ""
	end

	maxLength = tonumber(maxLength) or 180
	if #text > maxLength then
		text = text:sub(1, maxLength)
	end

	return text
end

local function getLimits()
	return Config.AdminLimits or {}
end

local function isValidIdentifier(identifier)
	return type(identifier) == "string"
		and #identifier <= 100
		and identifier:match("^[%w]+:[%w%-_]+$") ~= nil
end

local function isValidCharacterIdentifier(identifier)
	return type(identifier) == "string"
		and #identifier <= 100
		and identifier:match("^char%d+:[%w%-_]+$") ~= nil
end

local function normalizePlate(plate)
	plate = trimString(plate):upper()

	if plate == "" or #plate > 12 or not plate:match("^[%w%s%-]+$") then
		return nil
	end

	return plate
end

local function normalizeBanDuration(minutes)
	local duration = tonumber(minutes)
	if not duration or duration <= 0 then
		return nil
	end

	return math.floor(clampNumber(duration, 1, getLimits().MaxBanDurationMinutes or 2628000, 1))
end

local function insertBan(identifier, reason, bannedBy, expiresAt, bannedAt, identifiers)
	identifier = Helpers.normalizeLicenseIdentifier(identifier)
	if not identifier then
		return nil
	end

	local identifiersJson = (type(identifiers) == "table" and #identifiers > 0) and json.encode(identifiers) or nil

	if expiresAt then
		return MySQL.insert.await(
			"INSERT INTO bans (identifier, identifiers, reason, banned_by, expires_at, banned_at) VALUES (?, ?, ?, ?, FROM_UNIXTIME(?), FROM_UNIXTIME(?))",
			{ identifier, identifiersJson, reason, bannedBy, expiresAt, bannedAt }
		)
	end

	return MySQL.insert.await(
		"INSERT INTO bans (identifier, identifiers, reason, banned_by, expires_at, banned_at) VALUES (?, ?, ?, ?, NULL, FROM_UNIXTIME(?))",
		{ identifier, identifiersJson, reason, bannedBy, bannedAt }
	)
end

local function getBanIdentifierVariants(identifier)
	local normalized = Helpers.normalizeLicenseIdentifier(identifier)
	if not normalized then
		return nil, nil
	end

	local variants = { normalized }
	local bare = normalized:match("^license:(.+)$")
	if bare then
		variants[#variants + 1] = bare
	end

	return normalized, variants
end

local function updateBanExpiry(identifier, expiresAt)
	local _, variants = getBanIdentifierVariants(identifier)
	if not variants then
		return false
	end

	if expiresAt then
		for i = 1, #variants do
			MySQL.update.await(
				"UPDATE bans SET expires_at = FROM_UNIXTIME(?) WHERE identifier = ?",
				{ expiresAt, variants[i] }
			)
		end
		return true
	end

	for i = 1, #variants do
		MySQL.update.await("UPDATE bans SET expires_at = NULL WHERE identifier = ?", { variants[i] })
	end

	return true
end

local function expireBan(identifier)
	local _, variants = getBanIdentifierVariants(identifier)
	if not variants then
		return false
	end

	for i = 1, #variants do
		MySQL.update.await("UPDATE bans SET expires_at = NOW() WHERE identifier = ?", { variants[i] })
	end

	return true
end

local function normalizeMoneyAmount(amount)
	return math.floor(clampNumber(amount, 1, getLimits().MaxMoneyAmount or 10000000, 0))
end

local function normalizeMoneyAccount(account)
	account = trimString(account)
	local allowed = getLimits().AllowedMoneyAccounts or { money = true, bank = true, black_money = true }

	if allowed[account] then
		return account
	end

	return "money"
end

local function normalizeNotificationType(notificationType)
	notificationType = trimString(notificationType)
	local allowed = getLimits().AllowedNotificationTypes or { info = true, success = true, error = true }

	if allowed[notificationType] then
		return notificationType
	end

	return "info"
end

local function getPlayerIdentifier(xPlayer)
	if xPlayer and xPlayer.identifier then
		return xPlayer.identifier
	end

	if xPlayer and xPlayer.getIdentifier then
		return xPlayer.getIdentifier()
	end

	return nil
end

local function normalizeAceGroup(value)
	local group = trimString(value):gsub("^group%.", "")

	if group == "" or not group:match("^[%w_%.%-]+$") then
		return nil
	end

	return group
end

local function setStatusMeta(target, targetId, key, value)
	local statusValue = math.floor(clampNumber(value, 0, 100, 100))

	TriggerClientEvent("esx_status:set", targetId, key, statusValue * 10000)

	if target.setMeta then
		pcall(function()
			target.setMeta(key, statusValue)
		end)
	end

	return statusValue
end

local function getOnlineCharacterIdentifier(target, targetId)
	local identifier = getPlayerIdentifier(target)

	if type(identifier) ~= "string" or identifier == "" then
		return nil
	end

	return identifier
end

local function revivePlayer(targetId)
	local reviveConfig = Config.Revive or {}
	local events = reviveConfig.Events or {}
	local triggeredEvent = false

	for i = 1, #events do
		local eventName = events[i]

		if type(eventName) == "string" and eventName ~= "" then
			TriggerClientEvent(eventName, targetId)
			triggeredEvent = true
		end
	end

	if reviveConfig.UseNativeFallback ~= false then
		local delay = triggeredEvent and tonumber(reviveConfig.NativeFallbackDelay) or 0

		SetTimeout(delay or 0, function()
			TriggerClientEvent("esx-adminmenu:client:revive", targetId)
		end)
	end
end

local function getServerActionPermission(action)
	return Helpers.getActionPermission("serverManagement", action) or "serverManagement"
end

local function withServerData(data)
	data = data or {}
	data.serverData = Helpers.getServerData()
	return data
end

-- TELEPORT

function Actions.Goto(src, data)
	data = data or {}

	if not Helpers.hasFeaturePermission(src, "playerTeleport") then
		return { success = false, err = "Insufficient Permissions", playerOnline = true }
	end

	local targetId = getTargetId(data)
	if not Helpers.isOnline(targetId) then
		return { success = false, playerOnline = false }
	end

	local admin = ESX.GetPlayerFromId(src)
	local target = ESX.GetPlayerFromId(targetId)
	if not admin or not target then
		return { success = false, playerOnline = target ~= nil }
	end

	admin.setCoords(target.getCoords(true))
	return { success = true, playerOnline = true }
end

Helpers.registerCallback("esx-adminmenu:server:goto", function(source, data)
	return Actions.Goto(source, data)
end)

function Actions.Bring(src, data)
	data = data or {}

	if not Helpers.hasFeaturePermission(src, "playerTeleport") then
		return { success = false, playerOnline = true }
	end

	local targetId = getTargetId(data)
	if not Helpers.isOnline(targetId) then
		return { success = false, playerOnline = false }
	end

	local admin = ESX.GetPlayerFromId(src)
	local target = ESX.GetPlayerFromId(targetId)
	if not admin or not target then
		return { success = false, playerOnline = target ~= nil }
	end

	target.setCoords(admin.getCoords(true))
	return { success = true, playerOnline = true }
end

Helpers.registerCallback("esx-adminmenu:server:bring", function(source, data)
	return Actions.Bring(source, data)
end)

-- SPECTATE

function Actions.Spectate(src, data)
	data = data or {}

	if not Helpers.hasFeaturePermission(src, "spectate") then
		return { success = false, err = "Insufficient Permissions", playerOnline = true, isAdmin = false }
	end

	local targetId = getTargetId(data)
	if not Helpers.isOnline(targetId) then
		return { success = false, err = "Player Not Online", playerOnline = false, isAdmin = true }
	end

	if targetId == src then
		return { success = false, err = "You cannot spectate yourself.", playerOnline = true, isAdmin = true }
	end

	local targetPed = GetPlayerPed(targetId)
	local targetCoords = GetEntityCoords(targetPed)

	Helpers.stopSpectate(src)
	Helpers.startSpectate(src, targetId)

	return { success = true, playerOnline = true, targetCoords = targetCoords, isAdmin = true }
end

Helpers.registerCallback("esx-adminmenu:server:spectate", function(source, data)
	return Actions.Spectate(source, data)
end)

function Actions.StopSpectate(src)
	if not Helpers.hasFeaturePermission(src, "spectate") then
		return { success = false, err = "Insufficient Permissions" }
	end

	Helpers.stopSpectate(src)
	return { success = true }
end

Helpers.registerCallback("esx-adminmenu:server:spectate:stop", function(source)
	return Actions.StopSpectate(source)
end)

-- KICK

function Actions.Kick(src, data)
	data = data or {}

	if not Helpers.hasFeaturePermission(src, "playerModeration") then
		return { success = false, err = "Insufficient Permissions", playerOnline = true, isAdmin = false }
	end

	local targetId = getTargetId(data)
	if not Helpers.isOnline(targetId) then
		return { success = false, err = "Player Not Online", playerOnline = false, isAdmin = true }
	end

	if targetId == src then
		return { success = false, err = "You cannot kick yourself.", playerOnline = true, isAdmin = true }
	end

	local reason = limitString(data.reason, getLimits().MaxReasonLength, "Kicked by admin")

	-- Queued, not written inline: the drop must not wait on the database.
	-- Recorded before DropPlayer so the target is still resolvable.
	Logs.record({
		namespace = "moderation",
		action = "kick",
		actor = src,
		target = targetId,
		payload = { reason = reason },
	})

	DropPlayer(targetId, reason)

	return { success = true, playerOnline = true, isAdmin = true }
end

Helpers.registerCallback("esx-adminmenu:server:kick", function(source, data)
	return Actions.Kick(source, data)
end)

-- BAN
function Actions.Ban(src, data)
	data = data or {}

	if not Helpers.hasFeaturePermission(src, "banManagement") then
		return { success = false, err = "Insufficient Permissions", playerOnline = true, isAdmin = false }
	end

	local targetId = getTargetId(data)

	if not Helpers.isOnline(targetId) then
		return { success = false, err = "Player Not Online", playerOnline = false, isAdmin = true }
	end

	if targetId == src then
		return { success = false, err = "You cannot ban yourself.", playerOnline = true, isAdmin = true }
	end

	local identifier = Helpers.getPlayerLicenseIdentifier(targetId)
	if not identifier then
		return { success = false, err = "Missing player license identifier.", playerOnline = true, isAdmin = true }
	end

	-- Capture every enabled identifier so the ban matches on reconnect even if
	-- the player changes their license.
	local banIdentifiers = Helpers.getBanIdentifiers(targetId)

	local duration = normalizeBanDuration(data.duration)
	local seconds = duration and (os.time() + duration * 60) or nil
	local bannedAt = os.time()
	local adminName = GetPlayerName(src)
	local reason = limitString(data.reason, getLimits().MaxReasonLength, "Banned by admin")

	local ok, banId = pcall(insertBan, identifier, reason, adminName, seconds, bannedAt, banIdentifiers)
	if not ok or not banId then
		print(("[esx-adminmenu] Failed to persist ban for %s: %s"):format(tostring(identifier), tostring(banId)))
		return { success = false, err = "Failed to persist ban.", playerOnline = true, isAdmin = true }
	end

	BanCache.add({
		id = banId,
		identifier = identifier,
		identifiers = banIdentifiers,
		reason = reason,
		banned_by = adminName,
		banned_at = bannedAt,
		expires_at = seconds,
	})

	Logs.record({
		namespace = "moderation",
		action = "ban",
		actor = src,
		target = identifier,
		targetName = GetPlayerName(targetId),
		payload = { reason = reason, duration_minutes = duration, identifiers = #banIdentifiers },
	})

	DropPlayer(targetId, reason)
	return { success = true, playerOnline = true, isAdmin = true }
end

Helpers.registerCallback("esx-adminmenu:server:ban", function(source, data)
	return Actions.Ban(source, data)
end)

-- OFFLINE BAN

Helpers.registerCallback("esx-adminmenu:server:ban:offline", function(source, data)
	if not Helpers.hasFeaturePermission(source, "banManagement") then
		return { success = false, err = "Insufficient Permissions", isAdmin = false }
	end

	data = data or {}

	local normalizedIdentifier = Helpers.normalizeLicenseIdentifier(data.identifier)
	if not normalizedIdentifier then
		return { success = false, err = "Invalid Identifier", isAdmin = true }
	end

	local duration = normalizeBanDuration(data.duration)
	local seconds = duration and (os.time() + duration * 60) or nil
	local bannedAt = os.time()
	local adminName = GetPlayerName(source)
	local reason = limitString(data.reason, getLimits().MaxReasonLength, "Banned by admin")

	local ok, banId = pcall(insertBan, normalizedIdentifier, reason, adminName, seconds, bannedAt)
	if not ok or not banId then
		print(("[esx-adminmenu] Failed to persist offline ban for %s: %s"):format(tostring(normalizedIdentifier), tostring(banId)))
		return { success = false, err = "Failed to persist ban.", isAdmin = true }
	end

	BanCache.add({
		id = banId,
		identifier = normalizedIdentifier,
		reason = reason,
		banned_by = adminName,
		banned_at = bannedAt,
		expires_at = seconds,
	})

	Logs.record({
		namespace = "moderation",
		action = "banOffline",
		actor = source,
		target = normalizedIdentifier,
		payload = { reason = reason, duration_minutes = duration },
	})

	return { success = true, isAdmin = true }
end)

-- CHANGE EXPIRY

Helpers.registerCallback("esx-adminmenu:server:ban:changeExpiry", function(source, data)
	if not Helpers.hasFeaturePermission(source, "banManagement") then
		return { success = false, err = "Insufficient Permissions", isAdmin = false }
	end

	data = data or {}

	local normalizedIdentifier = Helpers.normalizeLicenseIdentifier(data.identifier)
	if not normalizedIdentifier then
		return { success = false, err = "Invalid Identifier", isAdmin = true }
	end

	local seconds = nil
	if data.newDate ~= nil then
		local newDate = tonumber(data.newDate)
		if not newDate then
			return { success = false, err = "Invalid expiry date.", isAdmin = true }
		end

		local now = os.time()
		seconds = math.floor(newDate / 1000)

		if seconds < now then
			seconds = now
		end

		local maxMinutes = tonumber(getLimits().MaxBanDurationMinutes)
		if maxMinutes and maxMinutes > 0 then
			seconds = math.min(seconds, now + (maxMinutes * 60))
		end
	end

	local ok = pcall(function()
		updateBanExpiry(normalizedIdentifier, seconds)
		BanCache.updateExpiry(normalizedIdentifier, seconds)
	end)

	if not ok then
		return { success = false, err = "Failed to update ban expiry.", isAdmin = true }
	end

	Logs.record({
		namespace = "moderation",
		action = "banChangeExpiry",
		actor = source,
		target = normalizedIdentifier,
		payload = { expires_at = seconds },
	})

	return { success = true, isAdmin = true }
end)

-- REVOKE

Helpers.registerCallback("esx-adminmenu:server:ban:revoke", function(source, data)
	if not Helpers.hasFeaturePermission(source, "banManagement") then
		return { success = false, err = "Insufficient Permissions", isAdmin = false }
	end

	data = data or {}

	local normalizedIdentifier = Helpers.normalizeLicenseIdentifier(data.identifier)
	if not normalizedIdentifier then
		return { success = false, err = "Invalid Identifier", isAdmin = true }
	end

	local ok = pcall(function()
		expireBan(normalizedIdentifier)
		BanCache.remove(normalizedIdentifier)
	end)

	if not ok then
		return { success = false, err = "Failed to revoke ban.", isAdmin = true }
	end

	Logs.record({
		namespace = "moderation",
		action = "unban",
		actor = source,
		target = normalizedIdentifier,
	})

	return { success = true, isAdmin = true }
end)

-- VEHICLES

local function vehicleUpdate(source, data, query, params, feature)
	if not Helpers.hasFeaturePermission(source, feature or "vehicleManagement") then
		return { success = false, err = "Insufficient Permissions" }
	end

	data = data or {}
	params = params or {}
	local plate = normalizePlate(data.plate)

	if not plate then
		return { success = false, err = "Missing plate" }
	end

	params[#params + 1] = plate

	async(function()
		Helpers.safeUpdate(query, params)
	end)

	return { success = true }
end

Helpers.registerCallback("esx-adminmenu:server:vehicleImpound", function(source, data)
	data = data or {}
	local impoundName = trimString(data.impoundName)
	local impounds = Helpers.getImpounds() or {}

	if impoundName == "" or not impounds[impoundName] then
		return { success = false, err = "Invalid impound." }
	end

	return vehicleUpdate(
		source,
		data,
		"UPDATE owned_vehicles SET pound = ? WHERE plate = ?",
		{ impoundName },
		"vehicleManagement"
	)
end)

Helpers.registerCallback("esx-adminmenu:server:vehicleUnimpound", function(source, data)
	return vehicleUpdate(source, data or {}, "UPDATE owned_vehicles SET pound = NULL WHERE plate = ?", {}, "vehicleManagement")
end)

Helpers.registerCallback("esx-adminmenu:server:vehicleDelete", function(source, data)
	return vehicleUpdate(source, data or {}, "DELETE FROM owned_vehicles WHERE plate = ?", {}, "vehicleDestructive")
end)

-- NOTIFY
function Actions.Notify(src, data)
	data = data or {}

	if not Helpers.hasFeaturePermission(src, "playerNotify") then
		return { success = false, err = "Insufficient Permissions", playerOnline = true, isAdmin = false }
	end

	local targetId = getTargetId(data)

	if not Helpers.isOnline(targetId) then
		return { success = false, err = "Player Not Online", playerOnline = false, isAdmin = true }
	end

	local message = limitString(data.notificationContent, getLimits().MaxNotificationLength, "Notification by Admin")
	local notificationType = normalizeNotificationType(data.notificationType)
	local duration = math.floor(clampNumber(data.duration, 1000, getLimits().MaxNotificationDuration or 30000, 5000))
	local title = limitString(data.notificationTitle, 80, "")

	TriggerClientEvent(
		"esx:showNotification",
		targetId,
		message,
		notificationType,
		duration,
		title ~= "" and title or nil,
		"top-left"
	)

	return { success = true, playerOnline = true, isAdmin = true }
end

Helpers.registerCallback("esx-adminmenu:server:notify", function(source, data)
	return Actions.Notify(source, data)
end)

-- SELF ACTIONS

function Actions.SelfAction(src, data)
	data = data or {}

	if not Helpers.hasPermission(src) then
		return { success = false, err = "Insufficient Permissions" }
	end

	local action = data.action
	local feature = Helpers.getActionPermission("adminMenu", action)

	if not feature or not Helpers.hasFeaturePermission(src, feature) then
		return { success = false, err = "Insufficient Permissions" }
	end

	if action == "revive" then
		revivePlayer(src)
		return { success = true }
	end

	return { success = false, err = "Unknown self action." }
end

Helpers.registerCallback("esx-adminmenu:server:selfAction", function(source, data)
	return Actions.SelfAction(source, data)
end)

-- SERVER MANAGEMENT

-- action -> handler(src, payload) -> AdminActionResult. The dispatcher enforces
-- the base serverManagement gate plus getServerActionPermission(action) uniformly.
local ServerHandlers = {}

local function regServer(action, handler)
	ServerHandlers[action] = handler
end

local function deletePool(pool)
	TriggerClientEvent("esx-adminmenu:client:deletePool", -1, pool)
	return { success = true }
end

regServer("weather", function(_, payload)
	local weather = trimString(payload.weather):upper()
	local allowedWeather = Config.ServerManagement and Config.ServerManagement.WeatherTypes or {}
	if not allowedWeather[weather] then
		weather = "CLEAR"
	end

	Helpers.setServerEnvironment({ weather = weather })
	TriggerClientEvent("esx-adminmenu:client:setWeather", -1, weather)
	return withServerData({ success = true })
end)

regServer("time", function(_, payload)
	local hour = math.floor(clampNumber(payload.hour, 0, 23, 12))
	local minute = math.floor(clampNumber(payload.minute, 0, 59, 0))

	Helpers.setServerEnvironment({ hour = hour, minute = minute })
	TriggerClientEvent("esx-adminmenu:client:setTime", -1, hour, minute)
	return withServerData({ success = true })
end)

regServer("blackout", function(_, payload)
	local enabled = getBoolean(payload.enabled)
	Helpers.setServerEnvironment({ blackout = enabled })
	TriggerClientEvent("esx-adminmenu:client:setBlackout", -1, enabled)
	return withServerData({ success = true })
end)

regServer("pvp", function(_, payload)
	local enabled = getBoolean(payload.enabled)
	Helpers.setServerEnvironment({ pvp = enabled })
	TriggerClientEvent("esx-adminmenu:client:setPvp", -1, enabled)
	return withServerData({ success = true })
end)

regServer("freezeAll", function()
	TriggerClientEvent("esx-adminmenu:client:setFrozen", -1, true)
	return { success = true }
end)

regServer("unfreezeAll", function()
	TriggerClientEvent("esx-adminmenu:client:setFrozen", -1, false)
	return { success = true }
end)

regServer("bringAll", function(src)
	local admin = ESX.GetPlayerFromId(src)
	if not admin then
		return { success = false, err = "Admin player not found." }
	end

	local coords = admin.getCoords(true)
	local players = ESX.ExtendedPlayers()

	for i = 1, #players do
		if players[i].src ~= src then
			players[i].setCoords(coords)
		end
	end

	return { success = true }
end)

regServer("killAll", function()
	TriggerClientEvent("esx-adminmenu:client:kill", -1)
	return { success = true }
end)

regServer("reviveAll", function()
	revivePlayer(-1)
	return { success = true }
end)

regServer("kickAll", function(src, payload)
	local reason = limitString(
		payload.reason,
		getLimits().MaxReasonLength,
		(Config.ServerManagement and Config.ServerManagement.DefaultKickReason) or "Kicked by admin"
	)

	for _, playerSource in ipairs(GetPlayers()) do
		local targetId = tonumber(playerSource)
		if targetId and targetId ~= src then
			DropPlayer(targetId, reason)
		end
	end

	return { success = true }
end)

regServer("deleteVehicles", function() return deletePool("CVehicle") end)
regServer("deletePeds", function() return deletePool("CPed") end)
regServer("deleteObjects", function() return deletePool("CObject") end)

regServer("notifyAll", function(_, payload)
	local message = limitString(payload.message, getLimits().MaxNotificationLength, "Notification by Admin")
	local notificationType = normalizeNotificationType(payload.notificationType)
	local duration = math.floor(clampNumber(payload.duration, 1000, getLimits().MaxNotificationDuration or 30000, 5000))
	local title = limitString(payload.title, 80, "")

	TriggerClientEvent(
		"esx:showNotification",
		-1,
		message,
		notificationType,
		duration,
		title ~= "" and title or nil,
		"top-left"
	)
	return { success = true }
end)

regServer("giveMoneyAll", function(_, payload)
	local amount = normalizeMoneyAmount(payload.amount)
	local account = normalizeMoneyAccount(payload.account)

	if amount <= 0 then
		return { success = false, err = "Amount must be greater than 0." }
	end

	local players = ESX.ExtendedPlayers()
	for i = 1, #players do
		if account == "money" then
			players[i].addMoney(amount, "Admin menu")
		else
			players[i].addAccountMoney(account, amount, "Admin menu")
		end
	end

	return { success = true }
end)

---@param src number
---@param data table
---@return AdminActionResult
function Actions.ServerManagement(src, data)
	data = data or {}

	local action = type(data.action) == "string" and data.action or "unknown"

	-- Any client can invoke a server callback, so a denial here is a genuine
	-- abuse signal and is worth recording.
	if not Helpers.hasFeaturePermission(src, "serverManagement") then
		Logs.record({ namespace = "serverManagement", action = action, actor = src,
			success = false, err = "Insufficient Permissions" })
		return { success = false, err = "Insufficient Permissions" }
	end

	local handler = ServerHandlers[action]
	if not handler then
		return { success = false, err = "Unknown server action." }
	end

	if not Helpers.hasFeaturePermission(src, getServerActionPermission(action)) then
		Logs.record({ namespace = "serverManagement", action = action, actor = src,
			success = false, err = "Insufficient Permissions" })
		return { success = false, err = "Insufficient Permissions" }
	end

	local result = handler(src, data.payload or {})

	Logs.record({
		namespace = "serverManagement",
		action = action,
		actor = src,
		success = type(result) ~= "table" or result.success ~= false,
		err = type(result) == "table" and result.err or nil,
		payload = data.payload,
	})

	return result
end

Helpers.registerCallback("esx-adminmenu:server:serverAction", function(source, data)
	return Actions.ServerManagement(source, data)
end)

-- PLAYER MANAGEMENT

-- action -> { offline = boolean?, handler = function(ctx) -> AdminActionResult }.
-- ctx = { src, targetId, target, payload }. Permission is sourced once from
-- Config.PlayerActions.ActionPermissions by the dispatcher, so a handler never
-- re-checks it and a new action cannot silently ship without a gate.
local PlayerHandlers = {}

local function regPlayer(action, spec)
	PlayerHandlers[action] = spec
end

local function moneyHandler(ctx, isGive)
	local amount = normalizeMoneyAmount(ctx.payload.amount)
	local account = normalizeMoneyAccount(ctx.payload.account)

	if amount <= 0 then
		return { success = false, err = "Amount must be greater than 0.", playerOnline = true }
	end

	local method
	if isGive then
		method = account == "money" and "addMoney" or "addAccountMoney"
	else
		method = account == "money" and "removeMoney" or "removeAccountMoney"
	end

	-- Callable, not type()=="function": xPlayer methods reach us as function
	-- references across the es_extended resource boundary.
	if not Helpers.isCallable(ctx.target[method]) then
		return { success = false, err = "This ESX version does not expose " .. method .. ".", playerOnline = true }
	end

	local ok = pcall(function()
		if account == "money" then
			ctx.target[method](amount, "Admin menu")
		else
			ctx.target[method](account, amount, "Admin menu")
		end
	end)

	if not ok then
		return { success = false, err = "Failed to update balance.", playerOnline = true }
	end

	return { success = true, playerOnline = true }
end

regPlayer("deleteCharacter", { offline = true, handler = function(ctx)
	local identifier = trimString(ctx.payload.identifier)

	if not isValidCharacterIdentifier(identifier) then
		return { success = false, err = "Missing character identifier." }
	end

	if ctx.target then
		local targetIdentifier = getOnlineCharacterIdentifier(ctx.target, ctx.targetId)

		if targetIdentifier ~= identifier then
			return { success = false, err = "Character identifier does not match the selected player.", playerOnline = true }
		end
	end

	async(function()
		Helpers.safeUpdate("DELETE FROM users WHERE identifier = ?", { identifier })
		Helpers.safeUpdate("DELETE FROM owned_vehicles WHERE owner = ?", { identifier })
	end)

	if ctx.targetId and Helpers.isOnline(ctx.targetId) then
		DropPlayer(ctx.targetId, "Character deleted by an admin.")
	end

	return { success = true, playerOnline = ctx.targetId and Helpers.isOnline(ctx.targetId) or false }
end })

regPlayer("giveMoney", { handler = function(ctx) return moneyHandler(ctx, true) end })
regPlayer("takeMoney", { handler = function(ctx) return moneyHandler(ctx, false) end })

regPlayer("setHealth", { handler = function(ctx)
	TriggerClientEvent("esx-adminmenu:client:setPlayerStats", ctx.targetId, clampNumber(ctx.payload.amount, 0, 100, 100), nil)
	return { success = true, playerOnline = true }
end })

regPlayer("setArmor", { handler = function(ctx)
	TriggerClientEvent("esx-adminmenu:client:setPlayerStats", ctx.targetId, nil, clampNumber(ctx.payload.amount, 0, 100, 100))
	return { success = true, playerOnline = true }
end })

regPlayer("cleanInventory", { handler = function(ctx)
	if not Helpers.isCallable(ctx.target.getInventory) then
		return { success = false, err = "This ESX version does not expose getInventory.", playerOnline = true }
	end

	local inventory = ctx.target.getInventory()
	if type(inventory) ~= "table" then
		return { success = false, err = "Failed to read inventory.", playerOnline = true }
	end

	for i = 1, #inventory do
		local item = inventory[i]
		if item.count and item.count > 0 then
			pcall(function()
				ctx.target.removeInventoryItem(item.name, item.count)
			end)
		end
	end

	return { success = true, playerOnline = true }
end })

regPlayer("killPlayer", { handler = function(ctx)
	TriggerClientEvent("esx-adminmenu:client:kill", ctx.targetId)
	return { success = true, playerOnline = true }
end })

regPlayer("revivePlayer", { handler = function(ctx)
	revivePlayer(ctx.targetId)
	return { success = true, playerOnline = true }
end })

regPlayer("freezePlayer", { handler = function(ctx)
	TriggerClientEvent("esx-adminmenu:client:setFrozen", ctx.targetId, ctx.payload.enabled == true)
	return { success = true, playerOnline = true }
end })

regPlayer("setModel", { handler = function(ctx)
	local model = limitString(ctx.payload.model, 64)
	if model == "" then
		return { success = false, err = "Missing model.", playerOnline = true }
	end

	TriggerClientEvent("esx-adminmenu:client:setModel", ctx.targetId, model)
	return { success = true, playerOnline = true }
end })

regPlayer("openClothing", { handler = function(ctx)
	TriggerClientEvent("esx-adminmenu:client:openClothing", ctx.targetId)
	return { success = true, playerOnline = true }
end })

regPlayer("giveAllWeapons", { handler = function(ctx)
	local weapons = Config.AdminWeapons or {}

	for i = 1, #weapons do
		local weapon = weapons[i]
		local name = weapon.name

		if name and name ~= "" then
			if ctx.target.hasWeapon and ctx.target.hasWeapon(name) and ctx.target.addWeaponAmmo then
				pcall(function()
					ctx.target.addWeaponAmmo(name, tonumber(weapon.ammo) or 250)
				end)
			elseif ctx.target.addWeapon then
				pcall(function()
					ctx.target.addWeapon(name, tonumber(weapon.ammo) or 250)
				end)
			end
		end
	end

	return { success = true, playerOnline = true }
end })

regPlayer("setRoutingBucket", { handler = function(ctx)
	local bucket = math.floor(clampNumber(ctx.payload.bucket, 0, getLimits().MaxRoutingBucket or 2147483647, 0))
	SetPlayerRoutingBucket(ctx.targetId, bucket)
	return { success = true, playerOnline = true }
end })

regPlayer("setRadio", { handler = function(ctx)
	local channel = math.floor(clampNumber(ctx.payload.channel, 0, getLimits().MaxRadioChannel or 10000, 0))
	TriggerClientEvent("esx-adminmenu:client:setRadioChannel", ctx.targetId, channel)
	return { success = true, playerOnline = true }
end })

regPlayer("setJob", { handler = function(ctx)
	local job = limitString(ctx.payload.job, 48)
	local grade = math.floor(clampNumber(ctx.payload.grade, 0, 100, 0))

	if job == "" or not job:match("^[%w_%-]+$") then
		return { success = false, err = "Missing job name.", playerOnline = true }
	end

	if ESX.DoesJobExist and not ESX.DoesJobExist(job, grade) then
		return { success = false, err = "Invalid job or grade.", playerOnline = true }
	end

	if not ctx.target.setJob then
		return { success = false, err = "This ESX version does not expose setJob.", playerOnline = true }
	end

	local ok, err = pcall(function()
		ctx.target.setJob(job, grade)
	end)

	if not ok then
		return { success = false, err = err or "Failed to set job.", playerOnline = true }
	end

	return { success = true, playerOnline = true }
end })

regPlayer("setName", { handler = function(ctx)
	local firstName = limitString(trimString(ctx.payload.firstName), 32)
	local lastName = limitString(trimString(ctx.payload.lastName), 32)

	if firstName == "" or lastName == "" then
		return { success = false, err = "Missing first or last name.", playerOnline = true }
	end

	local identifier = getPlayerIdentifier(ctx.target)
	if not identifier then
		return { success = false, err = "Missing character identifier.", playerOnline = true }
	end

	Helpers.safeUpdate("UPDATE users SET firstname = ?, lastname = ? WHERE identifier = ?", {
		firstName,
		lastName,
		identifier,
	})

	if ctx.target.setName then
		pcall(function()
			ctx.target.setName(firstName .. " " .. lastName)
		end)
	end

	return { success = true, playerOnline = true }
end })

local function statusHandler(ctx, statusName)
	setStatusMeta(ctx.target, ctx.targetId, statusName, ctx.payload.amount)
	return { success = true, playerOnline = true }
end

regPlayer("setThirst", { handler = function(ctx) return statusHandler(ctx, "thirst") end })
regPlayer("setHunger", { handler = function(ctx) return statusHandler(ctx, "hunger") end })

local function aceHandler(ctx, isAdd)
	local group = normalizeAceGroup(ctx.payload.group or ctx.payload.permission)
	if not group then
		return { success = false, err = "Invalid ACE group.", playerOnline = true }
	end

	local identifier = Helpers.getPlayerLicenseIdentifier(ctx.targetId)
	if not isValidIdentifier(identifier) then
		return { success = false, err = "Missing player identifier.", playerOnline = true }
	end

	local command = isAdd and "add_principal" or "remove_principal"
	ExecuteCommand(("%s identifier.%s group.%s"):format(command, identifier, group))

	return { success = true, playerOnline = true }
end

regPlayer("aceAdd", { handler = function(ctx) return aceHandler(ctx, true) end })
regPlayer("aceRemove", { handler = function(ctx) return aceHandler(ctx, false) end })

regPlayer("troll", { handler = function(ctx)
	local trollAction = trimString(ctx.payload.trollAction)
	local allowedTrollActions = Config.TrollActions or {}
	if not allowedTrollActions[trollAction] then
		return { success = false, err = "Invalid troll action.", playerOnline = true }
	end

	TriggerClientEvent("esx-adminmenu:client:troll", ctx.targetId, trollAction)
	return { success = true, playerOnline = true }
end })

---@param src number
---@param data table
---@return AdminActionResult
function Actions.PlayerAction(src, data)
	data = data or {}

	local action = type(data.action) == "string" and data.action or "unknown"

	if not Helpers.hasPermission(src) then
		Logs.record({ namespace = "playerActions", action = action, actor = src,
			success = false, err = "Insufficient Permissions" })
		return { success = false, err = "Insufficient Permissions" }
	end

	local spec = PlayerHandlers[data.action]
	if not spec then
		return { success = false, err = "Unknown player action.", playerOnline = true }
	end

	local targetId = getTargetId(data)
	local target = targetId and ESX.GetPlayerFromId(targetId) or nil

	local permission = Helpers.getActionPermission("playerActions", data.action)
	if permission and not Helpers.hasFeaturePermission(src, permission) then
		Logs.record({ namespace = "playerActions", action = action, actor = src, target = targetId,
			success = false, err = "Insufficient Permissions" })
		return { success = false, err = "Insufficient Permissions", playerOnline = target ~= nil }
	end

	if not spec.offline and not target then
		return { success = false, err = "Player Not Online", playerOnline = false }
	end

	-- Resolved before the handler runs: deleteCharacter and friends drop the
	-- player, after which the target can no longer be identified.
	local targetIdentifier = targetId and Helpers.getPlayerLicenseIdentifier(targetId) or nil
	local targetName = targetId and GetPlayerName(targetId) or nil

	local result = spec.handler({ src = src, targetId = targetId, target = target, payload = data.payload or {} })

	-- Acting on someone makes them "recent" straight away, so admins can find
	-- them again without waiting for a disconnect. Snapshotted after the handler
	-- so the entry reflects the post-action state (money, health, job...).
	if target and targetId and type(result) == "table" and result.success then
		Helpers.addRecentPlayer(targetId, "online")
	end

	Logs.record({
		namespace = "playerActions",
		action = action,
		actor = src,
		target = targetIdentifier,
		targetName = targetName,
		success = type(result) ~= "table" or result.success ~= false,
		err = type(result) == "table" and result.err or nil,
		payload = data.payload,
	})

	return result
end

Helpers.registerCallback("esx-adminmenu:server:playerAction", function(source, data)
	return Actions.PlayerAction(source, data)
end)
