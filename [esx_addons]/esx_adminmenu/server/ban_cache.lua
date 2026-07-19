BanCache = {}
local bans = {}

-- Single source of truth lives in Helpers; ban_cache.lua loads after helpers.lua.
local function normalizeIdentifier(identifier)
	return Helpers.normalizeLicenseIdentifier(identifier) or identifier
end

local function normalizeTimestamp(value)
	return Helpers.normalizeTimestamp(value)
end

-- Single expiry predicate shared by the reader and the maintenance prune.
local function isExpired(ban, now)
	local expires = normalizeTimestamp(ban.expires_at)
	return expires ~= nil and now >= expires
end

-- Maintenance: owns all expiry-driven cache mutation so readers stay side-effect free.
function BanCache.prune()
	local now = os.time()

	for identifier, list in pairs(bans) do
		for i = #list, 1, -1 do
			if isExpired(list[i], now) then
				table.remove(list, i)
			end
		end

		if #list == 0 then
			bans[identifier] = nil
		end
	end
end

function BanCache.load()
	-- Clear existing cache for ex. command usage.
	bans = {}

	local rows = Helpers.safeQuery("SELECT * FROM bans ORDER BY id ASC")
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

-- Read-only: returns the most recent still-active ban for the identifier, or nil.
-- Expired entries are left for BanCache.prune to reap, never removed on read.
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

		if not (expires and now >= expires) then
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

	for i = 1, #list do
		list[i].expires_at = newExpiry
	end

	BanCache.prune()
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

-- Low-frequency maintenance so expired entries never accumulate unbounded.
CreateThread(function()
	while true do
		Wait(60000)
		BanCache.prune()
	end
end)

return BanCache
