-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- @module server.module.main
--- Main server module for the scoreboard resource

local ScoreboardModule = {}

local RESOURCE_NAME <const> = GetCurrentResourceName()
local DEFAULT_JOB <const> = "unemployed"
local DEFAULT_SORT <const> = "serverId"

local VALID_SORT_COLUMNS <const> = {
  serverId = true,
  name = true,
  job = true,
  ping = true
}

local MAX_NAME_LEN <const> = 64
local MAX_JOB_LEN <const> = 40
local MAX_GRADE_LEN <const> = 64
local MAX_SERVER_NAME_LEN <const> = 80
local MAX_LOGO_URL_LEN <const> = 256
local MAX_ACTIVITY_TYPE_LEN <const> = 50
local MAX_ACTIVITY_LABEL_LEN <const> = 100
local MAX_ACTIVITY_LOCATION_LEN <const> = 100

--- @type table<number, table> Active activity entries.
local cachedActivities = {}

--- @type number Monotonic activity ID counter.
local nextActivityId = 1

--- @type number Server start timestamp (seconds).
local serverStartTime = os.time()

--- @type table<number, boolean> Clients with scoreboard currently open.
local activeClients = {}

--- @type table<number, table> Per-client request state and selected page.
local requestState = {}

local requestLimiters = {}

--- @type table<number, table> Public player records keyed by source.
local playersById = {}

--- @type table<number, string> Maps player source -> current job name for fast decrement on drop/job change.
local playerJobMap = {}

--- @type table<string, table> Incremental job counters: [jobName] = { name, label, count, color }
local jobCounters = {}

--- @type table|nil Cached summary payload.
local summaryCache = nil

--- @type boolean True when summary cache needs rebuild.
local summaryDirty = true

--- @type number Monotonic revisions used to avoid unnecessary client updates.
local playersRevision = 0
local activitiesRevision = 0
local pingRevision = 0

--- @type number Last time pings were refreshed (GetGameTimer).
local lastPingUpdate = 0

--- @type table<string, table> Per-query page cache.
local pageCache = {}

--- @type string[] Page cache insertion order for bounded memory.
local pageCacheOrder = {}

--- @type table<string, table> Cached filtered/sorted player references, shared by all pages of a query.
local playerQueryCache = {}

--- @type string[] Player query cache insertion order for bounded memory.
local playerQueryCacheOrder = {}

--- @type boolean Prevents stacked activity broadcasts.
local activityBroadcastPending = false

local function nowMs()
  return GetGameTimer()
end

local function cfgNumber(name, fallback, minValue, maxValue)
  local value = tonumber(Config[name])
  if not value then
    value = fallback
  end

  value = math.floor(value)

  if minValue and value < minValue then
    value = minValue
  end

  if maxValue and value > maxValue then
    value = maxValue
  end

  return value
end

local function getMaxPageSize()
  return cfgNumber("MaxPageSize", 100, 10, 100)
end

local function getDefaultPageSize()
  return cfgNumber("DefaultPageSize", 50, 10, getMaxPageSize())
end

local function getSummaryInterval()
  return cfgNumber("SummaryInterval", 10000, 5000, 60000)
end

local function getPageRefreshInterval()
  return cfgNumber("PageRefreshInterval", 15000, 5000, 60000)
end

local function getPageRefreshBatchSize()
  return cfgNumber("PageRefreshBatchSize", 25, 1, 250)
end

local function getPageRefreshBatchDelay()
  return cfgNumber("PageRefreshBatchDelay", 50, 0, 1000)
end

local function getFullReconcileInterval()
  return cfgNumber("FullReconcileInterval", 60000, 30000, 300000)
end

local function getPingRefreshInterval()
  return cfgNumber("PingRefreshInterval", 30000, 10000, 120000)
end

local function getActivityDebounce()
  return cfgNumber("ActivityDebounce", 1000, 250, 10000)
end

local function getOpenCooldown()
  return cfgNumber("OpenCooldown", 2000, 500, 10000)
end

local function getPageRequestCooldown()
  return cfgNumber("PageRequestCooldown", 1500, 250, 10000)
end

local function getMaxSearchLength()
  return cfgNumber("MaxSearchLength", 48, 0, 80)
