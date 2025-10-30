---Trick-or-Treat Server Logic
---Manages round scheduling, house state, rewards, and client communication

---@type TrickOrTreatConfig
local TrickOrTreatConfig = Config.TrickOrTreat
local Config = Config -- Keep reference to global Config for AdminGroups

---Track last collection time per house per round
---@type table<number, number> houseCooldowns - [houseId] = lastCollectTime
local houseCooldowns = {}

---Track current active houses in round
---@type table<number, boolean> activeHouses - [houseId] = true if active
local activeHouses = {}

---Track round state
---@type table roundState
local roundState = {
  active = false,
  startTime = 0,
  duration = 0,
  doorsPerRound = 0,
  selectedHouses = {},
  collectedCount = 0,
}

---Track player request cooldowns (anti-spam)
---@type table<number, number> playerCooldowns - [source] = timestamp
local playerCooldowns = {}

---=============================================================================
--- Round Management Functions
---=============================================================================

---Selects random houses for the current round
---@param count number Number of houses to select
---@return table selectedIndices Array of randomly selected house indices
local function SelectRandomHouses(count)
  local totalHouses = #TrickOrTreatConfig.houses
  if count > totalHouses then count = totalHouses end

  local indices = {}
  local used = {}

  while #indices < count do
    local randomIdx = math.random(1, totalHouses)
    if not used[randomIdx] then
      table.insert(indices, randomIdx)
      used[randomIdx] = true
    end
  end

  return indices
end

