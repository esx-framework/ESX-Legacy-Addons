---Trick-or-Treat Client Logic
---Manages NPC spawning, blips, interactions, and UI updates

---@type TrickOrTreatConfig
local Config

---Store spawned house NPCs
---@type table<number, number> houseNPCs - [houseIdx] = pedHandle
local houseNPCs = {}

---Store active blips
---@type table<number, number> blips - [houseIdx] = blipHandle
local blips = {}

---Track current active houses
---@type table<number, boolean> activeHouses - [houseIdx] = true
local activeHouses = {}

---Round state tracking
---@type table roundState
local roundState = {
  active = false,
  totalHouses = 0,
  currentHouses = 0,
  timeRemaining = 0,
}

---Player interaction state
local inRound = false

---=============================================================================
--- NPC Management
---=============================================================================

---Spawn NPC for a specific house location
---@param houseIdx number Index of house
---@param house table House data (coords, heading, pedModel)
local function SpawnHouseNPC(houseIdx, house)
  -- Request model
  local modelHash = GetHashKey(house.pedModel)

  RequestModel(modelHash)
  local startTime = GetGameTimer()
  while not HasModelLoaded(modelHash) do
    Wait(50)
    if GetGameTimer() - startTime > 5000 then
      print('^1[ESX Halloween] Failed to load model: ' .. house.pedModel .. '^7')
      return
    end
  end

  -- Get proper ground Z coordinate (search up to 50 units down)
  local groundZ, groundFound = GetGroundZFor_3dCoord(house.coords.x, house.coords.y, house.coords.z + 50.0, false)
  local spawnZ = groundFound and groundZ or house.coords.z

  -- Create ped at ground level
  local ped = CreatePed(4, modelHash, house.coords.x, house.coords.y, spawnZ, house.heading, false, false)

  -- Ensure ped is placed properly on ground
  PlaceObjectOnGroundProperly(ped)

  -- Configure ped
  SetEntityAsMissionEntity(ped, true, true)
  SetBlockingOfNonTemporaryEvents(ped, true)
  FreezeEntityPosition(ped, true)
  SetEntityInvincible(ped, true)

  -- Store reference
  houseNPCs[houseIdx] = ped

  -- Release model
  SetModelAsNoLongerNeeded(modelHash)
end

---Spawn all NPCs for active houses
local function SpawnAllNPCs()
  for idx, house in ipairs(Config.houses) do
    if activeHouses[idx] then
      SpawnHouseNPC(idx, house)
    end
  end

  print('^2[ESX Halloween] Spawned Trick-or-Treat NPCs^7')
end

---Delete all spawned NPCs
local function DeleteAllNPCs()
  for idx, ped in pairs(houseNPCs) do
    if DoesEntityExist(ped) then
      DeleteEntity(ped)
    end
  end
  houseNPCs = {}
end

---=============================================================================
--- Blip Management
---=============================================================================

---Create or update blips for active houses
---@param activeHouseIds table Array of active house indices
local function UpdateActiveBlips(activeHouseIds)
  -- Delete old blips
  for _, blip in pairs(blips) do
    if blip ~= 0 then
      RemoveBlip(blip)
    end
  end
  blips = {}

  -- Create new blips for active houses
  for _, houseIdx in ipairs(activeHouseIds) do
    local house = Config.houses[houseIdx]
    if house then
      local blip = AddBlipForCoord(house.coords.x, house.coords.y, house.coords.z)
      SetBlipAsShortRange(blip, false)
      SetBlipSprite(blip, Config.blips.sprite)
      SetBlipColour(blip, Config.blips.activeColor)
      SetBlipScale(blip, Config.blips.scale)
      BeginTextCommandSetBlipName('STRING')
      AddTextComponentString('Trick-or-Treat House')
      EndTextCommandSetBlipName(blip)

      blips[houseIdx] = blip
    end
  end
end

---Remove all blips
local function RemoveAllBlips()
  for _, blip in pairs(blips) do
    if blip ~= 0 then
      RemoveBlip(blip)
    end
  end
  blips = {}
end

