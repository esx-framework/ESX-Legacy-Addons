Utils = {}

---@param coords vector3
---@param sprite integer -- https://docs.fivem.net/docs/game-references/blips/#blips
---@param scale number -- float
---@param color integer -- https://docs.fivem.net/docs/game-references/blips/#blip-colors
---@param name string
---@return integer
function Utils.CreateBlip(coords, sprite, scale, color, name)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipSprite(blip, sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, scale)
    SetBlipColour(blip, color)
    SetBlipAsShortRange(blip, true)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(name)
    EndTextCommandSetBlipName(blip)

    return blip
end

---@param model string | number
---@param coords vector4
function Utils.SpawnFrozenPed(model, coords)
    local model_hash = ESX.Streaming.RequestModel(model)

    if not model_hash then
        return
    end

    RequestCollisionAtCoord(coords.x, coords.y, coords.y)

    Citizen.Wait(500)

    local _, correct_z = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, false)

    local ped = CreatePed(0, model_hash, coords.x, coords.y, correct_z, coords.w, false, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    SetModelAsNoLongerNeeded(model)
end
