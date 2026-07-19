Helpers = {}
local translations = nil
local allowedGroups = {}
local Spectators = {}
local impounds = nil
local ADMIN_LIMITS = Config.AdminLimits or {}
local MAX_VEHICLE_PAGE_SIZE = tonumber(ADMIN_LIMITS.VehiclePageSize) or 100
local MAX_BAN_PAGE_SIZE = tonumber(ADMIN_LIMITS.BanPageSize) or 100
local recentPlayers = {}
local MAX_RECENT_PLAYERS = tonumber(ADMIN_LIMITS.RecentPlayersCap) or 100
local serverStartedAt = os.time()
local serverManagementConfig = Config.ServerManagement or {}
local serverEnvironment = {
    weather = serverManagementConfig.DefaultWeather or "CLEAR",
    hour = math.floor(tonumber(serverManagementConfig.DefaultHour) or 12),
    minute = math.floor(tonumber(serverManagementConfig.DefaultMinute) or 0),
    blackout = serverManagementConfig.DefaultBlackout == true,
    pvp = serverManagementConfig.DefaultPvp ~= false,
}

for group, allowed in pairs(Config.AllowedGroups) do
    if allowed then
        allowedGroups[#allowedGroups + 1] = group
    end
end

local function capitalize(str)
    if type(str) ~= "string" or str == "" then return str end
    return str:sub(1, 1):upper() .. str:sub(2)
end

local function trim(str)
    if type(str) ~= "string" then
        return ""
    end

    return str:match("^%s*(.-)%s*$")
end

Helpers.trim = trim

-- =============================================
-- Safe DB wrappers: an await that raises must never abort a callback mid-flight.
-- =============================================
function Helpers.safeQuery(query, params)
    local ok, result = pcall(MySQL.query.await, query, params)
    if not ok then
        print(("[esx-adminmenu] DB query failed: %s"):format(tostring(result)))
        return nil
    end
    return result
end

function Helpers.safeScalar(query, params)
    local ok, result = pcall(MySQL.scalar.await, query, params)
    if not ok then
        print(("[esx-adminmenu] DB scalar failed: %s"):format(tostring(result)))
        return nil
    end
    return result
end

function Helpers.safeUpdate(query, params)
    local ok, result = pcall(MySQL.update.await, query, params)
    if not ok then
        print(("[esx-adminmenu] DB update failed: %s"):format(tostring(result)))
        return nil
    end
    return result
end

-- Wraps a server callback so a raised error still answers the client exactly once.
-- The handler receives (source, ...) and RETURNS its response table.
function Helpers.registerCallback(name, handler)
    ESX.RegisterServerCallback(name, function(source, cb, ...)
        local ok, result = pcall(handler, source, ...)
        if not ok then
            print(("[esx-adminmenu] Callback %s errored: %s"):format(name, tostring(result)))
            cb({ success = false, err = "Internal error." })
            return
        end
        cb(result)
    end)
end

-- Single accessor for the three action -> feature permission maps.
local ACTION_PERMISSION_MAPS = {
    adminMenu = function() return Config.AdminMenu and Config.AdminMenu.ActionPermissions or {} end,
    playerActions = function() return Config.PlayerActions and Config.PlayerActions.ActionPermissions or {} end,
    serverManagement = function() return Config.ServerManagement and Config.ServerManagement.ActionPermissions or {} end,
}

function Helpers.getActionPermission(namespace, action)
    local getter = ACTION_PERMISSION_MAPS[namespace]
    if not getter then
        return nil
    end
    return getter()[action]
end

function Helpers.getFormattedPlayTime(playtime)
    playtime = tonumber(playtime) or 0
    if playtime <= 0 then
        return { days = 0, hours = 0, minutes = 0 }
    end
    local days = math.floor(playtime / 86400)
    local hours = math.floor((playtime % 86400) / 3600)
    local minutes = math.floor((playtime % 3600) / 60)
    return { days = days, hours = hours, minutes = minutes }
end

function Helpers.isOnline(source)
    source = tonumber(source)
    if not source then
        return false
    end

    return GetPlayerName(source) ~= nil
end

function Helpers.isBanned(identifier)
    local ban = BanCache.get(identifier)
    if ban then
        return ban
    end
    return nil
end

function Helpers.getAllowedPermissions()
    return allowedGroups
end

function Helpers.getServerUptimeSeconds()
    if GetGameTimer then
        return math.floor(GetGameTimer() / 1000)
    end

    return os.time() - serverStartedAt
end

function Helpers.formatServerUptime(seconds)
    local total = math.max(0, tonumber(seconds) or 0)
    local days = math.floor(total / 86400)
    local hours = math.floor((total % 86400) / 3600)
    local minutes = math.floor((total % 3600) / 60)

    return ("%02d:%02d:%02d"):format(days, hours, minutes)
end

function Helpers.setServerEnvironment(data)
    data = data or {}

    if data.weather ~= nil then
        serverEnvironment.weather = tostring(data.weather)
    end

    if data.hour ~= nil then
        serverEnvironment.hour = math.max(0, math.min(23, math.floor(tonumber(data.hour) or serverEnvironment.hour)))
    end

    if data.minute ~= nil then
        serverEnvironment.minute = math.max(0,
            math.min(59, math.floor(tonumber(data.minute) or serverEnvironment.minute)))
    end

    if data.blackout ~= nil then
        serverEnvironment.blackout = data.blackout == true
    end

    if data.pvp ~= nil then
        serverEnvironment.pvp = data.pvp == true
    end
end

function Helpers.getServerEnvironment()
    return {
        weather = serverEnvironment.weather,
        hour = serverEnvironment.hour,
        minute = serverEnvironment.minute,
        blackout = serverEnvironment.blackout,
        pvp = serverEnvironment.pvp,
    }
end

function Helpers.getServerData()
    local uptimeSeconds = Helpers.getServerUptimeSeconds()

    return {
        currentPlayers = #GetPlayers(),
        maxPlayers = GetConvarInt("sv_maxclients", 32),
        uptimeSeconds = uptimeSeconds,
        uptimeFormatted = Helpers.formatServerUptime(uptimeSeconds),
        environment = Helpers.getServerEnvironment(),
    }
end

function Helpers.hasPermission(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return false
    end

    return Config.AllowedGroups[xPlayer.getGroup()] == true
end

function Helpers.hasFeaturePermission(source, feature)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return false
    end

    local featurePermissions = Config.FeaturePermissions and Config.FeaturePermissions[feature]
    if not featurePermissions then
        return Helpers.hasPermission(source)
    end

    return featurePermissions[xPlayer.getGroup()] == true
end

function Helpers.normalizeLicenseIdentifier(identifier)
    identifier = trim(identifier)
    if identifier == "" or #identifier > 100 then
        return nil
    end

    local license = identifier:match("^license:([%w%-_]+)$")
    if license then
        return "license:" .. license
    end

    if identifier:find(":") then
        return nil
    end

    if identifier:match("^[%w%-_]+$") then
        return "license:" .. identifier
    end

    return nil
end

function Helpers.getPlayerLicenseIdentifier(source)
    local identifiers = GetPlayerIdentifiers(source) or {}

    for i = 1, #identifiers do
        local identifier = Helpers.normalizeLicenseIdentifier(identifiers[i])
        if identifier then
            return identifier
        end
    end

    return Helpers.normalizeLicenseIdentifier(ESX.GetIdentifier(source))
end

local function getIdentifierMap(source)
    local result = {}
    local identifiers = GetPlayerIdentifiers(source) or {}

    for i = 1, #identifiers do
        local identifier = identifiers[i]
        local key = identifier:match("^([^:]+):") or ("identifier_" .. i)

        if result[key] then
            key = ("%s_%d"):format(key, i)
        end

        result[key] = identifier
    end

    return result
end

function Helpers.getPlayerRadioChannel(source)
    local ok, state = pcall(function()
        return Player(source).state
    end)

    if not ok or not state then
        return 0
    end

    return tonumber(state.radioChannel or state.radio or state.radio_channel or 0) or 0
end

local function loadLastSeenFor(identifiers)
    if #identifiers == 0 then
        return {}
    end

    local placeholders = {}
    for i = 1, #identifiers do
        placeholders[i] = "?"
    end

    local rows = Helpers.safeQuery(
        ("SELECT identifier, last_seen FROM users WHERE identifier IN (%s)"):format(table.concat(placeholders, ",")),
        identifiers
    )

    local map = {}
    for i = 1, #(rows or {}) do
        map[rows[i].identifier] = rows[i].last_seen
    end

    return map
end

function Helpers.getPlayerList(viewerSource)
    local players = {}
    local identifiers = {}
    local canSeeSensitive = viewerSource and Helpers.hasFeaturePermission(viewerSource, "sensitiveInfo")

    local xPlayers = ESX.ExtendedPlayers()

    -- One heavy numeric loop
    for i = 1, #xPlayers do
        local xPlayer = xPlayers[i]
        local src = xPlayer.src
        local full = ESX.GetPlayerFromId(src)

        local charIdentifier = full and full.identifier
        if charIdentifier then
            identifiers[#identifiers + 1] = charIdentifier
        end

        local ped = GetPlayerPed(src)
        local coords = xPlayer.getCoords(true)
        local playtime = Helpers.getFormattedPlayTime(xPlayer.getPlayTime() or 0)

        local job = full and full.getJob()
        local bank = full and full.getAccount("bank")
        local black = full and full.getAccount("black_money")
        players[#players + 1] = {
            status = "online",
            id = src,
            name = xPlayer.getName(),
            is_staff = Config.AllowedGroups[xPlayer.getGroup()] == true,
            group = canSeeSensitive and xPlayer.getGroup() or nil,

            cash = xPlayer.getMoney(),
            bank = bank and bank.money or 0,
            alt_money = black and black.money or 0,

            health = ped ~= 0 and math.floor(GetEntityHealth(ped) - 100) or 0,
            armor = ped ~= 0 and GetPedArmour(ped) or 0,

            char_identifier = canSeeSensitive and charIdentifier or nil,
            identifier = canSeeSensitive and Helpers.getPlayerLicenseIdentifier(src) or nil,
            ip = canSeeSensitive and GetPlayerEndpoint(src) or nil,
            identifiers = canSeeSensitive and getIdentifierMap(src) or nil,
            routing_bucket = GetPlayerRoutingBucket(src),
            radio_channel = Helpers.getPlayerRadioChannel(src),

            job = job and job.name or "unemployed",
            job_grade = job and job.grade_label or "",

            gender = full and full.variables.sex or "m",

            play_time = playtime,
            position = coords and { x = coords.x, y = coords.y, z = coords.z } or nil,
        }
    end

    -- Single DB query
    local lastSeenMap = loadLastSeenFor(identifiers)

    -- One light numeric loop for adding the last_seen's after getting all the current xPlayer identifiers.
    for i = 1, #players do
        local id = players[i].char_identifier
        players[i].last_join = id and lastSeenMap[id] or nil
    end

    return players
end

local function upsertRecentPlayer(player)
    if not player or not player.identifier then
        return
    end

    for i = #recentPlayers, 1, -1 do
        if recentPlayers[i].identifier == player.identifier then
            table.remove(recentPlayers, i)
        end
    end

    table.insert(recentPlayers, 1, player)

    while #recentPlayers > MAX_RECENT_PLAYERS do
        table.remove(recentPlayers)
    end
end

function Helpers.addRecentPlayer(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return
    end

    local ped = GetPlayerPed(source)
    local job = xPlayer.getJob and xPlayer.getJob() or nil
    local bank = xPlayer.getAccount and xPlayer.getAccount("bank") or nil
    local black = xPlayer.getAccount and xPlayer.getAccount("black_money") or nil

    upsertRecentPlayer({
        status = "offline",
        id = nil,
        name = xPlayer.getName and xPlayer.getName() or GetPlayerName(source) or "Unknown",
        cash = xPlayer.getMoney and xPlayer.getMoney() or 0,
        bank = bank and bank.money or 0,
        alt_money = black and black.money or 0,
        health = ped ~= 0 and math.floor(GetEntityHealth(ped) - 100) or 0,
        armor = ped ~= 0 and GetPedArmour(ped) or 0,
        char_identifier = xPlayer.identifier,
        identifier = Helpers.getPlayerLicenseIdentifier(source),
        job = job and job.name or "unemployed",
        job_grade = job and (job.grade_label or job.grade_name or tostring(job.grade)) or "",
        gender = xPlayer.variables and xPlayer.variables.sex or "m",
        play_time = Helpers.getFormattedPlayTime(xPlayer.getPlayTime and xPlayer.getPlayTime() or 0),
        last_join = os.time(),
    })
end

function Helpers.getRecentPlayers(viewerSource)
    if Helpers.hasFeaturePermission(viewerSource, "sensitiveInfo") then
        return recentPlayers
    end

    local sanitized = {}
    for i = 1, #recentPlayers do
        local player = {}

        for key, value in pairs(recentPlayers[i]) do
            if key ~= "identifier" and key ~= "char_identifier" and key ~= "identifiers" and key ~= "ip" then
                player[key] = value
            end
        end

        sanitized[#sanitized + 1] = player
    end

    return sanitized
end

function Helpers.startSpectate(adminSrc, targetSrc)
    Spectators[adminSrc] = targetSrc
end

function Helpers.stopSpectate(adminSrc)
    Spectators[adminSrc] = nil
end

-- Derives the key set directly from the active locale table so en.lua stays the
-- single source of truth (no hand-maintained key mirror to drift out of sync).
function Helpers.getTranslations()
    if not translations then
        translations = {}

        local localeTable = Locales and (Locales[Config.Locale] or Locales["en"]) or {}
        for key in pairs(localeTable) do
            translations[key] = Translate(key)
        end
    end

    return translations
end

function Helpers.getTranslation(key)
    if not key then
        return "missing_key"
    end
    if translations == nil then
        Helpers.getTranslations()
    end
    return translations[key] or key
end

local function decodeVehicleProps(rawVehicle)
    if not rawVehicle then
        return {}
    end

    local ok, decoded = pcall(json.decode, rawVehicle)
    if ok and type(decoded) == "table" then
        return decoded
    end

    return {}
end

local function toVehicleRecord(row, canSeeSensitive)
    local vehicleProps = decodeVehicleProps(row.vehicle)
    local vehicleHash = tonumber(vehicleProps.model)

    if not vehicleHash then
        return nil
    end

    return {
        plate = row.plate,
        owner = canSeeSensitive and row.owner or nil,
        model = vehicleHash,
        type = capitalize(row.type or "car"),
        stored = row.stored == 1 or row.stored == "1" or row.stored == true,
        impounded = row.pound ~= nil,
        impoundName = row.pound,
    }
end

function Helpers.getVehiclesPage(data, canSeeSensitive)
    data = data or {}

    local limit = tonumber(data.limit) or MAX_VEHICLE_PAGE_SIZE
    limit = math.max(1, math.min(limit, MAX_VEHICLE_PAGE_SIZE))

    local offset = tonumber(data.offset) or 0
    offset = math.max(0, offset)

    local search = trim(data.search):sub(1, 64)
    local params = {}
    local where = ""

    if search ~= "" then
        local pattern = "%" .. search .. "%"

        -- Only expose owner as a searchable/returned field to sensitive-tier admins.
        if canSeeSensitive then
            where = " WHERE plate LIKE ? OR owner LIKE ? OR type LIKE ?"
            params[#params + 1] = pattern
            params[#params + 1] = pattern
            params[#params + 1] = pattern
        else
            where = " WHERE plate LIKE ? OR type LIKE ?"
            params[#params + 1] = pattern
            params[#params + 1] = pattern
        end
    end

    params[#params + 1] = limit + 1
    params[#params + 1] = offset

    local rows = Helpers.safeQuery(
        ("SELECT owner, plate, vehicle, stored, pound, type FROM owned_vehicles%s ORDER BY plate ASC LIMIT ? OFFSET ?")
        :format(where),
        params
    )

    local result = {}
    local rowCount = #(rows or {})
    local count = math.min(rowCount, limit)

    for i = 1, count do
        local vehicle = toVehicleRecord(rows[i], canSeeSensitive)

        if vehicle then
            result[#result + 1] = vehicle
        end
    end

    return {
        vehicles = result,
        hasMore = rowCount > limit,
        nextOffset = offset + count,
        limit = limit,
    }
end

local function normalizeTimestamp(value)
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
        value = trim(value)
        if value == "" or value:find("^0000%-00%-00") then
            return nil
        end

        local numeric = tonumber(value)
        if numeric then
            return normalizeTimestamp(numeric)
        end

        local year, month, day, hour, min, sec = value:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)[ T](%d%d):(%d%d):(%d%d)")
        if not year then
            return nil
        end

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

    return nil
end

function Helpers.normalizeTimestamp(value)
    return normalizeTimestamp(value)
end

local function toMilliseconds(seconds)
    seconds = normalizeTimestamp(seconds)
    return seconds and (seconds * 1000) or nil
end

local function normalizeBanRecord(ban, now)
    local expires = normalizeTimestamp(ban.expires_at)
    local bannedAt = normalizeTimestamp(ban.banned_at)
    local normalized = {}

    for key, value in pairs(ban) do
        normalized[key] = value
    end

    normalized.banned_at = toMilliseconds(bannedAt)
    normalized.expires_at = toMilliseconds(expires)

    if expires then
        local remaining = math.max(0, expires - now)
        normalized.remaining_seconds = remaining
        normalized.remaining_formatted = Helpers.formatRemainingTime(remaining)
    else
        normalized.remaining_seconds = nil
        normalized.remaining_formatted = Helpers.getTranslation("permanent")
    end

    return normalized, expires
end

function Helpers.formatRemainingTime(seconds)
    local yearSeconds = 60 * 60 * 24 * 365
    local weekSeconds = 60 * 60 * 24 * 7
    local daySeconds = 60 * 60 * 24
    local hourSeconds = 60 * 60
    local minuteSeconds = 60

    local years = math.floor(seconds / yearSeconds)
    seconds = seconds % yearSeconds

    local weeks = math.floor(seconds / weekSeconds)
    seconds = seconds % weekSeconds

    local days = math.floor(seconds / daySeconds)
    seconds = seconds % daySeconds

    local hours = math.floor(seconds / hourSeconds)
    seconds = seconds % hourSeconds

    local minutes = math.floor(seconds / minuteSeconds)

    local parts = {}

    if years > 0 then
        table.insert(parts, years .. "y")
    end
    if weeks > 0 then
        table.insert(parts, weeks .. "w")
    end
    if days > 0 then
        table.insert(parts, days .. "d")
    end
    if hours > 0 then
        table.insert(parts, hours .. "h")
    end
    if minutes > 0 then
        table.insert(parts, minutes .. "m")
    end
    if #parts == 0 then
        table.insert(parts, "<1m")
    end

    return table.concat(parts, ", ")
end

-- Read-only: builds the active-ban view without mutating the shared cache.
-- Expiry pruning is owned by BanCache (on add/revoke and a maintenance timer).
function Helpers.getActiveBans()
    local all = BanCache.getAll()
    if not all then
        return {}
    end

    local now = os.time()
    local result = {}

    for _, list in pairs(all) do
        for i = 1, #list do
            local normalized, expires = normalizeBanRecord(list[i], now)

            if not (expires and now >= expires) then
                result[#result + 1] = normalized
            end
        end
    end

    return result
end

function Helpers.getActiveBansPage(data)
    data = data or {}

    local limit = tonumber(data.limit) or MAX_BAN_PAGE_SIZE
    limit = math.max(1, math.min(limit, MAX_BAN_PAGE_SIZE))

    local offset = tonumber(data.offset) or 0
    offset = math.max(0, offset)

    local bans = Helpers.getActiveBans()
    table.sort(bans, function(a, b)
        return (tonumber(a.id) or 0) > (tonumber(b.id) or 0)
    end)

    local result = {}
    local lastIndex = math.min(#bans, offset + limit)

    for i = offset + 1, lastIndex do
        result[#result + 1] = bans[i]
    end

    return {
        bans = result,
        hasMore = lastIndex < #bans,
        nextOffset = lastIndex,
        limit = limit,
    }
end

local NumberCharset, Charset = {}, {}

for i = 48, 57 do
    NumberCharset[#NumberCharset + 1] = string.char(i)
end
for i = 65, 90 do
    Charset[#Charset + 1] = string.char(i)
end

math.randomseed(os.time())

local function randomFrom(charset, length)
    local parts = {}
    for i = 1, math.max(0, length) do
        parts[i] = charset[math.random(#charset)]
    end
    return table.concat(parts)
end

function Helpers.isPlateTaken(plate)
    return Helpers.safeScalar("SELECT 1 FROM owned_vehicles WHERE plate = ? LIMIT 1", { plate }) ~= nil
end

function Helpers.generatePlate()
    local plateConfig = Config.Plate or {}
    local letters = tonumber(plateConfig.Letters) or 3
    local numbers = tonumber(plateConfig.Numbers) or 3
    local separator = plateConfig.UseSpace == false and "" or " "
    local attempts = tonumber(ADMIN_LIMITS.PlateGenAttempts) or 50

    for _ = 1, attempts do
        local generatedPlate = string.upper(randomFrom(Charset, letters) .. separator .. randomFrom(NumberCharset, numbers))

        if #generatedPlate > 8 then
            generatedPlate = generatedPlate:sub(1, 8)
        end

        if not Helpers.isPlateTaken(generatedPlate) then
            return generatedPlate
        end
    end

    return string.upper(randomFrom(Charset, letters) .. separator .. randomFrom(NumberCharset, numbers)):sub(1, 8)
end

-- Only memoize a successful, non-empty result so a start-order race with
-- esx_garage self-heals instead of caching an empty list forever.
function Helpers.getImpounds()
    if impounds and next(impounds) then
        return impounds
    end

    local ok, result = pcall(function()
        return exports["esx_garage"]:getImpounds()
    end)

    if ok and type(result) == "table" and next(result) then
        impounds = result
        return impounds
    end

    return {}
end

return Helpers
