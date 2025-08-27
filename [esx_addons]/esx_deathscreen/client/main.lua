local firstSpawn = true
isDead = false

RegisterNetEvent('esx:onPlayerLogout')
AddEventHandler('esx:onPlayerLogout', function()
  firstSpawn = true
end)

AddEventHandler('esx:onPlayerSpawn', function()
  if firstSpawn then
    firstSpawn = false
    return
  end
  isDead = false
  ClearTimecycleModifier()
  SetPedMotionBlur(PlayerPedId(), false)
  ClearExtraTimecycleModifier()
  EndDeathCam()
  
  -- Hook for other scripts to run code when player revives - example: esx_ambulancejob
  TriggerEvent('esx_deathscreen:onPlayerRevive')
end)

function RemoveItemsAfterRPDeath()
  TriggerServerEvent('esx_deathscreen:setDeathStatus', false)

  CreateThread(function()
    ESX.TriggerServerCallback('esx_deathscreen:removeItemsAfterRPDeath', function()
      local ClosestHospital = GetClosestRespawnPoint()

      ESX.SetPlayerData('loadout', {})

      DoScreenFadeOut(800)
      RespawnPed(PlayerPedId(), ClosestHospital.coords, ClosestHospital.heading)
      while not IsScreenFadedOut() do
        Wait(0)
      end
      DoScreenFadeIn(800)
    end)
  end)
end

function StartDeathLoop() 
  CreateThread(function()
    while isDead do
      DisableAllControlActions(0)
      EnableControlAction(0, 47, true) -- G 
      EnableControlAction(0, 245, true) -- T
      EnableControlAction(0, 38, true) -- E

      ProcessCamControls()
      
      -- Hook for other scripts to run code during death loop - example: esx_ambulancejob
      TriggerEvent('esx_deathscreen:onDeathLoop', isDead)
      
      Wait(0)
    end
  end)
end

function StartDistressSignal()
  CreateThread(function()
    local timer = Config.BleedoutTimer

    while timer > 0 and isDead do
      Wait(0)
      timer = timer - 30

      SetTextFont(4)
      SetTextScale(0.5, 0.5)
      SetTextColour(200, 50, 50, 255)
      SetTextDropshadow(0.1, 3, 27, 27, 255)
      BeginTextCommandDisplayText('STRING')
      AddTextComponentSubstringPlayerName(TranslateCap('distress_send'))
      EndTextCommandDisplayText(0.446, 0.77)

      if IsControlJustReleased(0, 47) then
        SendDistressSignal()
        break
      end
    end
  end)
end

function StartDeathTimer()
  local canPayFine = false

  if Config.EarlyRespawnFine then
    ESX.TriggerServerCallback('esx_deathscreen:checkBalance', function(canPay)
      canPayFine = canPay
    end)
  end

  local earlySpawnTimer = ESX.Math.Round(Config.EarlyRespawnTimer / 1000)
  local bleedoutTimer = ESX.Math.Round(Config.BleedoutTimer / 1000)

  CreateThread(function()
    -- early respawn timer
    while earlySpawnTimer > 0 and isDead do
      Wait(1000)

      if earlySpawnTimer > 0 then
        earlySpawnTimer = earlySpawnTimer - 1
      end
    end

    -- bleedout timer
    while bleedoutTimer > 0 and isDead do
      Wait(1000)

      if bleedoutTimer > 0 then
        bleedoutTimer = bleedoutTimer - 1
      end
    end
  end)

  CreateThread(function()
    local text, timeHeld

    -- early respawn timer
    while earlySpawnTimer > 0 and isDead do
      Wait(0)
      text = TranslateCap('respawn_available_in', secondsToClock(earlySpawnTimer))

      DrawGenericTextThisFrame()
      BeginTextCommandDisplayText('STRING')
      AddTextComponentSubstringPlayerName(text)
      EndTextCommandDisplayText(0.5, 0.8)
    end

    -- bleedout timer
    while bleedoutTimer > 0 and isDead do
      Wait(0)
      text = TranslateCap('respawn_bleedout_in', secondsToClock(bleedoutTimer))

      if not Config.EarlyRespawnFine then
        text = text .. TranslateCap('respawn_bleedout_prompt')

        if IsControlPressed(0, 38) and timeHeld > 120 then
          RemoveItemsAfterRPDeath()
          break
        end
      elseif Config.EarlyRespawnFine and canPayFine then
        text = text .. TranslateCap('respawn_bleedout_fine', ESX.Math.GroupDigits(Config.EarlyRespawnFineAmount))

        if IsControlPressed(0, 38) and timeHeld > 120 then
          TriggerServerEvent('esx_deathscreen:payFine')
          RemoveItemsAfterRPDeath()
          break
        end
      end

      if IsControlPressed(0, 38) then
        timeHeld += 1
      else
        timeHeld = 0
      end

      DrawGenericTextThisFrame()

      BeginTextCommandDisplayText('STRING')
      AddTextComponentSubstringPlayerName(text)
      EndTextCommandDisplayText(0.5, 0.8)
    end

    if bleedoutTimer < 1 and isDead then
      RemoveItemsAfterRPDeath()
    end
  end)
