-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local IsDead = false
local IsAnimated = false

local function setPlayerNeeds(hunger, thirst)
    TriggerEvent('esx_status:set', 'hunger', hunger)
    TriggerEvent('esx_status:set', 'thirst', thirst)
end

AddEventHandler('esx_basicneeds:resetStatus', function()
    setPlayerNeeds(500000, 500000)
end)


RegisterNetEvent('esx_basicneeds:healPlayer')
AddEventHandler('esx_basicneeds:healPlayer', function()
    setPlayerNeeds(1000000, 1000000)

    local playerPed = PlayerPedId()
    SetEntityHealth(playerPed, GetEntityMaxHealth(playerPed))
end)

AddEventHandler('esx:onPlayerDeath', function()
    IsDead = true
end)

AddEventHandler('esx:onPlayerSpawn', function()
    if IsDead then
		setPlayerNeeds(500000, 500000)
    end
    IsDead = false
end)

AddEventHandler('esx_status:loaded', function()
    local function registerStatus(name, color, removalRate)
        TriggerEvent('esx_status:registerStatus', name, 1000000, color, 
            function() return Config.Visible end,
            function(status) status.remove(removalRate) end
        )
    end

    registerStatus('hunger', '#CFAD0F', 100)
    registerStatus('thirst', '#0C98F1', 75)
end)

AddEventHandler('esx_status:onTick', function(statuses)
    local playerPed = PlayerPedId()
    local prevHealth = GetEntityHealth(playerPed)
    local newHealth = prevHealth

    for _, status in pairs(statuses) do
        if status.percent == 0 then
            local damage = (prevHealth <= 150) and 5 or 1
            if status.name == 'hunger' or status.name == 'thirst' then
                newHealth = newHealth - damage
            end
        end
    end

    if newHealth ~= prevHealth then
        SetEntityHealth(playerPed, newHealth)
    end
end)

AddEventHandler('esx_basicneeds:isEating', function(callback)
    callback(IsAnimated)
end)

local OFFSET_AXES <const> = { 'x', 'y', 'z' }

local function isValidOffset(offset)
    if type(offset) ~= 'vector3' and type(offset) ~= 'table' then
        return false
    end

    for i = 1, #OFFSET_AXES do
        local value = offset[OFFSET_AXES[i]]

        if
            type(value) ~= 'number'
            or value ~= value
            or value == math.huge
            or value == -math.huge
        then
            return false
        end
    end

    return true
end

local function handleAnimation(itemType, propName, anim, pos, rot)
    if IsAnimated then
        return
    end

    if itemType ~= 'food' and itemType ~= 'drink' then
        return
    end

    if type(propName) ~= 'string' or propName == '' then
        return
    end

    if anim == nil then
        anim = {
            dict = itemType == 'food' and 'mp_player_inteat@burger' or 'mp_player_intdrink',
            name = itemType == 'food' and 'mp_player_int_eat_burger_fp' or 'loop_bottle',
            settings = {
                8.0,
                -8.0,
                -1,
                49,
                0.0,
                false,
                false,
                false,
            },
        }
    end

    if
        type(anim) ~= 'table'
        or type(anim.dict) ~= 'string'
        or anim.dict == ''
        or type(anim.name) ~= 'string'
        or anim.name == ''
        or type(anim.settings) ~= 'table'
    then
        return
    end

    for i = 1, 8 do
        local value = anim.settings[i]

        if i <= 5 or type(value) ~= 'boolean' then
            if
                type(value) ~= 'number'
                or value ~= value
                or value == math.huge
                or value == -math.huge
            then
                return
            end
        end
    end

    pos = pos or vector3(0.12, 0.028, 0.001)
    rot = rot or vector3(10.0, 175.0, 0.0)

    if not isValidOffset(pos) or not isValidOffset(rot) then
        return
    end

    IsAnimated = true

    CreateThread(function()
        local playerPed = PlayerPedId()
        local prop
        local model
        local animationLoaded = false

        local ok, err = pcall(function()
            model = xLib.streaming.requestModel(propName)

            if not model then
                return
            end

            animationLoaded = xLib.streaming.requestAnimDict(anim.dict) ~= nil

            if not animationLoaded or not DoesEntityExist(playerPed) then
                return
            end

            local coords = GetEntityCoords(playerPed)
            prop = CreateObject(model, coords.x, coords.y, coords.z + 0.2, true, true, true)
            SetModelAsNoLongerNeeded(model)
            model = nil

            if prop == 0 then
                return
            end

            local boneIndex = GetPedBoneIndex(playerPed, 18905)

            AttachEntityToEntity(
                prop, playerPed, boneIndex,
                pos.x, pos.y, pos.z,
                rot.x, rot.y, rot.z,
                true, true, false, true, 1, true
            )

            TaskPlayAnim(playerPed, anim.dict, anim.name, table.unpack(anim.settings, 1, 8))
            RemoveAnimDict(anim.dict)
            animationLoaded = false

            Wait(3000)
        end)

        if model then
            SetModelAsNoLongerNeeded(model)
        end

        if animationLoaded then
            RemoveAnimDict(anim.dict)
        end

        if prop and prop ~= 0 then
            if DoesEntityExist(playerPed) then
                ClearPedSecondaryTask(playerPed)
            end

            DeleteObject(prop)
        end

        IsAnimated = false

        if not ok then
            print(('[esx_basicneeds] Animation failed: %s'):format(tostring(err)))
        end
    end)
end

RegisterNetEvent('esx_basicneeds:onUse', function(itemType, propName, anim, pos, rot)
    propName = propName or (itemType == 'food' and 'prop_cs_burger_01' or 'prop_ld_flow_bottle')
    handleAnimation(itemType, propName, anim, pos, rot)
end)

local function warnDeprecated(eventName, itemType, propName)
    local invokingResource = GetInvokingResource()
    print(('[^3WARNING^7] ^5%s^7 used ^5%s^7, which is deprecated. Refer to ESX documentation for updates.'):format(invokingResource, eventName))
    TriggerEvent('esx_basicneeds:onUse', itemType, propName)
end

RegisterNetEvent('esx_basicneeds:onEat', function(propName)
    warnDeprecated('esx_basicneeds:onEat', 'food', propName or 'prop_cs_burger_01')
end)

AddEventHandler('esx_basicneeds:onDrink', function(propName)
    warnDeprecated('esx_basicneeds:onDrink', 'drink', propName or 'prop_ld_flow_bottle')
end)
