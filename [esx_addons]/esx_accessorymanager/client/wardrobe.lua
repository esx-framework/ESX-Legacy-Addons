-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local Wardrobe = { removed = {}, hairFixed = false, savedHair = nil }
Accessories.Wardrobe = Wardrobe
local hairOverride

local function snapshot(skin)
    local result = {}
    for key, value in pairs(skin) do
        if type(value) ~= 'table' then result[key] = value end
    end
    return result
end

local function copyFields(skin, fields)
    local result = {}
    for _, key in ipairs(fields) do result[key] = skin[key] end
    return result
end

local function matches(skin, values)
    for key, value in pairs(values) do
        if skin[key] ~= value then return false end
    end
    return true
end

local function playClothingAnimation(category, direction)
    local settings = Config.Radial and Config.Radial.Animation
    if not settings or settings.Enabled == false then return end

    local clip = settings.ByCategory and settings.ByCategory[category.id] or settings.Default
    if type(clip) == 'table' and clip.on and clip.off then
        clip = direction == 'on' and clip.on or clip.off
    end
    if type(clip) ~= 'table' or type(clip.dict) ~= 'string' or type(clip.anim) ~= 'string' then return end

    RequestAnimDict(clip.dict)
    local deadline = GetGameTimer() + (tonumber(settings.Timeout) or 500)
    while not HasAnimDictLoaded(clip.dict) and GetGameTimer() < deadline do Wait(10) end
    if not HasAnimDictLoaded(clip.dict) then return end

    local duration = tonumber(clip.duration or settings.Duration) or 900
    TaskPlayAnim(PlayerPedId(), clip.dict, clip.anim, 4.0, -4.0, duration, tonumber(clip.flag or settings.Flag) or 49, 0.0, false, false, false)
    Wait(duration)
    StopAnimTask(PlayerPedId(), clip.dict, clip.anim, 1.0)
    RemoveAnimDict(clip.dict)
end

function Wardrobe.Clear()
    Wardrobe.removed = {}
    Wardrobe.ped, Wardrobe.model = nil, nil
    Wardrobe.lastSkin = nil
    Wardrobe.hairFixed = false
    Wardrobe.savedHair = nil
    hairOverride = nil
end

function Wardrobe.Read()
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    if Wardrobe.ped ~= ped or Wardrobe.model ~= model then Wardrobe.Clear() end
    Wardrobe.ped, Wardrobe.model = ped, model
    local skin = exports.skinchanger:GetSkin()
    if type(skin) ~= 'table' then return nil end
    if Wardrobe.lastSkin and not matches(skin, Wardrobe.lastSkin) then Wardrobe.removed = {} end
    Wardrobe.lastSkin = snapshot(skin)
    for id, item in pairs(Wardrobe.removed) do
        if not matches(skin, item.off) then Wardrobe.removed[id] = nil end
    end
    return skin
end

function Wardrobe.IsSupported()
    local model = GetEntityModel(PlayerPedId())
    return model == joaat('mp_m_freemode_01') or model == joaat('mp_f_freemode_01')
end

function Wardrobe.OffValues(category, skin)
    local defaults = Config.Radial.Undressed[skin.sex == 1 and 'female' or 'male']
    local drawable = category.prop and -1 or (category.undressed and defaults[category.undressed] or 0)
    local result = { [category.fields[1]] = drawable, [category.fields[2]] = 0 }
    if category.id == 'torso' then result.arms, result.arms_2 = defaults.arms, 0 end
    return result
end

local function validValues(category, values)
    if type(values) ~= 'table' then return false end
    local drawable, texture = values[category.fields[1]], values[category.fields[2]]
    if type(drawable) ~= 'number' or type(texture) ~= 'number' then return false end
    if drawable % 1 ~= 0 or texture % 1 ~= 0 or texture < 0 then return false end
    local ped = PlayerPedId()
    if category.prop then
        return drawable == -1 or (drawable >= 0
            and drawable < GetNumberOfPedPropDrawableVariations(ped, category.prop)
            and texture < GetNumberOfPedPropTextureVariations(ped, category.prop, drawable))
    end
    if not IsPedComponentVariationValid(ped, category.component, drawable, texture) then return false end
    if category.id == 'torso' then
        return type(values.arms) == 'number' and type(values.arms_2) == 'number'
            and IsPedComponentVariationValid(ped, 3, values.arms, values.arms_2)
    end
    return true
end

local function setHair(hair)
    SetPedComponentVariation(PlayerPedId(), 2, hair.hair_1, hair.hair_2, 2)
    SetPedHairColor(PlayerPedId(), hair.hair_color_1, hair.hair_color_2)
end

local function forceHairSkin(hair)
    hairOverride = hair
    if hair then setHair(hair) end
    Wardrobe.lastSkin = snapshot(exports.skinchanger:GetSkin())
end

local function apply(skin, patch)
    -- Keep skinchanger's state consistent with the ped and other ESX clothing scripts.
    exports.skinchanger:LoadClothes(skin, patch)
    if Wardrobe.hairFixed and hairOverride then setHair(hairOverride) end
    Wardrobe.lastSkin = snapshot(exports.skinchanger:GetSkin())
