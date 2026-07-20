-- Admin action log.
--
-- Recording must never slow down or break an admin action, so entries are
-- queued in memory and flushed to the database in batches by a background
-- thread. Every database call goes through Helpers.safeQuery, so a dead
-- database degrades into lost log lines, never into a failed moderation.

Logs = {}

-- Queue held as an explicit head/tail window instead of table.remove(t, 1),
-- which is O(n) and would get expensive at the cap.
local queue = {}
local head, tail = 1, 0
local dropped = 0
local flushing = false

local INSERT_COLUMNS =
"INSERT INTO admin_logs (created_at, actor_identifier, actor_name, namespace, action, target_identifier, target_name, success, error, payload) VALUES "
local COLUMN_COUNT = 10

--- Column values in INSERT order. Holes are expected: target_name, error and
--- payload are frequently nil.
local function rowValues(row)
    return {
        row.at,
        row.actor_identifier,
        row.actor_name,
        row.namespace,
        row.action,
        row.target_identifier,
        row.target_name,
        row.success,
        row.error,
        row.payload,
    }
end

--- Appends one row's placeholders and parameters.
--- A nil is written as a literal NULL in the statement instead of being bound,
--- because `params[#params + 1] = nil` appends nothing in Lua: the value is
--- silently dropped and every following parameter shifts one column left.
local function appendRow(row, placeholders, params)
    local values = rowValues(row)
    local parts = {}

    for i = 1, COLUMN_COUNT do
        local value = values[i]

        if value == nil then
            parts[i] = "NULL"
        elseif i == 1 then
            parts[i] = "FROM_UNIXTIME(?)"
            params[#params + 1] = value
        else
            parts[i] = "?"
            params[#params + 1] = value
        end
    end

    placeholders[#placeholders + 1] = "(" .. table.concat(parts, ",") .. ")"
end

-- Never persisted: these either leak network identity or duplicate a column.
local REDACTED_KEYS = {
    ip = true,
    identifiers = true,
    license = true,
    token = true,
    password = true,
    pincode = true,
}

local function config()
    return Config.Logs or {}
end

local function isEnabled()
    return config().Enabled ~= false
end

local function queueCount()
    return tail - head + 1
end

--- Builds a compact, safe JSON payload.
--- Nested tables are collapsed rather than serialised: a vehicle props blob is
--- several kilobytes and has no forensic value in a log line.
local function encodePayload(payload)
    if type(payload) ~= "table" then
        return nil
    end

    local clean = {}
    local empty = true

    for key, value in pairs(payload) do
        if not REDACTED_KEYS[key] then
            local valueType = type(value)

            if valueType == "string" or valueType == "number" or valueType == "boolean" then
                clean[key] = value
                empty = false
            elseif valueType == "table" then
                clean[key] = "<table>"
                empty = false
            end
        end
    end

    if empty then
        return nil
    end

    local ok, encoded = pcall(json.encode, clean)
    if not ok or type(encoded) ~= "string" then
        return nil
    end

    local maxBytes = tonumber(config().MaxPayloadBytes) or 2048
    if #encoded > maxBytes then
        -- Cutting the string mid-token would store invalid JSON, so replace it
        -- with a marker that still parses.
        return ('{"_truncated":true,"bytes":%d}'):format(#encoded)
    end

    return encoded
end

local function shouldRecord(action)
    local ignore = config().Ignore
    return not (ignore and ignore[action])
end

-- Per-source sliding window. Server callbacks are reachable by any client, so
-- without this a non-admin could spam denied attempts until the bounded queue
-- evicted every real entry.
local rateWindow = 0
local rateCounts = {}
local rateMuted = {}

local function withinRate(actor)
    local limit = tonumber(config().MaxPerMinutePerActor) or 120
    if limit <= 0 then
        return true
    end

    local key = tostring(actor or "unknown")
    local window = math.floor(os.time() / 60)

    if window ~= rateWindow then
        rateWindow = window
        rateCounts = {}
        rateMuted = {}
    end

    local count = (rateCounts[key] or 0) + 1
    rateCounts[key] = count

    if count > limit then
        -- Announce the mute once per window rather than on every dropped entry.
        if not rateMuted[key] then
            rateMuted[key] = true
            print(("[esx-adminmenu] Log rate limit hit for %s, muted for this minute"):format(key))
        end
        return false
    end

    return true
end

--- Resolves a player source (or a raw identifier string) into identifier + name.
local function resolveActor(value)
    if type(value) == "string" then
        return value, nil
    end

    local src = tonumber(value)
    if not src or src <= 0 then
        return nil, nil
    end

    local identifier = Helpers.getPlayerLicenseIdentifier and Helpers.getPlayerLicenseIdentifier(src) or nil
    local name = GetPlayerName(src)

    return identifier, name
end

--- Queues one admin action. Cheap, allocation-light, and never raises.
--- @param entry table namespace, action, actor, target, targetName, success, err, payload
function Logs.record(entry)
    if not isEnabled() or type(entry) ~= "table" then
        return
    end

    local action = entry.action
    if type(action) ~= "string" or action == "" or not shouldRecord(action) then
        return
    end

    if not withinRate(entry.actor) then
        return
    end

    local ok, row = pcall(function()
        local actorIdentifier, actorName = resolveActor(entry.actor)
        local targetIdentifier, targetName = resolveActor(entry.target)

        return {
            at = os.time(),
            actor_identifier = actorIdentifier or "unknown",
            actor_name = actorName or entry.actorName,
            namespace = tostring(entry.namespace or "unknown"),
            action = action,
            target_identifier = targetIdentifier,
            target_name = targetName or entry.targetName,
            success = entry.success ~= false and 1 or 0,
            error = entry.err and tostring(entry.err):sub(1, 190) or nil,
            payload = encodePayload(entry.payload),
        }
    end)

    if not ok or not row then
        return
    end

    -- Bounded: if the database is unreachable we shed the oldest entries rather
    -- than grow until the server runs out of memory.
    local maxQueue = tonumber(config().MaxQueue) or 500
    while queueCount() >= maxQueue do
        queue[head] = nil
        head = head + 1
        dropped = dropped + 1
    end

    tail = tail + 1
    queue[tail] = row
end

local function buildWebhookEmbeds(rows)
    local allowed = config().Webhook and config().Webhook.Actions
    if not allowed then
        return nil
    end

    local embeds = {}

    for i = 1, #rows do
        -- Discord rejects payloads with more than 10 embeds.
        if #embeds >= 10 then
            break
        end

        local row = rows[i]
        if allowed[row.action] then
            local lines = {
                ("**Admin:** %s (`%s`)"):format(row.actor_name or "?", row.actor_identifier or "?"),
            }

            if row.target_identifier then
                lines[#lines + 1] = ("**Target:** %s (`%s`)"):format(row.target_name or "?", row.target_identifier)
            end

            if not row.success then
                lines[#lines + 1] = ("**Failed:** %s"):format(row.error or "unknown")
            end

            if row.payload then
                lines[#lines + 1] = ("```json\n%s\n```"):format(row.payload:sub(1, 900))
            end

            embeds[#embeds + 1] = {
                title = ("%s / %s"):format(row.namespace, row.action),
                description = table.concat(lines, "\n"),
                color = row.success == 1 and 3066993 or 15158332,
            }
        end
    end

    return #embeds > 0 and embeds or nil
end

local function postWebhook(rows)
    local webhook = config().Webhook
    local url = webhook and webhook.Url

    -- Only https, so a misconfigured value cannot be used to probe the local
    -- network from the server process.
    if type(url) ~= "string" or not url:match("^https://") then
        return
    end

    local embeds = buildWebhookEmbeds(rows)
    if not embeds then
        return
    end

    pcall(PerformHttpRequest, url, function() end, "POST",
        json.encode({ username = "ESX Admin Menu", embeds = embeds }),
        { ["Content-Type"] = "application/json" })
end

--- Writes every queued entry. Safe to call at any time; concurrent calls are
--- ignored so two flushes can never insert the same batch twice.
function Logs.flush()
    if flushing or queueCount() <= 0 then
        return
    end

    flushing = true

    -- Detach the queue first: entries recorded during the write land in the
    -- next batch instead of being lost.
    local batch = {}
    for i = head, tail do
        batch[#batch + 1] = queue[i]
        queue[i] = nil
    end
    head, tail = 1, 0

    if dropped > 0 then
        print(("[esx-adminmenu] Log queue overflow, dropped %d entries"):format(dropped))
        dropped = 0
    end

    local batchSize = tonumber(config().BatchSize) or 100

    for start = 1, #batch, batchSize do
        local placeholders = {}
        local params = {}
        local chunk = {}

        for i = start, math.min(start + batchSize - 1, #batch) do
            local row = batch[i]
            chunk[#chunk + 1] = row
            appendRow(row, placeholders, params)
        end

        Helpers.safeQuery(INSERT_COLUMNS .. table.concat(placeholders, ","), params)
        postWebhook(chunk)
    end

    flushing = false
end

--- Escapes LIKE metacharacters so a search of "%" cannot match every row.
local function escapeLike(value)
    return (value:gsub("([%%_\\])", "\\%1"))
end

--- Paginated read. Filters are optional and combine with AND.
function Logs.query(filters)
    filters = filters or {}

    local where = {}
    local params = {}

    -- Free-text search across the columns an admin would actually type into.
    -- Infix LIKE cannot use an index, so it is bounded by the LIMIT below and
    -- by the retention window: admin_logs never grows past RetentionDays.
    local search = type(filters.search) == "string" and filters.search:match("^%s*(.-)%s*$") or ""
    if #search >= 2 and #search <= 100 then
        local infix = "%" .. escapeLike(search) .. "%"

        where[#where + 1] =
        "(actor_name LIKE ? OR actor_identifier LIKE ? OR target_name LIKE ? OR target_identifier LIKE ? OR action LIKE ?)"

        for _ = 1, 5 do
            params[#params + 1] = infix
        end
    end

    if type(filters.actor) == "string" and filters.actor ~= "" then
        where[#where + 1] = "actor_identifier = ?"
        params[#params + 1] = filters.actor
    end

    if type(filters.target) == "string" and filters.target ~= "" then
        where[#where + 1] = "target_identifier = ?"
        params[#params + 1] = filters.target
    end

    if type(filters.action) == "string" and filters.action ~= "" then
        where[#where + 1] = "action = ?"
        params[#params + 1] = filters.action
    end

    if type(filters.namespace) == "string" and filters.namespace ~= "" then
        where[#where + 1] = "namespace = ?"
        params[#params + 1] = filters.namespace
    end

    local days = tonumber(filters.days)
    if days and days > 0 then
        where[#where + 1] = "created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)"
        params[#params + 1] = math.floor(days)
    end

    local limit = math.max(1, math.min(tonumber(filters.limit) or 50, 200))
    local offset = math.max(0, tonumber(filters.offset) or 0)

    local sql = [[SELECT id, created_at, actor_identifier, actor_name, namespace, action,
        target_identifier, target_name, success, error, payload
        FROM admin_logs]]

    if #where > 0 then
        sql = sql .. " WHERE " .. table.concat(where, " AND ")
    end

    -- id desc rather than created_at desc: id is the primary key, so the sort
    -- is served by the index and stays cheap as the table grows.
    sql = sql .. " ORDER BY id DESC LIMIT ? OFFSET ?"
    params[#params + 1] = limit + 1
    params[#params + 1] = offset

    local rows = Helpers.safeQuery(sql, params) or {}
    local hasMore = #rows > limit

    if hasMore then
        rows[#rows] = nil
    end

    return { logs = rows, hasMore = hasMore, nextOffset = offset + #rows, limit = limit }
end

--- Deletes expired rows in bounded chunks so the table is never locked long.
function Logs.purge()
    local days = tonumber(config().RetentionDays) or 30
    if days <= 0 then
        return 0
    end

    local removed = 0

    for _ = 1, 20 do
        local affected = Helpers.safeUpdate(
            "DELETE FROM admin_logs WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY) LIMIT 1000",
            { math.floor(days) })

        affected = tonumber(affected) or 0
        removed = removed + affected

        if affected < 1000 then
            break
        end

        Wait(0)
    end

    return removed
end

CreateThread(function()
    local interval = tonumber(config().FlushInterval) or 5000

    while true do
        Wait(interval)
        pcall(Logs.flush)
    end
end)

CreateThread(function()
    while true do
        Wait(3600000)
        pcall(Logs.purge)
    end
end)

-- Last chance to persist: a restart would otherwise discard the current window.
AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        pcall(Logs.flush)
    end
end)

exports("logAdminAction", function(entry)
    Logs.record(entry)
end)

exports("getAdminLogs", function(filters)
    return Logs.query(filters)
end)

return Logs
