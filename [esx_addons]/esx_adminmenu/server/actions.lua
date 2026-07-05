Actions = Actions or {}

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

local function trimString(value)
	if type(value) ~= "string" then
		return ""
	end

	return value:match("^%s*(.-)%s*$")
end

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

local function insertBan(identifier, reason, bannedBy, expiresAt, bannedAt)
	identifier = Helpers.normalizeLicenseIdentifier(identifier)
	if not identifier then
		return nil
	end

	if expiresAt then
		return MySQL.insert.await(
			"INSERT INTO bans (identifier, reason, banned_by, expires_at, banned_at) VALUES (?, ?, ?, FROM_UNIXTIME(?), FROM_UNIXTIME(?))",
			{ identifier, reason, bannedBy, expiresAt, bannedAt }
		)
	end

	return MySQL.insert.await(
		"INSERT INTO bans (identifier, reason, banned_by, expires_at, banned_at) VALUES (?, ?, ?, NULL, FROM_UNIXTIME(?))",
		{ identifier, reason, bannedBy, bannedAt }
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

local function getPlayerIdentifier(xPlayer, source)
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
	local identifier = getPlayerIdentifier(target, targetId)

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
	local serverConfig = Config.ServerManagement or {}
	local actionPermissions = serverConfig.ActionPermissions or {}

	return actionPermissions[action] or "serverManagement"
end

local function withServerData(data)
	data = data or {}
	data.serverData = Helpers.getServerData()
	return data
end

local function getPlayerActionPermission(action)
	local playerConfig = Config.PlayerActions or {}
	local actionPermissions = playerConfig.ActionPermissions or {}

	return actionPermissions[action]
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

	local admin = ESX.Player(src)
	local target = ESX.Player(targetId)
	if not admin or not target then
		return { success = false, playerOnline = target ~= nil }
	end

	admin.setCoords(target.getCoords(true))
	return { success = true, playerOnline = true }
end

ESX.RegisterServerCallback("esx-adminmenu:server:goto", function(source, cb, data)
	cb(Actions.Goto(source, data))
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

	local admin = ESX.Player(src)
	local target = ESX.Player(targetId)
	if not admin or not target then
		return { success = false, playerOnline = target ~= nil }
	end

	target.setCoords(admin.getCoords(true))
	return { success = true, playerOnline = true }
end

ESX.RegisterServerCallback("esx-adminmenu:server:bring", function(source, cb, data)
	cb(Actions.Bring(source, data))
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

ESX.RegisterServerCallback("esx-adminmenu:server:spectate", function(source, cb, data)
	cb(Actions.Spectate(source, data))
end)

function Actions.StopSpectate(src)
	Helpers.stopSpectate(src)
	return { success = true }
end

ESX.RegisterServerCallback("esx-adminmenu:server:spectate:stop", function(source, cb)
	cb(Actions.StopSpectate(source))
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

	async(function()
		local identifier = Helpers.getPlayerLicenseIdentifier(targetId)
		local reason = limitString(data.reason, getLimits().MaxReasonLength, "Kicked by admin")

		MySQL.insert.await(
			"INSERT INTO kicks (identifier, reason, kicked_by) VALUES (?, ?, ?)",
			{ identifier, reason, GetPlayerName(src) }
		)

		DropPlayer(targetId, reason)
	end)

	return { success = true, playerOnline = true, isAdmin = true }
end

ESX.RegisterServerCallback("esx-adminmenu:server:kick", function(source, cb, data)
	cb(Actions.Kick(source, data))
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

	async(function()
		local duration = normalizeBanDuration(data.duration)
		local seconds = duration and (os.time() + duration * 60) or nil
		local bannedAt = os.time()
		local adminName = GetPlayerName(src)
		local reason = limitString(data.reason, getLimits().MaxReasonLength, "Banned by admin")

		local banId = insertBan(identifier, reason, adminName, seconds, bannedAt)

		BanCache.add({
			id = banId,
			identifier = identifier,
			reason = reason,
			banned_by = adminName,
			banned_at = bannedAt,
			expires_at = seconds,
		})

		DropPlayer(targetId, reason)
	end)
	return { success = true, playerOnline = true, isAdmin = true }
end

ESX.RegisterServerCallback("esx-adminmenu:server:ban", function(source, cb, data)
	cb(Actions.Ban(source, data))
end)

-- OFFLINE BAN

ESX.RegisterServerCallback("esx-adminmenu:server:ban:offline", function(source, cb, data)
	local src = source
	if not Helpers.hasFeaturePermission(source, "banManagement") then
		cb({ success = false, err = "Insufficient Permissions", isAdmin = false })
		return
	end

	data = data or {}

	local normalizedIdentifier = Helpers.normalizeLicenseIdentifier(data.identifier)
	if not normalizedIdentifier then
		cb({ success = false, err = "Invalid Identifier", isAdmin = true })
		return
	end

	cb({ success = true, isAdmin = true })

	async(function()
		local duration = normalizeBanDuration(data.duration)
		local seconds = duration and (os.time() + duration * 60) or nil
		local bannedAt = os.time()
		local identifier = normalizedIdentifier
		local adminName = GetPlayerName(src)
		local reason = limitString(data.reason, getLimits().MaxReasonLength, "Banned by admin")

		local banId = insertBan(identifier, reason, adminName, seconds, bannedAt)

		BanCache.add({
			id = banId,
			identifier = identifier,
			reason = reason,
			banned_by = adminName,
			banned_at = bannedAt,
			expires_at = seconds,
		})
	end)
end)

-- CHANGE EXPIRY

ESX.RegisterServerCallback("esx-adminmenu:server:ban:changeExpiry", function(source, cb, data)
	if not Helpers.hasFeaturePermission(source, "banManagement") then
		cb({ success = false, err = "Insufficient Permissions", isAdmin = false })
		return
	end

	data = data or {}

	local normalizedIdentifier = Helpers.normalizeLicenseIdentifier(data.identifier)
	if not normalizedIdentifier then
		cb({ success = false, err = "Invalid Identifier", isAdmin = true })
		return
	end

	local seconds = nil
	if data.newDate ~= nil then
		local newDate = tonumber(data.newDate)
		if not newDate then
			cb({ success = false, err = "Invalid expiry date.", isAdmin = true })
			return
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

	cb({ success = true, isAdmin = true })

	async(function()
		updateBanExpiry(normalizedIdentifier, seconds)
		BanCache.updateExpiry(normalizedIdentifier, seconds)
	end)
end)

-- REVOKE

ESX.RegisterServerCallback("esx-adminmenu:server:ban:revoke", function(source, cb, data)
	if not Helpers.hasFeaturePermission(source, "banManagement") then
		cb({ success = false, err = "Insufficient Permissions", isAdmin = false })
		return
	end

	data = data or {}

	local normalizedIdentifier = Helpers.normalizeLicenseIdentifier(data.identifier)
	if not normalizedIdentifier then
		cb({ success = false, err = "Invalid Identifier", isAdmin = true })
		return
	end

	cb({ success = true, isAdmin = true })

	async(function()
		expireBan(normalizedIdentifier)
		BanCache.remove(normalizedIdentifier)
	end)
end)

-- VEHICLES

local function vehicleAsync(source, cb, data, query, params, feature)
	if not Helpers.hasFeaturePermission(source, feature or "vehicleManagement") then
		cb({ success = false, err = "Insufficient Permissions" })
		return
	end

	data = data or {}
	params = params or {}
	local plate = normalizePlate(data.plate)

	if not plate then
		cb({ success = false, err = "Missing plate" })
		return
	end

	params[#params + 1] = plate
	cb({ success = true })

	async(function()
		MySQL.update.await(query, params)
		Helpers.invalidateVehicles()
	end)
end

ESX.RegisterServerCallback("esx-adminmenu:server:vehicleImpound", function(source, cb, data)
	data = data or {}
	local impoundName = trimString(data.impoundName)
	local impounds = Helpers.getImpounds() or {}

	if impoundName == "" or not impounds[impoundName] then
		cb({ success = false, err = "Invalid impound." })
		return
	end

	vehicleAsync(
		source,
		cb,
		data,
		"UPDATE owned_vehicles SET pound = ? WHERE plate = ?",
		{ impoundName },
		"vehicleManagement"
	)
end)

ESX.RegisterServerCallback("esx-adminmenu:server:vehicleUnimpound", function(source, cb, data)
	data = data or {}

	vehicleAsync(source, cb, data, "UPDATE owned_vehicles SET pound = NULL WHERE plate = ?", {}, "vehicleManagement")
end)

ESX.RegisterServerCallback("esx-adminmenu:server:vehicleDelete", function(source, cb, data)
	data = data or {}

	vehicleAsync(source, cb, data, "DELETE FROM owned_vehicles WHERE plate = ?", {}, "vehicleDestructive")
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

ESX.RegisterServerCallback("esx-adminmenu:server:notify", function(source, cb, data)
	cb(Actions.Notify(source, data))
end)

-- SELF ACTIONS

function Actions.SelfAction(src, data)
	data = data or {}

	if not Helpers.hasPermission(src) then
		return { success = false, err = "Insufficient Permissions" }
	end

	local action = data.action
	local actionPermissions = Config.AdminMenu and Config.AdminMenu.ActionPermissions or {}
	local feature = actionPermissions[action]

	if not feature or not Helpers.hasFeaturePermission(src, feature) then
		return { success = false, err = "Insufficient Permissions" }
	end

	if action == "revive" then
		revivePlayer(src)
		return { success = true }
	end

	return { success = false, err = "Unknown self action." }
end

ESX.RegisterServerCallback("esx-adminmenu:server:selfAction", function(source, cb, data)
	cb(Actions.SelfAction(source, data))
end)

-- SERVER MANAGEMENT

function Actions.ServerManagement(src, data)
	data = data or {}

	if not Helpers.hasFeaturePermission(src, "serverManagement") then
		return { success = false, err = "Insufficient Permissions" }
	end

	local action = data.action
	local payload = data.payload or {}

	if not Helpers.hasFeaturePermission(src, getServerActionPermission(action)) then
		return { success = false, err = "Insufficient Permissions" }
	end

	if action == "weather" then
		local weather = trimString(payload.weather):upper()
		local allowedWeather = Config.ServerManagement and Config.ServerManagement.WeatherTypes or {}
		if not allowedWeather[weather] then
			weather = "CLEAR"
		end

		Helpers.setServerEnvironment({ weather = weather })
		TriggerClientEvent("esx-adminmenu:client:setWeather", -1, weather)
		return withServerData({ success = true })
	end

	if action == "time" then
		local hour = math.floor(clampNumber(payload.hour, 0, 23, 12))
		local minute = math.floor(clampNumber(payload.minute, 0, 59, 0))

		Helpers.setServerEnvironment({ hour = hour, minute = minute })
		TriggerClientEvent("esx-adminmenu:client:setTime", -1, hour, minute)
		return withServerData({ success = true })
	end

	if action == "blackout" then
		local enabled = getBoolean(payload.enabled)
		Helpers.setServerEnvironment({ blackout = enabled })
		TriggerClientEvent("esx-adminmenu:client:setBlackout", -1, enabled)
		return withServerData({ success = true })
	end

	if action == "pvp" then
		local enabled = getBoolean(payload.enabled)
		Helpers.setServerEnvironment({ pvp = enabled })
		TriggerClientEvent("esx-adminmenu:client:setPvp", -1, enabled)
		return withServerData({ success = true })
	end

	if action == "freezeAll" then
		TriggerClientEvent("esx-adminmenu:client:setFrozen", -1, true)
		return { success = true }
	end

	if action == "unfreezeAll" then
		TriggerClientEvent("esx-adminmenu:client:setFrozen", -1, false)
		return { success = true }
	end

	if action == "bringAll" then
		local admin = ESX.Player(src)
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
	end

	if action == "killAll" then
		TriggerClientEvent("esx-adminmenu:client:kill", -1)
		return { success = true }
	end

	if action == "reviveAll" then
		revivePlayer(-1)
		return { success = true }
	end

	if action == "kickAll" then
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
	end

	if action == "deleteVehicles" then
		TriggerClientEvent("esx-adminmenu:client:deletePool", -1, "CVehicle")
		return { success = true }
	end

	if action == "deletePeds" then
		TriggerClientEvent("esx-adminmenu:client:deletePool", -1, "CPed")
		return { success = true }
	end

	if action == "deleteObjects" then
		TriggerClientEvent("esx-adminmenu:client:deletePool", -1, "CObject")
		return { success = true }
	end

	if action == "notifyAll" then
		local message = limitString(payload.message, getLimits().MaxNotificationLength, "Notification by Admin")
		local notificationType = normalizeNotificationType(payload.notificationType)
		local duration = math.floor(clampNumber(payload.duration, 1000, getLimits().MaxNotificationDuration or 30000,
			5000))
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
	end

	if action == "giveMoneyAll" then
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
	end

	return { success = false, err = "Unknown server action." }
end

ESX.RegisterServerCallback("esx-adminmenu:server:serverAction", function(source, cb, data)
	cb(Actions.ServerManagement(source, data))
end)

-- PLAYER MANAGEMENT

function Actions.PlayerAction(src, data)
	data = data or {}

	if not Helpers.hasPermission(src) then
		return { success = false, err = "Insufficient Permissions" }
	end

	local action = data.action
	local payload = data.payload or {}
	local targetId = getTargetId(data)
	local target = targetId and ESX.GetPlayerFromId(targetId) or nil
	local actionPermission = getPlayerActionPermission(action)

	if actionPermission and not Helpers.hasFeaturePermission(src, actionPermission) then
		return { success = false, err = "Insufficient Permissions", playerOnline = target ~= nil }
	end

	if action == "deleteCharacter" then
		local identifier = trimString(payload.identifier)

		if not isValidCharacterIdentifier(identifier) then
			return { success = false, err = "Missing character identifier." }
		end

		if target then
			local targetIdentifier = getOnlineCharacterIdentifier(target, targetId)

			if targetIdentifier ~= identifier then
				return { success = false, err = "Character identifier does not match the selected player.", playerOnline = true }
			end
		end

		async(function()
			MySQL.update.await("DELETE FROM users WHERE identifier = ?", { identifier })
			MySQL.update.await("DELETE FROM owned_vehicles WHERE owner = ?", { identifier })
		end)

		if targetId and Helpers.isOnline(targetId) then
			DropPlayer(targetId, "Character deleted by an admin.")
		end

		return { success = true, playerOnline = targetId and Helpers.isOnline(targetId) or false }
	end

	if not target then
		return { success = false, err = "Player Not Online", playerOnline = false }
	end

	if action == "giveMoney" or action == "takeMoney" then
		if not Helpers.hasFeaturePermission(src, "money") then
			return { success = false, err = "Insufficient Permissions", playerOnline = true }
		end

		local amount = normalizeMoneyAmount(payload.amount)
		local account = normalizeMoneyAccount(payload.account)

		if amount <= 0 then
			return { success = false, err = "Amount must be greater than 0.", playerOnline = true }
		end

		if action == "giveMoney" then
			if account == "money" then
				target.addMoney(amount, "Admin menu")
			else
				target.addAccountMoney(account, amount, "Admin menu")
			end
		else
			if account == "money" then
				target.removeMoney(amount, "Admin menu")
			else
				target.removeAccountMoney(account, amount, "Admin menu")
			end
		end

		return { success = true, playerOnline = true }
	end

	if action == "setHealth" then
		TriggerClientEvent("esx-adminmenu:client:setPlayerStats", targetId, clampNumber(payload.amount, 0, 100, 100), nil)
		return { success = true, playerOnline = true }
	end

	if action == "setArmor" then
		TriggerClientEvent("esx-adminmenu:client:setPlayerStats", targetId, nil, clampNumber(payload.amount, 0, 100, 100))
		return { success = true, playerOnline = true }
	end

	if action == "cleanInventory" then
		local inventory = target.getInventory()

		for i = 1, #inventory do
			local item = inventory[i]
			if item.count and item.count > 0 then
				target.removeInventoryItem(item.name, item.count)
			end
		end

		return { success = true, playerOnline = true }
	end

	if action == "killPlayer" then
		TriggerClientEvent("esx-adminmenu:client:kill", targetId)
		return { success = true, playerOnline = true }
	end

	if action == "revivePlayer" then
		revivePlayer(targetId)
		return { success = true, playerOnline = true }
	end

	if action == "freezePlayer" then
		TriggerClientEvent("esx-adminmenu:client:setFrozen", targetId, payload.enabled == true)
		return { success = true, playerOnline = true }
	end

	if action == "setModel" then
		if not Helpers.hasFeaturePermission(src, "setModel") then
			return { success = false, err = "Insufficient Permissions", playerOnline = true }
		end

		local model = limitString(payload.model, 64)
		if model == "" then
			return { success = false, err = "Missing model.", playerOnline = true }
		end

		TriggerClientEvent("esx-adminmenu:client:setModel", targetId, model)
		return { success = true, playerOnline = true }
	end

	if action == "openClothing" then
		if not Helpers.hasFeaturePermission(src, "openClothing") then
			return { success = false, err = "Insufficient Permissions", playerOnline = true }
		end

		TriggerClientEvent("esx-adminmenu:client:openClothing", targetId)
		return { success = true, playerOnline = true }
	end

	if action == "giveAllWeapons" then
		if not Helpers.hasFeaturePermission(src, "weapons") then
			return { success = false, err = "Insufficient Permissions", playerOnline = true }
		end

		local weapons = Config.AdminWeapons or {}

		for i = 1, #weapons do
			local weapon = weapons[i]
			local name = weapon.name

			if name and name ~= "" then
				if target.hasWeapon and target.hasWeapon(name) and target.addWeaponAmmo then
					pcall(function()
						target.addWeaponAmmo(name, tonumber(weapon.ammo) or 250)
					end)
				elseif target.addWeapon then
					pcall(function()
						target.addWeapon(name, tonumber(weapon.ammo) or 250)
					end)
				end
			end
		end

		return { success = true, playerOnline = true }
	end

	if action == "setRoutingBucket" then
		if not Helpers.hasFeaturePermission(src, "routingBucket") then
			return { success = false, err = "Insufficient Permissions", playerOnline = true }
		end

		local bucket = math.floor(clampNumber(payload.bucket, 0, getLimits().MaxRoutingBucket or 2147483647, 0))
		SetPlayerRoutingBucket(targetId, bucket)
		return { success = true, playerOnline = true }
	end

	if action == "setRadio" then
		if not Helpers.hasFeaturePermission(src, "playerData") then
			return { success = false, err = "Insufficient Permissions", playerOnline = true }
		end

		local channel = math.floor(clampNumber(payload.channel, 0, getLimits().MaxRadioChannel or 10000, 0))
		TriggerClientEvent("esx-adminmenu:client:setRadioChannel", targetId, channel)
		return { success = true, playerOnline = true }
	end

	if action == "setJob" then
		if not Helpers.hasFeaturePermission(src, "playerData") then
			return { success = false, err = "Insufficient Permissions", playerOnline = true }
		end

		local job = limitString(payload.job, 48)
		local grade = math.floor(clampNumber(payload.grade, 0, 100, 0))

		if job == "" or not job:match("^[%w_%-]+$") then
			return { success = false, err = "Missing job name.", playerOnline = true }
		end

		if ESX.DoesJobExist and not ESX.DoesJobExist(job, grade) then
			return { success = false, err = "Invalid job or grade.", playerOnline = true }
		end

		if not target.setJob then
			return { success = false, err = "This ESX version does not expose setJob.", playerOnline = true }
		end

		local ok, err = pcall(function()
			target.setJob(job, grade)
		end)

		if not ok then
			return { success = false, err = err or "Failed to set job.", playerOnline = true }
		end

		return { success = true, playerOnline = true }
	end

	if action == "setName" then
		if not Helpers.hasFeaturePermission(src, "playerData") then
			return { success = false, err = "Insufficient Permissions", playerOnline = true }
		end

		local firstName = trimString(payload.firstName)
		local lastName = trimString(payload.lastName)

		firstName = limitString(firstName, 32)
		lastName = limitString(lastName, 32)

		if firstName == "" or lastName == "" then
			return { success = false, err = "Missing first or last name.", playerOnline = true }
		end

		local identifier = getPlayerIdentifier(target, targetId)
		if not identifier then
			return { success = false, err = "Missing character identifier.", playerOnline = true }
		end

		MySQL.update.await("UPDATE users SET firstname = ?, lastname = ? WHERE identifier = ?", {
			firstName,
			lastName,
			identifier,
		})

		if target.setName then
			pcall(function()
				target.setName(firstName .. " " .. lastName)
			end)
		end

		return { success = true, playerOnline = true }
	end

	if action == "setThirst" or action == "setHunger" then
		if not Helpers.hasFeaturePermission(src, "playerData") then
			return { success = false, err = "Insufficient Permissions", playerOnline = true }
		end

		local statusName = action == "setThirst" and "thirst" or "hunger"
		setStatusMeta(target, targetId, statusName, payload.amount)
		return { success = true, playerOnline = true }
	end

	if action == "aceAdd" or action == "aceRemove" then
		if not Helpers.hasFeaturePermission(src, "acePermissions") then
			return { success = false, err = "Insufficient Permissions", playerOnline = true }
		end

		local group = normalizeAceGroup(payload.group or payload.permission)
		if not group then
			return { success = false, err = "Invalid ACE group.", playerOnline = true }
		end

		local identifier = Helpers.getPlayerLicenseIdentifier(targetId)
		if not isValidIdentifier(identifier) then
			return { success = false, err = "Missing player identifier.", playerOnline = true }
		end

		local command = action == "aceAdd" and "add_principal" or "remove_principal"
		ExecuteCommand(("%s identifier.%s group.%s"):format(command, identifier, group))

		return { success = true, playerOnline = true }
	end

	if action == "troll" then
		if not Helpers.hasFeaturePermission(src, "troll") then
			return { success = false, err = "Insufficient Permissions", playerOnline = true }
		end

		local trollAction = trimString(payload.trollAction)
		local allowedTrollActions = Config.TrollActions or {}
		if not allowedTrollActions[trollAction] then
			return { success = false, err = "Invalid troll action.", playerOnline = true }
		end

		TriggerClientEvent("esx-adminmenu:client:troll", targetId, trollAction)
		return { success = true, playerOnline = true }
	end

	return { success = false, err = "Unknown player action.", playerOnline = true }
end

ESX.RegisterServerCallback("esx-adminmenu:server:playerAction", function(source, cb, data)
	cb(Actions.PlayerAction(source, data))
end)