---=============================================================================
--- Interaction Handling (Performance-Optimized Multi-Level Loop)
---=============================================================================

---Send house collection request to server
---@param houseIdx number Index of house to collect from
local function SendHouseCollectRequest(houseIdx)
  TriggerServerEvent(Events.HOUSE_COLLECT_REQUEST, houseIdx)
end

-- Track currently nearby house for fast rendering
local nearbyHouseIdx = nil

---=============================================================================
--- NUI Communication
---=============================================================================

---Handle round start from server
RegisterNetEvent(Events.ROUND_START)
AddEventHandler(Events.ROUND_START, function(data)
  print('^3[DEBUG] ROUND_START event received^7')
  print('^3[DEBUG] Data: ' .. json.encode(data) .. '^7')

  -- Validate data parameter
  if type(data) ~= "table" then
    print('^1[ESX Halloween] Invalid round start data^7')
    return
  end

  if type(data.totalHouses) ~= "number" or
     type(data.duration) ~= "number" or
     type(data.activeHouseIds) ~= "table" then
    print('^1[ESX Halloween] Missing required round start fields^7')
    return
  end

  roundState.active = true
  roundState.totalHouses = data.totalHouses
  roundState.currentHouses = 0
  roundState.timeRemaining = data.duration

  -- Store active houses
  activeHouses = {}
  for _, houseIdx in ipairs(data.activeHouseIds) do
    activeHouses[houseIdx] = true
  end

  -- Spawn NPCs for this round
  SpawnAllNPCs()

  -- Update blips
  UpdateActiveBlips(data.activeHouseIds)

  -- Notify UI
  SendNUIMessage({
    type = 'trickOrTreatRoundStart',
    totalHouses = data.totalHouses,
    timeRemaining = data.duration,
    activeHouseIds = data.activeHouseIds,
  })

  print('^2[ESX Halloween] Trick-or-Treat round started (client)^7')

  -- Start Interaction Thread (only runs while round is active)
  CreateThread(function()
    while roundState.active do
      local sleep = 1000 -- Default: check once per second when not near a house

      -- HELP TEXT RENDERING + KEY HANDLING (only when near house)
      if Config and Config.enabled and nearbyHouseIdx and roundState.active then
        sleep = 0 -- Only use Wait(0) when ACTUALLY near a house

        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local house = Config.houses[nearbyHouseIdx]

        if house then
          local distance = #(playerCoords - house.coords)

          if distance <= Config.interaction.distance then
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentString('Press ~INPUT_CONTEXT~ to collect candy')
            EndTextCommandDisplayHelp(0)

            -- Handle E-key press
            if IsControlJustReleased(0, Config.interaction.key) then
              SendHouseCollectRequest(nearbyHouseIdx)
            end
          end
        end
      end

      Wait(sleep)
    end
  end)

  -- Start Proximity Detection Thread (only runs while round is active)
  CreateThread(function()
    while roundState.active do
      Wait(500)

      if Config and Config.enabled then
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local nearestHouseIdx = nil
        local nearestDistance = Config.interaction.distance

        for houseIdx, house in ipairs(Config.houses) do
          if activeHouses[houseIdx] then
            local distance = #(playerCoords - house.coords)

            if distance < nearestDistance then
              nearestDistance = distance
              nearestHouseIdx = houseIdx
            end
          end
        end

        nearbyHouseIdx = nearestHouseIdx
      else
        nearbyHouseIdx = nil
      end
    end
  end)
end)

---Handle round end from server
RegisterNetEvent(Events.ROUND_END)
AddEventHandler(Events.ROUND_END, function(data)
  -- Validate data parameter
  if type(data) ~= "table" then
    print('^1[ESX Halloween] Invalid round end data^7')
    return
  end

  if type(data.totalCollected) ~= "number" or type(data.totalHouses) ~= "number" then
    print('^1[ESX Halloween] Missing round end fields^7')
    return
  end

  roundState.active = false

  -- Delete NPCs
  DeleteAllNPCs()

  -- Remove blips
  RemoveAllBlips()

  -- Notify UI
  SendNUIMessage({
    type = 'trickOrTreatRoundEnd',
    totalCollected = data.totalCollected,
    totalHouses = data.totalHouses,
  })

  print('^2[ESX Halloween] Trick-or-Treat round ended (client)^7')
end)

