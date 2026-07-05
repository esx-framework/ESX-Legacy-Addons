Helpers = {}
local translations = nil
local allowedGroups = {}
local Spectators = {}
local impounds = nil
local vehicles = {}
local vehiclesFetchedAt = 0
local MAX_VEHICLE_PAGE_SIZE = 100
local MAX_BAN_PAGE_SIZE = 100
local recentPlayers = {}
local MAX_RECENT_PLAYERS = 100
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

function Helpers.getFormattedPlayTime(playtime)
    if playtime == 0 or playtime < 0 then
        return 0
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

function Helpers.getPlayerIdentifiers(source)
    return getIdentifierMap(source)
end

local function loadLastSeenFor(identifiers)
    if #identifiers == 0 then
        return {}
    end

    local placeholders = {}
    for i = 1, #identifiers do
        placeholders[i] = "?"
    end

    local rows = MySQL.query.await(
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

function Helpers.getSpectateTarget(adminSrc)
    return Spectators[adminSrc]
end

function Helpers.getSpectators()
    return Spectators
end

function Helpers.getTranslations()
    if not translations then
        local keys = {
            "admin_menu",
            "admin_dashboard",
            "dashboard_home",
            "dashboard_snapshot",
            "admin_menu_desc",
            "quick_admin_menu",
            "quick_actions",
            "open_admin_dashboard",
            "open_admin_menu",
            "admin_menu_self",
            "admin_menu_vehicle",
            "admin_menu_utility",
            "search_anything",
            "server_online",
            "server_uptime",
            "players",
            "search_player",
            "search_vehicle",
            "search_banned_identifier",
            "player_management",
            "players_list",
            "vehicles_list",
            "player_search",
            "recent_players",
            "no_players_found",
            "bans_list",

            "id",
            "name",
            "money",
            "total_money",
            "avg_money",
            "avg_money_per_player",
            "active_staff",
            "non_staff",
            "available_slots",
            "money_distribution",
            "economy_summary",
            "median_money",
            "richest_player",
            "avg_money_breakdown",
            "health_distribution",
            "avg_health",
            "avg_armor",
            "player_counts",
            "player_condition",
            "staff_overview",
            "active_player_job_distribution",
            "top_jobs",
            "wealth_bands",
            "bank_money",
            "black_money",
            "health",
            "armor",
            "last_visited",
            "gender",
            "male",
            "female",
            "job",
            "job_grade",
            "identifier",
            "ip_address",
            "char_identifier",
            "play_time",
            "position",
            "identifiers",
            "routing_bucket",
            "radio_channel",
            "thirst",
            "hunger",

            "player_information",
            "information",
            "teleport",
            "bring",
            "spectate",
            "notify_player",
            "notification_message",
            "give_money",
            "take_money",
            "set_health",
            "set_armor",
            "clean_inventory",
            "player_tools",
            "kill_player",
            "revive_player",
            "freeze_player",
            "unfreeze_player",
            "set_model",
            "open_clothing",
            "give_all_weapons",
            "set_bucket",
            "set_radio",
            "set_job",
            "set_name",
            "set_thirst",
            "set_hunger",
            "ace_add",
            "ace_remove",
            "model_name",
            "ace_group",
            "first_name",
            "last_name",
            "delete_character",
            "troll_options",
            "troll_burn",
            "troll_explode",
            "troll_sky",
            "troll_random",
            "troll_nausea",
            "noclip",
            "show_names",
            "show_blips",
            "godmode",
            "invisible",
            "infinite_ammo",
            "revive",
            "heal",
            "spawn_vehicle",
            "vehicle_spawner",
            "vehicle_model",
            "vehicle_color",
            "primary_color",
            "secondary_color",
            "customize_vehicle",
            "customize_vehicle_hint",
            "spawn_tuned",
            "engine_level",
            "brake_level",
            "transmission_level",
            "suspension_level",
            "vehicle_armor",
            "turbo",
            "xenon_lights",
            "neon_lights",
            "neon_color",
            "window_tint",
            "wheel_category",
            "wheel_design",
            "bulletproof_tires",
            "apply_performance",
            "apply_customization",
            "max_performance",
            "repair_vehicle",
            "clean_vehicle",
            "flip_vehicle",
            "teleport_waypoint",
            "copy_coords",
            "delete_current_vehicle",
            "quick_menu_hint",
            "quick_menu_edit_hint",
            "back",
            "kick",
            "ban",
            "never",
            "copied_to_clipboard",
            "online",
            "offline",
            "on",
            "off",
            "player",
            "reason",
            "kick_reason_placeholder",
            "ban_reason_placeholder",
            "duration",
            "minutes",
            "hours",
            "days",
            "months",
            "years",
            "permanent",
            "duration_desc",
            "cancel",
            "confirm",
            "escape_spectate",
            "default_ban",
            "finalizing_connection",

            "banned_by",
            "banned_at",
            "expires_at",
            "change_expiry",
            "revoke",
            "new_expiry_date",

            "plate",
            "owner",
            "vehicle_name",
            "vehicle_type",
            "mileage",
            "impounded",
            "copy_plate",
            "copy_owner",
            "impound",
            "unimpound",
            "delete_vehicle",
            "select_impound"
        }
        translations = {}

        for i = 1, #keys do
            local key = keys[i]
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

function Helpers.getAllVehicles()
    -- Return if vehicles has been cached within 20 seconds.
    if vehiclesFetchedAt ~= 0 and (os.time() - vehiclesFetchedAt) < 20 then
        return vehicles
    end

    local rows = MySQL.query.await("SELECT owner, plate, vehicle, stored, pound, type FROM owned_vehicles")
    if not rows then return vehicles end

    -- clear existing cache instead of reassigning (important if referenced elsewhere)
    for k in pairs(vehicles) do
        vehicles[k] = nil
    end

    for i = 1, #rows do
        local v = rows[i]

        local vehicleProps = {}
        if v.vehicle then
            local ok, decoded = pcall(json.decode, v.vehicle)
            if ok and type(decoded) == "table" then
                vehicleProps = decoded
            end
        end

        local vehicleHash = tonumber(vehicleProps.model)
        if not vehicleHash then
            goto continue
        end

        vehicles[#vehicles + 1] = {
            plate = v.plate,
            owner = v.owner,
            model = vehicleHash,
            type = capitalize(v.type or 'car'),
            stored = v.stored == 1 or v.stored == "1" or v.stored == true,
            impounded = v.pound ~= nil,
        }

        ::continue::
    end

    vehiclesFetchedAt = os.time()
    return vehicles
end

function Helpers.invalidateVehicles()
    for k in pairs(vehicles) do
        vehicles[k] = nil
    end

    vehiclesFetchedAt = 0
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

local function toVehicleRecord(row)
    local vehicleProps = decodeVehicleProps(row.vehicle)
    local vehicleHash = tonumber(vehicleProps.model)

    if not vehicleHash then
        return nil
    end

    return {
        plate = row.plate,
        owner = row.owner,
        model = vehicleHash,
        type = capitalize(row.type or "car"),
        stored = row.stored == 1 or row.stored == "1" or row.stored == true,
        impounded = row.pound ~= nil,
        impoundName = row.pound,
    }
end

function Helpers.getVehiclesPage(data)
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
        where = " WHERE plate LIKE ? OR owner LIKE ? OR type LIKE ?"
        params[#params + 1] = pattern
        params[#params + 1] = pattern
        params[#params + 1] = pattern
    end

    params[#params + 1] = limit + 1
    params[#params + 1] = offset

    local rows = MySQL.query.await(
        ("SELECT owner, plate, vehicle, stored, pound, type FROM owned_vehicles%s ORDER BY plate ASC LIMIT ? OFFSET ?")
        :format(where),
        params
    )

    local result = {}
    local rowCount = #(rows or {})
    local count = math.min(rowCount, limit)

    for i = 1, count do
        local vehicle = toVehicleRecord(rows[i])

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

function Helpers.getActiveBans()
    local all = BanCache.getAll()
    if not all then
        return {}
    end

    local now = os.time()
    local result = {}

    for identifier, list in pairs(all) do
        for i = #list, 1, -1 do
            local ban = list[i]

            local normalized, expires = normalizeBanRecord(ban, now)

            if expires and now >= expires then
                table.remove(list, i)
            else
                result[#result + 1] = normalized
            end
        end

        if #list == 0 then
            all[identifier] = nil
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

local function getRandomNumber(length)
    if length <= 0 then
        return ""
    end
    return getRandomNumber(length - 1) .. NumberCharset[math.random(#NumberCharset)]
end

local function getRandomLetter(length)
    if length <= 0 then
        return ""
    end
    return getRandomLetter(length - 1) .. Charset[math.random(#Charset)]
end

function Helpers.isPlateTaken(plate)
    return MySQL.scalar.await("SELECT 1 FROM owned_vehicles WHERE plate = ? LIMIT 1", { plate }) ~= nil
end

function Helpers.generatePlate()
    local plateConfig = Config.Plate or {}
    local letters = tonumber(plateConfig.Letters) or 3
    local numbers = tonumber(plateConfig.Numbers) or 3
    local separator = plateConfig.UseSpace == false and "" or " "

    for _ = 1, 50 do
        local generatedPlate = string.upper(getRandomLetter(letters) .. separator .. getRandomNumber(numbers))

        if #generatedPlate > 8 then
            generatedPlate = generatedPlate:sub(1, 8)
        end

        if not Helpers.isPlateTaken(generatedPlate) then
            return generatedPlate
        end
    end

    return string.upper(getRandomLetter(letters) .. separator .. getRandomNumber(numbers)):sub(1, 8)
end

function Helpers.getImpounds()
    if not impounds then
        local ok, result = pcall(function()
            return exports["esx_garage"]:getImpounds()
        end)

        impounds = ok and result or {}
    end
    return impounds
end

return Helpers