end

local function getMaxActivities()
  return cfgNumber("MaxActivities", 64, 1, 256)
end

local function getMaxActivityPlayers()
  return cfgNumber("MaxActivityPlayers", 16, 0, 64)
end

local function getMaxPageCacheEntries()
  return cfgNumber("MaxPageCacheEntries", 256, 32, 1024)
end

local function getMaxPlayerQueryCacheEntries()
  return cfgNumber("MaxPlayerQueryCacheEntries", 64, 8, 256)
end

local function clearPageCache()
  pageCache = {}
  pageCacheOrder = {}
  playerQueryCache = {}
  playerQueryCacheOrder = {}
end

local function sanitizeString(value, maxLen, fallback)
  if type(value) ~= "string" then
    return fallback or ""
  end

  value = value:gsub("[%z\1-\31\127]", ""):match("^%s*(.-)%s*$") or ""
  if maxLen and #value > maxLen then
    value = value:sub(1, maxLen)
  end

  if value == "" then
    return fallback or ""
  end

  return value
end

local function sanitizeKey(value, maxLen, fallback)
  value = sanitizeString(value, maxLen, fallback)
  value = value:gsub("[^%w_%-]", "")
  if value == "" then
    return fallback or DEFAULT_JOB
  end
  return value
end

local function sanitizeColor(value, fallback)
  if type(value) == "string" and value:match("^#%x%x%x%x%x%x$") then
    return value
  end
  return fallback or "#6B7280"
end

local function sanitizeLogoUrl(value)
  value = sanitizeString(value, MAX_LOGO_URL_LEN, "")
  if value == "" then return "" end
  if value:match("^https://") then
    return value
  end
  return ""
end

local function markPlayersDirty()
  playersRevision = playersRevision + 1
  summaryDirty = true
  clearPageCache()
end

local function markActivitiesDirty()
  activitiesRevision = activitiesRevision + 1
  summaryDirty = true
end

local function isRateLimited(src, key, cooldownMs)
  if type(src) ~= "number" or src <= 0 then
    return true
  end

  cooldownMs = math.max(1, math.floor(tonumber(cooldownMs) or 1))

  local limiterState = requestLimiters[key]
  if not limiterState or limiterState.cooldownMs ~= cooldownMs then
    limiterState = {
      cooldownMs = cooldownMs,
      limiter = xLib.rateLimiter({
        capacity = 1,
        refill = 1,
        interval = cooldownMs,
        staleMs = math.max(60000, cooldownMs * 4)
      })
    }
    requestLimiters[key] = limiterState
  end

  local allowed = limiterState.limiter:consume(src)
  return not allowed
end

local function getPlayer(src)
  if type(src) ~= "number" or src <= 0 then
    return nil
  end

  local xPlayer = ESX.GetPlayerFromId(src)
  if not xPlayer then
    return nil
  end

  return xPlayer
end

--- Get current server uptime in seconds.
--- @return number
function ScoreboardModule.GetUptime()
  return os.time() - serverStartTime
end

--- Get configured max players.
--- @return number
function ScoreboardModule.GetMaxPlayers()
  local configured = tonumber(Config.MaxPlayers)
  if configured and configured > 0 then
    return math.floor(configured)
  end
  return GetConvarInt("sv_maxclients", 128)
end

--- Get configured server name.
--- @return string
function ScoreboardModule.GetServerName()
  return sanitizeString(Config.ServerName, MAX_SERVER_NAME_LEN, "ESX Server")
end

--- Get configured logo URL.
--- @return string
function ScoreboardModule.GetLogoUrl()
  return sanitizeLogoUrl(Config.LogoUrl)
end

--- Build server info object for NUI.
--- @return table
function ScoreboardModule.GetServerInfo()
  return {
    serverName = ScoreboardModule.GetServerName(),
    maxPlayers = ScoreboardModule.GetMaxPlayers(),
    logoUrl = ScoreboardModule.GetLogoUrl(),
    uptime = ScoreboardModule.GetUptime()
  }
end

