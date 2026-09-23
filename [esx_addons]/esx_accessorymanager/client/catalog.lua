-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Accessories = {}

-- Clockwise from twelve o'clock, matching the supplied Figma design.
Accessories.Catalog = {
    { id = 'watches', fields = { 'watches_1', 'watches_2' }, prop = 6 },
    { id = 'glasses', fields = { 'glasses_1', 'glasses_2' }, prop = 1 },
    { id = 'mask', fields = { 'mask_1', 'mask_2' }, component = 1 },
    { id = 'chain', fields = { 'chain_1', 'chain_2' }, component = 7 },
    { id = 'ears', fields = { 'ears_1', 'ears_2' }, prop = 2 },
    { id = 'pants', fields = { 'pants_1', 'pants_2' }, component = 4, undressed = 'pants' },
    { id = 'shoes', fields = { 'shoes_1', 'shoes_2' }, component = 6, undressed = 'shoes' },
    { id = 'torso', fields = { 'torso_1', 'torso_2', 'arms', 'arms_2' }, component = 11, undressed = 'torso' },
    { id = 'helmet', fields = { 'helmet_1', 'helmet_2' }, prop = 0 },
    { id = 'bags', fields = { 'bags_1', 'bags_2' }, component = 5 },
    { id = 'tshirt', fields = { 'tshirt_1', 'tshirt_2' }, component = 8, undressed = 'tshirt' },
    { id = 'bracelets', fields = { 'bracelets_1', 'bracelets_2' }, prop = 7 },
    { id = 'bproof', fields = { 'bproof_1', 'bproof_2' }, component = 9 }
}

Accessories.ById = {}
for _, category in ipairs(Accessories.Catalog) do
    Accessories.ById[category.id] = category
end

function Accessories.Translate(key)
    local selected = Locales[Config.Locale] or Locales.en
    return selected['radial_' .. key] or Locales.en['radial_' .. key] or key
end

function Accessories.GetLabels()
    local labels = {}
    for key, value in pairs(Locales.en) do
        if key:sub(1, 7) == 'radial_' then
            labels[key:sub(8)] = (Locales[Config.Locale] or {})[key] or value
        end
    end
    return labels
end
