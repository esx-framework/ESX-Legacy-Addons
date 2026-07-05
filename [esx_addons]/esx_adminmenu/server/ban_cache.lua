BanCache = {}
local translations
local bans = {}

local function normalizeIdentifier(identifier)
	if Helpers and Helpers.normalizeLicenseIdentifier then
		return Helpers.normalizeLicenseIdentifier(identifier) or identifier
	end

	if type(identifier) ~= "string" or identifier == "" then
		return identifier
	end

	if identifier:match("^license:[%w%-_]+$") then
		return identifier
	end

	if not identifier:find(":") and identifier:match("^[%w%-_]+$") then
		return "license:" .. identifier
	end

	return identifier
end

local function normalizeTimestamp(value)
	if Helpers and Helpers.normalizeTimestamp then
		return Helpers.normalizeTimestamp(value)
	end

	if value == nil or value == "" then
		return nil
	end

	if type(value) == "number" then
		if value <= 0 then
			return nil
		end

		if value > 1e12 then
			return math.floor(value / 1000)
		end

		return math.floor(value)
	end

	if type(value) == "string" then
		value = value:match("^%s*(.-)%s*$")
		if value == "" or value:find("^0000%-00%-00") then
			return nil
		end

		local numeric = tonumber(value)
		if numeric then
			return normalizeTimestamp(numeric)
		end

		local year, month, day, hour, min, sec = value:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)[ T](%d%d):(%d%d):(%d%d)")
		if year then
			local ok, timestamp = pcall(os.time, {
				year = tonumber(year),
				month = tonumber(month),
				day = tonumber(day),
				hour = tonumber(hour),
				min = tonumber(min),
				sec = tonumber(sec),
			})

			if ok and timestamp and timestamp > 0 then
				return timestamp
			end
		end
	end

	return nil
end

function BanCache.load()
	-- Clear existing cache for ex. command usage.
	bans = {}

	local rows = MySQL.query.await("SELECT * FROM bans ORDER BY id ASC")
	if not rows then
		return
	end

	for i = 1, #rows do
		local ban = rows[i]
		local identifier = normalizeIdentifier(ban.identifier)
		ban.identifier = identifier

		if not bans[identifier] then
			bans[identifier] = {}
		end

		bans[identifier][#bans[identifier] + 1] = ban
	end
end

function BanCache.get(identifier)
	identifier = normalizeIdentifier(identifier)
	if not identifier then
		return nil
	end

	local list = bans[identifier]
	if not list then
		return nil
	end

	local now = os.time()

	for i = #list, 1, -1 do
		local ban = list[i]

		local expires = normalizeTimestamp(ban.expires_at)

		if expires and now >= expires then
			table.remove(list, i)
		else
			if expires then
				local remaining = expires - now
				ban.remaining_seconds = remaining
				ban.remaining_formatted = Helpers.formatRemainingTime(remaining)
			else
				ban.remaining_seconds = nil
				ban.remaining_formatted = Helpers.getTranslation("permanent")
			end

			return ban
		end
	end

	if #list == 0 then
		bans[identifier] = nil
	end

	return nil
end

function BanCache.add(ban)
	if not ban.banned_at then
		ban.banned_at = os.time()
	end

	ban.identifier = normalizeIdentifier(ban.identifier)
	if not ban.identifier then
		return
	end

	if not bans[ban.identifier] then
		bans[ban.identifier] = {}
	end

	bans[ban.identifier][#bans[ban.identifier] + 1] = ban
end

function BanCache.updateExpiry(identifier, newExpiry)
	identifier = normalizeIdentifier(identifier)
	if not identifier then
		return
	end

	local list = bans[identifier]
	if not list then
		return
	end

	for i = #list, 1, -1 do
		local ban = list[i]
		ban.expires_at = newExpiry
		return
	end
end

-- No need for this at the moment but in case the logic changes this might be useful.
function BanCache.expireNow(identifier)
	identifier = normalizeIdentifier(identifier)
	if not identifier then
		return
	end

	local list = bans[identifier]
	if not list then
		return
	end

	local now = os.time()

	for i = #list, 1, -1 do
		local ban = list[i]
		ban.expires_at = now
	end
end

function BanCache.remove(identifier)
	identifier = normalizeIdentifier(identifier)
	if not identifier then
		return
	end

	bans[identifier] = nil
end

function BanCache.getAll()
	return bans
end

return BanCache