--- Get color for a job.
--- @param jobName string
--- @return string Hex color code
function ScoreboardModule.GetJobColor(jobName)
  local safeJobName = sanitizeKey(jobName, MAX_JOB_LEN, DEFAULT_JOB)
  if Config.Jobs and Config.Jobs[safeJobName] then
    return sanitizeColor(Config.Jobs[safeJobName].color)
  end

  local colors = {
    police = "#3B82F6",
    ambulance = "#EF4444",
    mechanic = "#F59E0B",
    taxi = "#FBBF24",
    realtor = "#10B981",
    cardealer = "#8B5CF6",
    banker = "#06B6D4",
    unemployed = "#6B7280"
  }
  return colors[safeJobName] or "#FB9B04"
end

local function getJobLabel(jobName, fallback)
  local safeJobName = sanitizeKey(jobName, MAX_JOB_LEN, DEFAULT_JOB)
  if jobCounters[safeJobName] and jobCounters[safeJobName].label then
    return jobCounters[safeJobName].label
  end

  if Config.Jobs and Config.Jobs[safeJobName] and Config.Jobs[safeJobName].label then
    return sanitizeString(Config.Jobs[safeJobName].label, MAX_GRADE_LEN, fallback or safeJobName)
  end

  local jobs = ESX.GetJobs()
  if type(jobs) == "table" and jobs[safeJobName] and jobs[safeJobName].label then
    return sanitizeString(jobs[safeJobName].label, MAX_GRADE_LEN, fallback or safeJobName)
  end

  return sanitizeString(fallback or safeJobName, MAX_GRADE_LEN, safeJobName)
end

local function ensureJobCounter(jobName, label)
  local safeJobName = sanitizeKey(jobName, MAX_JOB_LEN, DEFAULT_JOB)
  if not jobCounters[safeJobName] then
    jobCounters[safeJobName] = {
      name = safeJobName,
      label = getJobLabel(safeJobName, label),
      count = 0,
      color = ScoreboardModule.GetJobColor(safeJobName)
    }
  end
  return jobCounters[safeJobName]
end

local function incrementJob(jobName, label)
  local counter = ensureJobCounter(jobName, label)
  counter.count = counter.count + 1
  summaryDirty = true
end

local function decrementJob(jobName)
  local safeJobName = sanitizeKey(jobName, MAX_JOB_LEN, DEFAULT_JOB)
  local counter = jobCounters[safeJobName]
  if counter then
    counter.count = math.max(0, counter.count - 1)
    summaryDirty = true
  end
end

local function initJobCounters()
  local jobs = ESX.GetJobs()
  if type(jobs) ~= "table" then
    return false
  end

  jobCounters = {}
  for name, jobData in pairs(jobs) do
    local safeJobName = sanitizeKey(name, MAX_JOB_LEN, DEFAULT_JOB)
    jobCounters[safeJobName] = {
      name = safeJobName,
      label = sanitizeString(jobData.label, MAX_GRADE_LEN, safeJobName),
      count = 0,
      color = ScoreboardModule.GetJobColor(safeJobName)
    }
  end

  ensureJobCounter(DEFAULT_JOB, "Civilian")
  return true
end

--- Get player activity.
--- @param source number
--- @return string|nil
function ScoreboardModule.GetPlayerActivity(source)
  return nil
end

local function createPlayerRecord(src, xPlayer)
  if not xPlayer or not xPlayer.job then
    return nil
  end

  local jobName = sanitizeKey(xPlayer.job.name, MAX_JOB_LEN, DEFAULT_JOB)
  local jobGrade = sanitizeString(xPlayer.job.grade_label or xPlayer.job.grade_name, MAX_GRADE_LEN, "")
  local playerName = GetPlayerName(src)

  if type(xPlayer.getName) == "function" then
    playerName = xPlayer.getName() or playerName
  end

  return {
    serverId = src,
    name = sanitizeString(playerName, MAX_NAME_LEN, "Unknown"),
    job = jobName,
    jobLabel = sanitizeString(xPlayer.job.label or getJobLabel(jobName, jobName), MAX_GRADE_LEN, jobName),
    jobGrade = jobGrade,
    ping = GetPlayerPing(src) or 0,
    activity = ScoreboardModule.GetPlayerActivity(src)
  }
end

