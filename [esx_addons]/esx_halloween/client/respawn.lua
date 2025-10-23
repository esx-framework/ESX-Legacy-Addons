--- Finds the closest hospital respawn point from Config.RespawnPoints
---@return table|nil Closest respawn point with coords and heading, or nil if no respawn points configured
---@example
--- local hospital = GetClosestRespawnPoint()
--- if hospital then
---     SetEntityCoords(ped, hospital.coords.x, hospital.coords.y, hospital.coords.z)
--- end
local function GetClosestRespawnPoint()
    if not Config.RespawnPoints or #Config.RespawnPoints == 0 then
        print('^1[ESX Halloween] Error: No respawn points configured in Config.RespawnPoints^7')
        return nil
    end

    local plyCoords = GetEntityCoords(PlayerPedId())
    local closestDist, closestHospital

    for i = 1, #Config.RespawnPoints do
        local dist = #(plyCoords - Config.RespawnPoints[i].coords)

        if not closestDist or dist <= closestDist then
            closestDist, closestHospital = dist, Config.RespawnPoints[i]
        end
    end

    return closestHospital
end

--- Fades screen to black and waits for completion
--- Uses 800ms fade duration as standard
---@return nil
function FadeScreenOut()
    DoScreenFadeOut(800)
    while not IsScreenFadedOut() do
        Wait(50)
    end
end

--- Fades screen in from black
--- Uses 800ms fade duration as standard
---@return nil
function FadeScreenIn()
    DoScreenFadeIn(800)
end

--- Restores player to freemode model and loads their saved skin
--- Determines correct model based on player's sex (male/female)
--- Loads skin via ESX skinchanger after model change
---@param callback function|nil Function to call after skin is restored
---@return nil
---@example
--- RestorePlayerSkin(function(playerPed)
---     print('Skin restored for ped: ' .. playerPed)
--- end)
function RestorePlayerSkin(callback)
    TriggerEvent('skinchanger:getSkin', function(skin)
        if not skin then
            print('^1[ESX Halloween] Error: Failed to get player skin from skinchanger^7')
            if callback then callback(PlayerPedId()) end
            return
        end

        local modelHash = skin.sex == 0 and GetHashKey('mp_m_freemode_01') or GetHashKey('mp_f_freemode_01')

        RequestModel(modelHash)
        local timeout = 0
        while not HasModelLoaded(modelHash) and timeout < 100 do
            Wait(50)
            timeout = timeout + 1
        end

        if not HasModelLoaded(modelHash) then
            print('^1[ESX Halloween] Error: Failed to load player model^7')
            if callback then callback(PlayerPedId()) end
            return
        end

        SetPlayerModel(PlayerId(), modelHash)
        SetModelAsNoLongerNeeded(modelHash)

        Wait(100)

        TriggerEvent('skinchanger:loadSkin', skin)

        Wait(100)

        local playerPed = PlayerPedId()
        SetEntityInvincible(playerPed, false)
        SetEntityAlpha(playerPed, 255, false)
        SetPedCanRagdoll(playerPed, true)

        if callback then
            callback(playerPed)
        end
    end)
end

--- Respawns player at closest hospital from Config.RespawnPoints
--- Triggers ESX ambulancejob callback to remove items
--- Uses NetworkResurrectLocalPlayer for proper respawn
---@return nil
---@example
--- RespawnAtHospital()
function RespawnAtHospital()
    if not ESX then
        print('^1[ESX Halloween] Error: ESX not loaded, cannot respawn at hospital^7')
        FadeScreenIn()
        return
    end

    ESX.TriggerServerCallback('esx_ambulancejob:removeItemsAfterRPDeath', function()
        local playerPed = PlayerPedId()
        local closestHospital = GetClosestRespawnPoint()

        if closestHospital then
            local coords = closestHospital.coords
            local heading = closestHospital.heading or 0.0

            SetEntityCoordsNoOffset(playerPed, coords.x, coords.y, coords.z, false, false, false)
            NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
            SetPlayerInvincible(playerPed, false)
            ClearPedBloodDamage(playerPed)

            TriggerServerEvent('esx:onPlayerSpawn')
            TriggerEvent('esx:onPlayerSpawn')
        else
            print('^1[ESX Halloween] Error: No respawn point found, respawning at current location^7')
        end

        FadeScreenIn()
    end)
end