---Starts a new trick-or-treat round
---Selects random houses and notifies all clients
local function StartTrickOrTreatRound()
  if roundState.active then
    print('^3[ESX Halloween] A round is already active, ignoring start request^7')
    return
  end

  roundState.active = true
  roundState.startTime = GetGameTimer()
  roundState.duration = TrickOrTreatConfig.roundFrequencyMinutes * 60000
  roundState.doorsPerRound = math.min(TrickOrTreatConfig.doorsPerRound, #TrickOrTreatConfig.houses)
  roundState.selectedHouses = SelectRandomHouses(roundState.doorsPerRound)
  roundState.collectedCount = 0

  -- Initialize active houses
  activeHouses = {}
  for _, houseIdx in ipairs(roundState.selectedHouses) do
    activeHouses[houseIdx] = true
  end

  -- Notify all clients
  TriggerClientEvent(Events.ROUND_START, -1, {
    totalHouses = roundState.doorsPerRound,
    duration = roundState.duration,
    activeHouseIds = roundState.selectedHouses,
  })

  print(
    '^2[ESX Halloween] Trick-or-Treat round started! ^3' ..
      roundState.doorsPerRound ..
      ' ^2houses available^7'
  )
end

---Ends the current trick-or-treat round
---Resets state and notifies clients
local function EndTrickOrTreatRound()
  if not roundState.active then return end

  local collected = roundState.collectedCount
  local total = roundState.doorsPerRound

  TriggerClientEvent(Events.ROUND_END, -1, {
    totalCollected = collected,
    totalHouses = total,
  })

  roundState.active = false
  roundState.selectedHouses = {}
  activeHouses = {}
  houseCooldowns = {}

  print('^2[ESX Halloween] Trick-or-Treat round ended! ' .. collected .. '/' .. total .. ' collected^7')
end

---Checks if a house is currently active in the round
---@param houseIdx number Index of the house
---@return boolean True if house is active and not emptied
local function IsHouseActive(houseIdx)
  return roundState.active and activeHouses[houseIdx] == true
end

---=============================================================================
--- Reward Management Functions
---=============================================================================

---Rolls a random reward based on configured probabilities
---@return table rewardData Contains: rewardType, item, amount
local function RollReward()
  local roll = math.random(100)
  local chance = 0

  -- Check candy (70%)
  chance = chance + TrickOrTreatConfig.rewards.candy.chance
  if roll <= chance then
    return {
      rewardType = 'treat',
      item = TrickOrTreatConfig.rewards.candy.item,
      amount = TrickOrTreatConfig.candyPerDoor * TrickOrTreatConfig.rewards.candy.amount,
    }
  end

  -- Check rare candy (15%)
  chance = chance + TrickOrTreatConfig.rewards.rareCandy.chance
  if roll <= chance then
    return {
      rewardType = 'treat',
      item = TrickOrTreatConfig.rewards.rareCandy.item,
      amount = TrickOrTreatConfig.rewards.rareCandy.amount,
    }
  end

  -- Trick (15%)
  return {
    rewardType = 'trick',
    item = 'trick',
    amount = 0,
  }
end

---=============================================================================
--- Request Handlers
---=============================================================================

---Handles player house collection request
---Server-side validation with security checks
---@param source number Player server ID
---@param houseIdx number Index of house to collect from
RegisterNetEvent(Events.HOUSE_COLLECT_REQUEST)
AddEventHandler(Events.HOUSE_COLLECT_REQUEST, function(houseIdx)
  local source = source

  -- Validate player exists
  if not GetPlayerEndpoint(source) then
    TriggerClientEvent(Events.HOUSE_COLLECT_RESPONSE, source, {
      success = false,
      error = 'Player not found',
    })
    return
  end

  -- Validate round is active
  if not roundState.active then
    TriggerClientEvent(Events.HOUSE_COLLECT_RESPONSE, source, {
      success = false,
      error = 'No active round',
    })
    return
  end

  -- Validate house index
  if type(houseIdx) ~= 'number' or houseIdx < 1 or houseIdx > #TrickOrTreatConfig.houses then
    print(
      '^1[ESX Halloween] Player ' ..
        source .. ' sent invalid houseIdx: ' .. tostring(houseIdx) .. '^7'
    )
    TriggerClientEvent(Events.HOUSE_COLLECT_RESPONSE, source, {
      success = false,
      error = 'Invalid house',
    })
    return
  end

  -- Validate house is active
  if not IsHouseActive(houseIdx) then
    TriggerClientEvent(Events.HOUSE_COLLECT_RESPONSE, source, {
      success = false,
      error = 'House not available',
    })
    return
  end

  -- Validate distance (server-side security check)
  local xPlayer = ESX.Player(source)
  if not xPlayer then
    TriggerClientEvent(Events.HOUSE_COLLECT_RESPONSE, source, {
      success = false,
      error = 'Player data not found',
    })
    return
  end

  local playerPed = GetPlayerPed(source)
  if playerPed == 0 then
    TriggerClientEvent(Events.HOUSE_COLLECT_RESPONSE, source, {
      success = false,
      error = 'Ped not found',
    })
    return
  end

  local playerCoords = GetEntityCoords(playerPed)
  local houseCoords = TrickOrTreatConfig.houses[houseIdx].coords
  local distance = #(playerCoords - houseCoords)

  if distance > TrickOrTreatConfig.interaction.distance + 5.0 then
    -- Allow 5m buffer for network latency
    print(
      '^1[ESX Halloween] Player ' ..
        source ..
        ' attempted collection from ' ..
        distance ..
        'm away (max: ' ..
        (TrickOrTreatConfig.interaction.distance + 5.0) ..
        ')^7'
    )
    TriggerClientEvent(Events.HOUSE_COLLECT_RESPONSE, source, {
      success = false,
      error = 'Too far away',
    })
    return
  end

  -- Prevent double-collection of same house
  if houseCooldowns[houseIdx] and houseCooldowns[houseIdx] > GetGameTimer() - 500 then
    TriggerClientEvent(Events.HOUSE_COLLECT_RESPONSE, source, {
      success = false,
      error = 'House already collected',
    })
    return
  end

  -- Roll reward
  local reward = RollReward()

  -- Handle based on reward type
  if reward.rewardType == 'treat' then
    -- Try to add item to inventory
    if xPlayer.canCarryItem(reward.item, reward.amount) then
      xPlayer.addInventoryItem(reward.item, reward.amount)
    else
      -- Inventory full, send error response (client will show notification)
      TriggerClientEvent(Events.HOUSE_COLLECT_RESPONSE, source, {
        success = false,
        error = 'Inventory full',
      })
      return
    end
  elseif reward.rewardType == 'trick' then
    -- Apply trick effect (jumpscare + damage)
    TriggerClientEvent(Events.TRIGGER_TRICK, source)
    xPlayer.addHealth(-10) -- Small damage (max health is usually 200)
  end

  -- Mark house as collected this round
  activeHouses[houseIdx] = false
  houseCooldowns[houseIdx] = GetGameTimer()
  roundState.collectedCount = roundState.collectedCount + 1

  -- Send success response to client
  TriggerClientEvent(Events.HOUSE_COLLECT_RESPONSE, source, {
    success = true,
    rewardType = reward.rewardType,
    rewardItem = reward.item,
    rewardAmount = reward.amount,
    remainingHouses = roundState.doorsPerRound - roundState.collectedCount,
  })

  -- Broadcast progress update to all clients
  TriggerClientEvent(Events.HOUSE_STATE_SYNC, -1, {
    currentHouses = roundState.collectedCount,
    totalHouses = roundState.doorsPerRound,
    timeRemaining = roundState.duration - (GetGameTimer() - roundState.startTime),
  })

  print(
    '^2[ESX Halloween] Player ' ..
      xPlayer.getName() ..
      ' collected from house ' .. houseIdx .. ' (' .. reward.item .. ')^7'
  )
end)

---=============================================================================
--- Timers & Scheduling
---=============================================================================

---Main round timer thread
---Manages round scheduling, duration, and auto-start
---Performance: Dynamic sleep - 10s when inactive (auto-start check), 1s when active (progress updates)
CreateThread(function()
  local nextAutoStartTime = GetGameTimer() + (TrickOrTreatConfig.roundFrequencyMinutes * 60000)
  local lastProgressUpdate = 0

  print('^2[ESX Halloween] Timer thread started - next auto-start in ' .. TrickOrTreatConfig.roundFrequencyMinutes .. ' minutes^7')

  while true do
    -- Dynamic sleep: 10s when inactive (idle), 1s when active (for progress updates)
    local sleep = roundState.active and 1000 or 10000
    Wait(sleep)

    if not roundState.active then
      -- Check if time for auto-start (every 10 seconds when idle)
      if GetGameTimer() >= nextAutoStartTime then
        print('^3[ESX Halloween] Auto-starting round...^7')
        StartTrickOrTreatRound()
        nextAutoStartTime = GetGameTimer() + (TrickOrTreatConfig.roundFrequencyMinutes * 60000)
      end
    else
      -- Round is active - check if should end
      local elapsedTime = GetGameTimer() - roundState.startTime
      if elapsedTime >= roundState.duration then
        EndTrickOrTreatRound()
        nextAutoStartTime = GetGameTimer() + (TrickOrTreatConfig.roundFrequencyMinutes * 60000)
      else
        -- Send progress updates every 1 second
        if GetGameTimer() - lastProgressUpdate >= 1000 then
          lastProgressUpdate = GetGameTimer()
          TriggerClientEvent(Events.HOUSE_STATE_SYNC, -1, {
            currentHouses = roundState.collectedCount,
            totalHouses = roundState.doorsPerRound,
            timeRemaining = roundState.duration - elapsedTime,
          })
        end
      end
    end
  end
end)

---Cleanup on player disconnect
AddEventHandler('playerDropped', function()
  local source = source
  playerCooldowns[source] = nil
end)

---Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
  if GetCurrentResourceName() ~= resourceName then return end

  if roundState.active then
    EndTrickOrTreatRound()
  end

  houseCooldowns = {}
  activeHouses = {}
  playerCooldowns = {}

  print('^2[ESX Halloween] Trick-or-Treat cleaned up^7')
end)

