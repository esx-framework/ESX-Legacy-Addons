-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Utils = {}

local PED_GROUND_RETRIES <const> = 40

---@param coords vector3
---@param sprite integer -- https://docs.fivem.net/docs/game-references/blips/#blips
---@param scale number -- float
---@param color integer -- https://docs.fivem.net/docs/game-references/blips/#blip-colors
---@param name string
---@return integer
function Utils.CreateBlip(coords, sprite, scale, color, name)
    return xLib.blips.create({
        coords = coords,
        sprite = sprite,
        display = 4,
        scale = scale,
        color = color,
        shortRange = true,
        label = name
    })
end

---@param model string | number
---@param coords any
---@param snapToGround boolean?
function Utils.SpawnFrozenPed(model, coords, snapToGround)
    local model_hash = xLib.streaming.requestModel(model)

    if not model_hash then
        return
    end

    local heading = coords.w or 0.0
    local spawnZ = coords.z
    local shouldSnap = snapToGround ~= false

    if shouldSnap then
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)

        for _ = 1, PED_GROUND_RETRIES do
            local success, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 2.0, false)
            if success then
                spawnZ = groundZ
                break
            end

            Wait(25)
        end
    end

    local ped = CreatePed(0, model_hash, coords.x, coords.y, spawnZ, heading, false, true)
    if not ped or ped == 0 then
        SetModelAsNoLongerNeeded(model_hash)
        return
    end

    SetEntityAsMissionEntity(ped, true, true)
    RequestCollisionAtCoord(coords.x, coords.y, spawnZ)

    for _ = 1, 20 do
        if HasCollisionLoadedAroundEntity(ped) then
            break
        end

        Wait(25)
    end

    if shouldSnap then
        for _ = 1, 10 do
            local success, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, spawnZ + 2.0, false)
            if success then
                spawnZ = groundZ
                break
            end

            Wait(25)
        end

        SetEntityCoords(ped, coords.x, coords.y, spawnZ, false, false, false, false)
    else
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, spawnZ, false, false, false)
    end

    SetEntityHeading(ped, heading)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    SetModelAsNoLongerNeeded(model_hash)

    return ped
end