end

function Wardrobe.States()
    local skin = Wardrobe.Read()
    local states = {}
    for _, category in ipairs(Accessories.Catalog) do
        local active, available = false, false
        if skin and Wardrobe.IsSupported() then
            local off = Wardrobe.OffValues(category, skin)
            active = Wardrobe.removed[category.id] ~= nil
            available = validValues(category, off) and (active
                or (validValues(category, skin) and not matches(skin, off)))
        end
        states[category.id] = { active = active, available = available }
    end
    states['repairHair'] = { active = Wardrobe.hairFixed, available = skin ~= nil and Wardrobe.IsSupported() }
    return states
end

function Wardrobe.Toggle(id)
    local category = Accessories.ById[id]
    if not category then return false, 'unavailable' end
    local skin = Wardrobe.Read()
    if not skin or not Wardrobe.IsSupported() then return false, 'unsupported' end
    local off = Wardrobe.OffValues(category, skin)
    local cached = Wardrobe.removed[id]
    if not cached and matches(skin, off) then return false, 'unavailable' end
    local target = cached and cached.original or off
    if not validValues(category, target) or not validValues(category, off) then return false, 'unavailable' end
    local original = copyFields(skin, category.fields)
    local direction = cached and 'on' or 'off'
    playClothingAnimation(category, direction)
    apply(skin, target)
    if target == off then
        Wardrobe.removed[id] = { original = original, off = off }
    else
        Wardrobe.removed[id] = nil
    end
    return true
end

function Wardrobe.Restore()
    local skin = Wardrobe.Read()
    if not skin or not Wardrobe.IsSupported() then return false, 'unsupported' end
    local patch = {}
    for id, item in pairs(Wardrobe.removed) do
        if validValues(Accessories.ById[id], item.original) then
            for key, value in pairs(item.original) do patch[key] = value end
        end
    end
    if next(patch) then apply(skin, patch) end
    Wardrobe.removed = {}
    if Wardrobe.hairFixed and Wardrobe.savedHair then
        setHair(Wardrobe.savedHair)
        forceHairSkin(nil)
        Wardrobe.hairFixed = false
        Wardrobe.savedHair = nil
    end
    return true
end

function Wardrobe.RepairProps()
    local skin = Wardrobe.Read()
    if not skin then return false, 'unavailable' end
    for _, category in ipairs(Accessories.Catalog) do
        if category.prop and validValues(category, skin) then
            local drawable, texture = skin[category.fields[1]], skin[category.fields[2]]
            if drawable == -1 then ClearPedProp(PlayerPedId(), category.prop)
            else SetPedPropIndex(PlayerPedId(), category.prop, drawable, texture, true) end
        end
    end
    return true
end

function Wardrobe.RepairHair()
    local skin = Wardrobe.Read()
    if not skin or type(skin.hair_1) ~= 'number' or type(skin.hair_2) ~= 'number'
        or type(skin.hair_color_1) ~= 'number' or type(skin.hair_color_2) ~= 'number'
        or not IsPedComponentVariationValid(PlayerPedId(), 2, skin.hair_1, skin.hair_2) then
        return false, 'unavailable'
    end
    SetPedComponentVariation(PlayerPedId(), 2, skin.hair_1, skin.hair_2, 2)
    SetPedHairColor(PlayerPedId(), skin.hair_color_1, skin.hair_color_2)
    return true
end

function Wardrobe.ToggleFixHair()
    local ped = PlayerPedId()
    if not Wardrobe.IsSupported() then return false, 'unsupported' end
    local skin = Wardrobe.Read()
    if not skin then return false, 'unavailable' end

    local direction = Wardrobe.hairFixed and 'on' or 'off'
    playClothingAnimation({ id = 'repairHair' }, direction)

    if Wardrobe.hairFixed and Wardrobe.savedHair then
        setHair(Wardrobe.savedHair)
        forceHairSkin(nil)
        Wardrobe.hairFixed, Wardrobe.savedHair = false, nil
    else
        Wardrobe.savedHair = {
            hair_1 = (type(skin.hair_1) == 'number' and skin.hair_1) or GetPedDrawableVariation(ped, 2),
            hair_2 = (type(skin.hair_2) == 'number' and skin.hair_2) or GetPedTextureVariation(ped, 2),
            hair_color_1 = (type(skin.hair_color_1) == 'number' and skin.hair_color_1) or 0,
            hair_color_2 = (type(skin.hair_color_2) == 'number' and skin.hair_color_2) or 0
        }
        Wardrobe.hairFixed = true
        forceHairSkin({ hair_1 = 0, hair_2 = 0, hair_color_1 = 0, hair_color_2 = 0 })
    end
    return true
end

exports('InvalidateWardrobe', Wardrobe.Clear)

-- External outfits invalidate removal snapshots, including identical empty slots.
AddEventHandler('skinchanger:loadSkin', Wardrobe.Clear)
AddEventHandler('skinchanger:loadClothes', Wardrobe.Clear)