---=============================================================================
--- Admin Permission Check
---=============================================================================

---Check if player has admin permission based on group
---@param source number Player ID
---@return boolean True if player is admin
local function HasAdminPermission(source)
  if source == 0 then return true end -- Console always has permission

  local xPlayer = ESX.Player(source)
  if not xPlayer then return false end

  local playerGroup = xPlayer.getGroup()

  for i = 1, #Config.AdminGroups do
    if playerGroup == Config.AdminGroups[i] then
      return true
    end
  end

  return false
end

---=============================================================================
--- Admin Commands
---=============================================================================

---Start a trick-or-treat round immediately
---@param source number Admin player ID
---@param args table Command arguments
TriggerEvent('chat:addSuggestion', '/startround', 'Start a trick-or-treat round immediately')
TriggerEvent('chat:addSuggestion', '/resetcooldowns', 'Reset all house cooldowns')

RegisterCommand('startround', function(source, args, rawCommand)
  if source == 0 then
    -- Console can always execute
  else
    -- Check admin permission
    if not HasAdminPermission(source) then
      TriggerClientEvent(
        'chat:addMessage',
        source,
        {
          args = { 'Halloween' },
          msg = '^1You do not have permission to use this command^7',
        }
      )
      return
    end
  end

  StartTrickOrTreatRound()

  if source ~= 0 then
    TriggerClientEvent(
      'chat:addMessage',
      source,
      { args = { 'Halloween' }, msg = '^2Round started!^7' }
    )
  end
end)

RegisterCommand('resetcooldowns', function(source, args, rawCommand)
  if source == 0 then
    -- Console can always execute
  else
    -- Check admin permission
    if not HasAdminPermission(source) then
      TriggerClientEvent(
        'chat:addMessage',
        source,
        {
          args = { 'Halloween' },
          msg = '^1You do not have permission to use this command^7',
        }
      )
      return
    end
  end

  houseCooldowns = {}
  activeHouses = {}

  if roundState.active then
    -- Re-initialize active houses
    for _, houseIdx in ipairs(roundState.selectedHouses) do
      activeHouses[houseIdx] = true
    end
  end

  if source ~= 0 then
    TriggerClientEvent(
      'chat:addMessage',
      source,
      { args = { 'Halloween' }, msg = '^2Cooldowns reset!^7' }
    )
  end
end)
