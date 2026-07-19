BanCache = {}

-- Flat list of ban records (each may carry an `identifiers` array of raw
-- identifier strings), plus an index mapping every identifier -> ban refs so a
-- connecting player is matched on ANY of their identifiers, not just license.
local banList = {}
local index = {}
local generation = 0

-- Bumped on every mutation so read-side caches (e.g. the sorted ban page) can
-- detect staleness without re-sorting on every request.
local function bump()
	generation = generation + 1
end

function BanCache.getGeneration()
	return generation
end

local function normalizeTimestamp(value)
	return Helpers.normalizeTimestamp(value)
end

-- Single expiry predicate shared by the reader and the maintenance prune.
local function isExpired(ban, now)
	local expires = normalizeTimestamp(ban.expires_at)
	return expires ~= nil and now >= expires
end

-- Every identifier a ban should be matchable by: the primary plus its array, deduped.
local function banIdentifiers(ban)
	local seen = {}
	local out = {}

	local function push(id)
		if type(id) == "string" and id ~= "" and not seen[id] then
			seen[id] = true
			out[#out + 1] = id
		end
	end

	push(ban.identifier)
	if type(ban.identifiers) == "table" then
		for i = 1, #ban.identifiers do
			push(ban.identifiers[i])
		end
	end

	return out
end

local function addToIndex(ban)
	for _, id in ipairs(banIdentifiers(ban)) do
		if not index[id] then
			index[id] = {}
		end
		index[id][#index[id] + 1] = ban
	end
end

local function rebuildIndex()
	index = {}
	for i = 1, #banList do
		addToIndex(banList[i])
	end
end

-- Maintenance: owns all expiry-driven cache mutation so readers stay side-effect free.
function BanCache.prune()
	local now = os.time()
	local changed = false

	for i = #banList, 1, -1 do
		if isExpired(banList[i], now) then
			table.remove(banList, i)
			changed = true
		end
	end

	if changed then
		rebuildIndex()
		bump()
	end
end

function BanCache.load()
	banList = {}
	index = {}

	local rows = Helpers.safeQuery("SELECT * FROM bans ORDER BY id ASC")
	if rows then
		for i = 1, #rows do
			local ban = rows[i]

			if type(ban.identifiers) == "string" and ban.identifiers ~= "" then
				local ok, decoded = pcall(json.decode, ban.identifiers)
				ban.identifiers = (ok and type(decoded) == "table") and decoded or nil
			end

			banList[#banList + 1] = ban
			addToIndex(ban)
		end
	end

	bump()
end

-- Read-only: most recent still-active ban matching this identifier, or nil.
-- Expired entries are left for BanCache.prune, never removed on read.
function BanCache.get(identifier)
	if type(identifier) ~= "string" or identifier == "" then
		return nil
	end

	local list = index[identifier]
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

	if type(ban.identifier) ~= "string" or ban.identifier == "" then
		return
	end

	banList[#banList + 1] = ban
	addToIndex(ban)
	bump()
end

-- Bans are keyed for update/remove by their primary identifier (license).
function BanCache.updateExpiry(identifier, newExpiry)
	if type(identifier) ~= "string" then
		return
	end

	local changed = false

	for i = 1, #banList do
		if banList[i].identifier == identifier then
			banList[i].expires_at = newExpiry
			changed = true
		end
	end

	if changed then
		-- Drop any that just became expired and refresh the index/generation.
		BanCache.prune()
		bump()
	end
end

function BanCache.remove(identifier)
	if type(identifier) ~= "string" then
		return
	end

	local changed = false

	for i = #banList, 1, -1 do
		if banList[i].identifier == identifier then
			table.remove(banList, i)
			changed = true
		end
	end

	if changed then
		rebuildIndex()
		bump()
	end
end

-- Flat ban list, consumed by the active-ban pagination in Helpers.
function BanCache.getAll()
	return banList
end

-- Low-frequency maintenance so expired entries never accumulate unbounded.
CreateThread(function()
	while true do
		Wait(60000)
		BanCache.prune()
	end
end)

return BanCache