end

function GetClosestRespawnPoint()
  local plyCoords = GetEntityCoords(PlayerPedId())
  local closestDist, closestHospital 

  for i=1, #Config.RespawnPoints do 
      local dist = #(plyCoords - Config.RespawnPoints[i].coords) 

      if not closestDist or dist <= closestDist then
          closestDist, closestHospital = dist, Config.RespawnPoints[i] 
      end 
  end 
  
  return closestHospital
end


AddEventHandler('esx:onPlayerDeath', function(data)
  OnPlayerDeath()
end)


function OnPlayerDeath()
  ESX.CloseContext()
  ClearTimecycleModifier()
  SetTimecycleModifier("REDMIST_blend")
  SetTimecycleModifierStrength(0.7)
  SetExtraTimecycleModifier("fp_vig_red")
  SetExtraTimecycleModifierStrength(1.0)
  SetPedMotionBlur(PlayerPedId(), true)
  TriggerServerEvent('esx_deathscreen:setDeathStatus', true)
  StartDeathTimer()
  StartDeathCam()
  isDead = true
  StartDeathLoop() 
  
  if Config.AmbulanceJobEnabled == true then
  StartDistressSignal()
  end
  if Config.DeathAnim.enabled then
    local coords = GetEntityCoords(ESX.PlayerData.ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, 0.0, 0.0, false)
    ESX.Streaming.RequestAnimDict(Config.DeathAnim.dict)
    TaskPlayAnim(ESX.PlayerData.ped, Config.DeathAnim.dict, Config.DeathAnim.name, Config.DeathAnim.fadeIn, Config.DeathAnim.fadeOut,
      -1, Config.DeathAnim.flags, Config.DeathAnim.playbackRate, false, false, false)
    FreezeEntityPosition(ESX.PlayerData.ped, true)

    Citizen.CreateThreadNow(function()
      while ESX.PlayerData.dead do
        if not IsEntityPlayingAnim(ESX.PlayerData.ped, Config.DeathAnim.dict, Config.DeathAnim.name, 3) then
          TaskPlayAnim(ESX.PlayerData.ped, Config.DeathAnim.dict, Config.DeathAnim.name, Config.DeathAnim.fadeIn, Config.DeathAnim.fadeOut,
            -1, Config.DeathAnim.flags, Config.DeathAnim.playbackRate, false, false, false)
        end
        Wait(0)
      end
      RemoveAnimDict(Config.DeathAnim.dict)
    end)

  end
  
  -- Hook for other scripts to run code when player dies - example: esx_ambulancejob
  TriggerEvent('esx_deathscreen:onPlayerDeath')
end

function SendDistressSignal()
  local playerPed = PlayerPedId()
  local coords = GetEntityCoords(playerPed)

  ESX.ShowNotification(TranslateCap('distress_sent'))
  TriggerServerEvent('esx_ambulancejob:onPlayerDistress')
end

function DrawGenericTextThisFrame()
  SetTextFont(4)
  SetTextScale(0.0, 0.5)
  SetTextColour(255, 255, 255, 255)
  SetTextDropshadow(0, 0, 0, 0, 255)
  SetTextDropShadow()
  SetTextOutline()
  SetTextCentre(true)
end

function secondsToClock(seconds)
  local seconds, hours, mins, secs = tonumber(seconds), 0, 0, 0

  if seconds <= 0 then
    return 0, 0
  else
    local hours = string.format('%02.f', math.floor(seconds / 3600))
    local mins = string.format('%02.f', math.floor(seconds / 60 - (hours * 60)))
    local secs = string.format('%02.f', math.floor(seconds - hours * 3600 - mins * 60))

    return mins, secs
  end
end

function RespawnPed(ped, coords, heading)
  SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
  NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
  SetPlayerInvincible(ped, false)
  ClearPedBloodDamage(ped)

  if Config.DeathAnim.enabled then
    FreezeEntityPosition(ped, false)
  end

  TriggerEvent('esx_basicneeds:resetStatus')
  TriggerServerEvent('esx:onPlayerSpawn')
  TriggerEvent('esx:onPlayerSpawn')
  TriggerEvent('playerSpawned') -- compatibility with old scripts, will be removed soon
end