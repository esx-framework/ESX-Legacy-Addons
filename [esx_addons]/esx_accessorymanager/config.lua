-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 ESX Framework

Config = {}
Config.Locale = GetConvar('esx:locale', 'en')
Config.EnableControls = true

Config.Radial = {
    Command = 'accessories',
    DefaultKey = 'F11',
    ActionCooldown = 350,
    AllowInVehicle = false,
    -- Freemode underwear values. Adjust for custom clothing packs.
    Undressed = {
        male = { tshirt = 15, torso = 15, arms = 15, pants = 61, shoes = 34 },
        female = { tshirt = 15, torso = 15, arms = 15, pants = 15, shoes = 35 }
    },
    Animation = {
        Enabled = true,
        Timeout = 500,
        Duration = 900,
        Flag = 49,
        Default = { dict = 'clothingshirt', anim = 'try_shirt_positive_d' },
        ByCategory = {
            watches = { dict = 'nmt_3_rcm-10', anim = 'cs_nigel_dual-10', flag = 51, duration = 1200 },
            glasses = { dict = 'clothingspecs', anim = 'take_off', flag = 51, duration = 1400 },
            mask = { dict = 'mp_masks@standard_car@ds@', anim = 'put_on_mask', flag = 51, duration = 800 },
            chain = { dict = 'clothingtie', anim = 'try_tie_positive_a', flag = 51, duration = 2100 },
            ears = { dict = 'mp_cp_stolen_tut', anim = 'b_think', flag = 51, duration = 900 },
            pants = { dict = 're@construction', anim = 'out_of_breath', flag = 51, duration = 1300 },
            shoes = { dict = 'random@domestic', anim = 'pickup_low', flag = 0, duration = 1200 },
            torso = { dict = 'missmic4', anim = 'michael_tux_fidget', flag = 51, duration = 1500 },
            helmet = {
                on = { dict = 'mp_masks@standard_car@ds@', anim = 'put_on_mask', flag = 51, duration = 600 },
                off = { dict = 'missheist_agency2ahelmet', anim = 'take_off_helmet_stand', flag = 51, duration = 1200 }
            },
            bags = { dict = 'anim@heists@ornate_bank@grab_cash', anim = 'intro', flag = 51, duration = 1600 },
            bracelets = { dict = 'nmt_3_rcm-10', anim = 'cs_nigel_dual-10', flag = 51, duration = 1200 },
            bproof = { dict = 'clothingtie', anim = 'try_tie_negative_a', flag = 51, duration = 1200 },
            repairHair = { dict = 'clothingtie', anim = 'check_out_a', flag = 51, duration = 2000 }
        }
    }
}
