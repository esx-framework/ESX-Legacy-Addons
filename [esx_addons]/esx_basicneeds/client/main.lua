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

local function handleAnimation(itemType, propName, anim, pos, rot)
    if IsAnimated then return end

    IsAnimated = true
    local playerPed = PlayerPedId()
    local x, y, z = table.unpack(GetEntityCoords(playerPed))
    local prop = CreateObject(joaat(propName), x, y, z + 0.2, true, true, true)
    local boneIndex = GetPedBoneIndex(playerPed, 18905)

    pos = pos or vector3(0.12, 0.028, 0.001)
    rot = rot or vector3(10.0, 175.0, 0.0)

    AttachEntityToEntity(prop, playerPed, boneIndex, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)

    CreateThread(function()
        ESX.Streaming.RequestAnimDict(anim.dict, function()
            TaskPlayAnim(playerPed, anim.dict, anim.name, table.unpack(anim.settings))
            RemoveAnimDict(anim.dict)

            Wait(3000)
            IsAnimated = false
            ClearPedSecondaryTask(playerPed)
            DeleteObject(prop)
        end)
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