---Handle house collection response from server
RegisterNetEvent(Events.HOUSE_COLLECT_RESPONSE)
AddEventHandler(Events.HOUSE_COLLECT_RESPONSE, function(data)
  -- Validate data parameter
  if type(data) ~= "table" then
    print('^1[ESX Halloween] Invalid collect response data^7')
    return
  end

  if type(data.success) ~= "boolean" then
    print('^1[ESX Halloween] Missing success field^7')
    return
  end

  if data.success then
    -- Validate reward fields
    if not data.rewardType or not data.rewardItem or type(data.rewardAmount) ~= "number" then
      print('^1[ESX Halloween] Missing reward data^7')
      return
    end

    -- Show reward popup
    SendNUIMessage({
      type = 'trickOrTreatCollect',
      rewardType = data.rewardType,
      rewardItem = data.rewardItem,
      rewardAmount = data.rewardAmount,
      remainingHouses = data.remainingHouses,
    })

    -- Play success sound
    TriggerEvent('esx:showNotification', 'Collected from house!')
  else
    -- Show error notification
    local errorMsg = "Unknown error"
    if type(data.error) == "string" then
      errorMsg = data.error
    end
    TriggerEvent('esx:showNotification', 'Failed: ' .. errorMsg)
  end
end)

---Handle house state synchronization from server
RegisterNetEvent(Events.HOUSE_STATE_SYNC)
AddEventHandler(Events.HOUSE_STATE_SYNC, function(data)
  -- Validate data parameter
  if type(data) ~= "table" then
    print('^1[ESX Halloween] Invalid state sync data^7')
    return
  end

  if type(data.currentHouses) ~= "number" or
     type(data.totalHouses) ~= "number" or
     type(data.timeRemaining) ~= "number" then
    print('^1[ESX Halloween] Missing state sync fields^7')
    return
  end

  if roundState.active then
    roundState.currentHouses = data.currentHouses
    roundState.totalHouses = data.totalHouses
    roundState.timeRemaining = data.timeRemaining

    -- Update UI progress
    SendNUIMessage({
      type = 'trickOrTreatProgress',
      currentHouses = data.currentHouses,
      totalHouses = data.totalHouses,
      timeRemaining = data.timeRemaining,
    })
  end
end)

---Handle trick effect (trick reward)
RegisterNetEvent(Events.TRIGGER_TRICK)
AddEventHandler(Events.TRIGGER_TRICK, function()
  -- Screen shake
  ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.5)

  -- Show jumpscare UI
  SendNUIMessage({
    type = 'trickOrTreatCollect',
    rewardType = 'trick',
    rewardItem = 'trick',
    rewardAmount = 0,
  })

  TriggerEvent('esx:showNotification', '^1You got tricked!^7')
end)

---=============================================================================
--- Cleanup
---=============================================================================

---Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
  if GetCurrentResourceName() ~= resourceName then return end

  DeleteAllNPCs()
  RemoveAllBlips()
  roundState.active = false

  print('^2[ESX Halloween] Trick-or-Treat client cleaned up^7')
end)

---=============================================================================
--- Initialization
---=============================================================================

--- Initialize config after resource load
CreateThread(function()
  print('^2[TrickOrTreat] Waiting for global config...^7')

  -- Wait for global Config to be defined
  local maxWaits = 50
  local waits = 0
  while not _G.Config or not _G.Config.TrickOrTreat do
    Wait(100)
    waits = waits + 1
    if waits >= maxWaits then
      print('^1[TrickOrTreat] Config timeout!^7')
      return
    end
  end

  Config = _G.Config.TrickOrTreat

  if not Config or not Config.enabled then
    print('^3[TrickOrTreat] Trick-or-Treat is disabled, skipping init^7')
    return
  end

  print('^2[TrickOrTreat] ✓ Client initialized^7')
end)