local function upsertPlayer(src, xPlayer)
  xPlayer = xPlayer or getPlayer(src)
  if not xPlayer then
    return false
  end

  local record = createPlayerRecord(src, xPlayer)
  if not record then
    return false
  end

  local previousJob = playerJobMap[src]
  if previousJob and previousJob ~= record.job then
    decrementJob(previousJob)
  end

  if not previousJob or previousJob ~= record.job then
    incrementJob(record.job, record.jobLabel)
    playerJobMap[src] = record.job
  else
    local counter = ensureJobCounter(record.job, record.jobLabel)
    if counter.label ~= record.jobLabel then
      counter.label = record.jobLabel
      summaryDirty = true
    end
  end

  playersById[src] = record
  markPlayersDirty()
  return true
end

local function removePlayer(src)
  local previousJob = playerJobMap[src]
  if previousJob then
    decrementJob(previousJob)
    playerJobMap[src] = nil
  end

  if playersById[src] then
    playersById[src] = nil
    markPlayersDirty()
  end
end

local function refreshPings()
  local now = nowMs()
  if now - lastPingUpdate < getPingRefreshInterval() then
    return
  end

  lastPingUpdate = now
  local changed = false

  for src, record in pairs(playersById) do
    if GetPlayerName(src) then
      local ping = GetPlayerPing(src) or 0
      if record.ping ~= ping then
        record.ping = ping
        changed = true
      end
    end
  end

  if not changed then
    return
  end

  pingRevision = pingRevision + 1
  clearPageCache()
end

local function copyActivity(activity)
  local players = {}
  if type(activity.players) == "table" then
    for i = 1, math.min(#activity.players, getMaxActivityPlayers()) do
      local value = activity.players[i]
      if type(value) == "number" or type(value) == "string" then
        players[#players + 1] = value
      end
    end
  end

  return {
    id = activity.id,
    type = activity.type,
    label = activity.label,
    location = activity.location,
    startTime = activity.startTime,
    players = players
  }
end

local function getPublicActivities()
  local result = {}
  for i = 1, #cachedActivities do
    result[i] = copyActivity(cachedActivities[i])
  end
  return result
end

--- Get active activities.
--- @return table
function ScoreboardModule.GetActiveActivities()
  return getPublicActivities()
end

--- Get job counts.
--- @return table Sorted array of active jobs.
function ScoreboardModule.GetJobCounts()
  local result = {}
  for _, data in pairs(jobCounters) do
    if data.count > 0 then
      result[#result + 1] = {
        name = data.name,
        label = data.label,
        count = data.count,
        color = data.color
      }
    end
  end
  table.sort(result, function(a, b)
    if a.count == b.count then
      return a.label < b.label
    end
    return a.count > b.count
  end)
  return result
end

function ScoreboardModule.GetSummary()
  if not summaryDirty and summaryCache then
    summaryCache.info.uptime = ScoreboardModule.GetUptime()
    return summaryCache
  end

  local totalPlayers = 0
  for _ in pairs(playersById) do
    totalPlayers = totalPlayers + 1
  end

  summaryCache = {
    totalPlayers = totalPlayers,
    jobs = ScoreboardModule.GetJobCounts(),
    activities = getPublicActivities(),
    info = ScoreboardModule.GetServerInfo(),
    paging = {
      defaultPageSize = getDefaultPageSize(),
      maxPageSize = getMaxPageSize()
    },
    revisions = {
      players = playersRevision,
      activities = activitiesRevision
    }
  }

  summaryDirty = false
  return summaryCache
end

local function sanitizePlayers(players)
  local result = {}
  if type(players) ~= "table" then
    return result
  end

  for i = 1, math.min(#players, getMaxActivityPlayers()) do
    local player = players[i]
    if type(player) == "number" or type(player) == "string" then
      result[#result + 1] = player
    end
  end

  return result
end

--- Add an activity.
--- @param activityType string
--- @param label string|nil
--- @param location string|nil
--- @param players table|nil
--- @return number activityId
function ScoreboardModule.AddActivity(activityType, label, location, players)
  local safeType = sanitizeString(activityType, MAX_ACTIVITY_TYPE_LEN, ""):gsub("[^%w_%-]", "")
  if safeType == "" then
    print("[^3esx_scoreboard^7] Warning: invalid activityType rejected")
    return -1
  end

  local configType = Config.ActivityTypes and Config.ActivityTypes[safeType]
  local activity = {
    id = nextActivityId,
    type = safeType,
    label = sanitizeString(label or (configType and configType.label), MAX_ACTIVITY_LABEL_LEN, safeType),
    location = sanitizeString(location, MAX_ACTIVITY_LOCATION_LEN, ""),
    startTime = os.time(),
    players = sanitizePlayers(players)
  }

  nextActivityId = nextActivityId + 1
  cachedActivities[#cachedActivities + 1] = activity

  while #cachedActivities > getMaxActivities() do
    table.remove(cachedActivities, 1)
  end

  markActivitiesDirty()
  ScoreboardModule.BroadcastActivities()

  return activity.id
end

--- Remove an activity by ID.
--- @param activityId number
--- @return boolean success
function ScoreboardModule.RemoveActivity(activityId)
  activityId = tonumber(activityId)
  if not activityId then return false end

  for i, activity in ipairs(cachedActivities) do
    if activity.id == activityId then
      table.remove(cachedActivities, i)
      markActivitiesDirty()
      ScoreboardModule.BroadcastActivities()
      return true
    end
  end
  return false
end

--- Update an activity by ID.
--- @param activityId number
--- @param data table
--- @return boolean success
function ScoreboardModule.UpdateActivity(activityId, data)
  activityId = tonumber(activityId)
  if not activityId or type(data) ~= "table" then return false end

  for _, activity in ipairs(cachedActivities) do
    if activity.id == activityId then
      if data.label ~= nil then
        activity.label = sanitizeString(data.label, MAX_ACTIVITY_LABEL_LEN, activity.label)
      end
      if data.location ~= nil then
        activity.location = sanitizeString(data.location, MAX_ACTIVITY_LOCATION_LEN, "")
      end
      if data.players ~= nil then
        activity.players = sanitizePlayers(data.players)
      end

      markActivitiesDirty()
      ScoreboardModule.BroadcastActivities()
      return true
    end
  end
  return false
end

local function normalizePageRequest(data)
  data = type(data) == "table" and data or {}

  local maxPageSize = getMaxPageSize()
  local pageSize = tonumber(data.pageSize) or getDefaultPageSize()
  pageSize = math.floor(pageSize)
  pageSize = math.max(10, math.min(pageSize, maxPageSize))

  local page = tonumber(data.page) or 1
  page = math.max(1, math.floor(page))

  local search = sanitizeString(data.search, getMaxSearchLength(), ""):lower()
  local sortBy = sanitizeKey(data.sortBy, 24, DEFAULT_SORT)
  if not VALID_SORT_COLUMNS[sortBy] then
    sortBy = DEFAULT_SORT
  end

  local sortAsc = data.sortAsc == true
  return page, pageSize, search, sortBy, sortAsc
end

local function matchesSearch(record, search)
  if search == "" then
    return true
  end

  return tostring(record.serverId):find(search, 1, true)
    or record.name:lower():find(search, 1, true)
    or record.job:lower():find(search, 1, true)
    or record.jobLabel:lower():find(search, 1, true)
end

local function sortPlayers(players, sortBy, sortAsc)
  table.sort(players, function(a, b)
    local av = a[sortBy]
    local bv = b[sortBy]

    if sortBy == "name" or sortBy == "job" then
      av = tostring(av or ""):lower()
      bv = tostring(bv or ""):lower()
    else
      av = tonumber(av) or 0
      bv = tonumber(bv) or 0
    end

    if av == bv then
      return a.serverId < b.serverId
    end

    if sortAsc then
      return av < bv
    end

    return av > bv
  end)
end

local function buildPlayerQuery(search, sortBy, sortAsc)
  local queryKey = ("%s:%s:%s:%s:%s"):format(playersRevision, pingRevision, #search, search, sortBy .. tostring(sortAsc))
  local cached = playerQueryCache[queryKey]
  if cached then
    return cached
  end

  local filtered = {}
  for _, record in pairs(playersById) do
    if matchesSearch(record, search) then
      filtered[#filtered + 1] = record
    end
  end

  sortPlayers(filtered, sortBy, sortAsc)

  cached = {
    players = filtered,
    total = #filtered
  }

  playerQueryCache[queryKey] = cached
  playerQueryCacheOrder[#playerQueryCacheOrder + 1] = queryKey

  while #playerQueryCacheOrder > getMaxPlayerQueryCacheEntries() do
    playerQueryCache[table.remove(playerQueryCacheOrder, 1)] = nil
  end

  return cached
end

function ScoreboardModule.BuildPlayerPage(data)
  refreshPings()

  local page, pageSize, search, sortBy, sortAsc = normalizePageRequest(data)
  local cacheKey = ("%s:%s:%s:%s:%s:%s:%s"):format(playersRevision, pingRevision, #search, search, page, pageSize, sortBy .. tostring(sortAsc))
  local cached = pageCache[cacheKey]
  if cached then
    return cached
  end

  local query = buildPlayerQuery(search, sortBy, sortAsc)
  local filtered = query.players
  local total = query.total
  local totalPages = math.max(1, math.ceil(total / pageSize))
  if page > totalPages then
    page = totalPages
  end

  local startIndex = ((page - 1) * pageSize) + 1
  local endIndex = math.min(startIndex + pageSize - 1, total)
  local rows = {}

  for i = startIndex, endIndex do
    local player = filtered[i]
    if player then
      rows[#rows + 1] = {
        serverId = player.serverId,
        name = player.name,
        job = player.job,
        jobLabel = player.jobLabel,
        jobGrade = player.jobGrade,
        ping = player.ping,
        activity = player.activity
      }
    end
  end

  local pageData = {
    players = rows,
    page = page,
    pageSize = pageSize,
    total = total,
    totalPages = totalPages,
    search = search,
    sortBy = sortBy,
    sortAsc = sortAsc,
    revisions = {
      players = playersRevision,
      pings = pingRevision
    }
  }

  pageCache[cacheKey] = pageData
  pageCacheOrder[#pageCacheOrder + 1] = cacheKey

  while #pageCacheOrder > getMaxPageCacheEntries() do
    pageCache[table.remove(pageCacheOrder, 1)] = nil
  end

  return pageData
end

function ScoreboardModule.SendSummary(src)
  TriggerClientEvent("esx_scoreboard:client:receiveSummary", src, ScoreboardModule.GetSummary())
end

function ScoreboardModule.SendPage(src, request)
  local page = ScoreboardModule.BuildPlayerPage(request)
  TriggerClientEvent("esx_scoreboard:client:receivePage", src, page)

  local state = requestState[src] or {}
  requestState[src] = state
  state.pageRequest = {
    page = page.page,
    pageSize = page.pageSize,
    search = page.search,
    sortBy = page.sortBy,
    sortAsc = page.sortAsc
  }
  state.pageRevision = playersRevision
  state.pingRevision = pingRevision
end

--- Send initial payload to a specific client.
--- @param source number
function ScoreboardModule.SendToClient(source)
  ScoreboardModule.SendSummary(source)
  ScoreboardModule.SendPage(source, requestState[source] and requestState[source].pageRequest or nil)
end

--- Broadcast summary only to clients with scoreboard open.
function ScoreboardModule.BroadcastUpdate()
  local summary = ScoreboardModule.GetSummary()
  for clientId in pairs(activeClients) do
    TriggerClientEvent("esx_scoreboard:client:receiveSummary", clientId, summary)
  end
end

--- Broadcast only activities to all clients with scoreboard open.
function ScoreboardModule.BroadcastActivities()
  if activityBroadcastPending then return end
  activityBroadcastPending = true

  CreateThread(function()
    Wait(getActivityDebounce())
    activityBroadcastPending = false

    local activities = getPublicActivities()
    for clientId in pairs(activeClients) do
      TriggerClientEvent("esx_scoreboard:client:receiveActivities", clientId, activities)
    end
  end)
end

local function reconcilePlayers()
  if not initJobCounters() then
    return
  end

  local nextPlayersById = {}
  local nextPlayerJobMap = {}

  for _, playerId in ipairs(GetPlayers()) do
    local src = tonumber(playerId)
    if src then
      local xPlayer = getPlayer(src)
      local record = xPlayer and createPlayerRecord(src, xPlayer)
      if record then
        local counter = ensureJobCounter(record.job, record.jobLabel)
        counter.count = counter.count + 1
        nextPlayersById[src] = record
        nextPlayerJobMap[src] = record.job
      end
    end
  end

  playersById = nextPlayersById
  playerJobMap = nextPlayerJobMap
  markPlayersDirty()
end

local function openScoreboard(src)
  if isRateLimited(src, "open", getOpenCooldown()) then
    return
  end

  if not playersById[src] then
    upsertPlayer(src)
  end

  activeClients[src] = true
  ScoreboardModule.SendToClient(src)
end

RegisterNetEvent("esx_scoreboard:server:open", function()
  openScoreboard(source)
end)

RegisterNetEvent("esx_scoreboard:server:requestData", function()
  openScoreboard(source)
end)

RegisterNetEvent("esx_scoreboard:server:requestPage", function(data)
  local src = source
  if not activeClients[src] then
    return
  end

  if isRateLimited(src, "page", getPageRequestCooldown()) then
    return
  end

  ScoreboardModule.SendPage(src, data)
end)

RegisterNetEvent("esx_scoreboard:server:close", function()
  local src = source
  if type(src) == "number" then
    activeClients[src] = nil
  end
end)

AddEventHandler("esx:playerLoaded", function(playerId, xPlayer)
  if type(playerId) ~= "number" then return end
  upsertPlayer(playerId, xPlayer)
end)

AddEventHandler("playerDropped", function()
  local src = source
  if type(src) ~= "number" then return end

  removePlayer(src)
  activeClients[src] = nil
  requestState[src] = nil
end)

AddEventHandler("esx:setJob", function(source)
  if type(source) ~= "number" then return end
  upsertPlayer(source)
end)

AddEventHandler("esx:jobDataRefreshed", function(source)
  if type(source) ~= "number" then return end
  upsertPlayer(source)
end)

AddEventHandler("playerConnecting", function()
  markPlayersDirty()
end)

AddEventHandler("onResourceStart", function(resourceName)
  if resourceName ~= RESOURCE_NAME then return end

  CreateThread(function()
    local attempts = 0
    while not initJobCounters() and attempts < 10 do
      Wait(1000)
      attempts = attempts + 1
    end

    if attempts >= 10 then
      print("[^1esx_scoreboard^7] Critical: ESX.GetJobs() unavailable after 10 attempts")
      return
    end

    reconcilePlayers()

    if Config.Debug then
      print(("[^2esx_scoreboard^7] Scoreboard ready for %s players"):format(#GetPlayers()))
    end
  end)
end)

CreateThread(function()
  while true do
    Wait(getSummaryInterval())
    if next(activeClients) then
      ScoreboardModule.BroadcastUpdate()
    end
  end
end)

CreateThread(function()
  while true do
    Wait(getPageRefreshInterval())
    if next(activeClients) then
      refreshPings()

      local refreshed = 0
      local batchSize = getPageRefreshBatchSize()
      local batchDelay = getPageRefreshBatchDelay()
      local clients = {}

      for src in pairs(activeClients) do
        clients[#clients + 1] = src
      end

      for i = 1, #clients do
        local src = clients[i]
        local state = activeClients[src] and requestState[src]
        if state and state.pageRequest and (state.pageRevision ~= playersRevision or state.pingRevision ~= pingRevision) then
          ScoreboardModule.SendPage(src, state.pageRequest)
          refreshed = refreshed + 1

          if refreshed % batchSize == 0 and batchDelay > 0 then
            Wait(batchDelay)
          end
        end
      end
    end
  end
end)

CreateThread(function()
  while true do
    Wait(getFullReconcileInterval())
    reconcilePlayers()
  end
end)

exports("AddActivity", ScoreboardModule.AddActivity)
exports("RemoveActivity", ScoreboardModule.RemoveActivity)
exports("UpdateActivity", ScoreboardModule.UpdateActivity)
exports("GetActiveActivities", ScoreboardModule.GetActiveActivities)

return ScoreboardModule
