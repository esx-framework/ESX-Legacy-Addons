-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

if not Config.Disable.Status then
    local values = { foodBar = 100, drinkBar = 100 }
    local function percent(value)
        return math.max(0, math.min(100, math.floor(value)))
    end

    AddEventHandler("esx_status:onTick", function(data)
        for i = 1, #data do
            if data[i].name == "thirst" then
                values.drinkBar = percent(data[i].percent)
            elseif data[i].name == "hunger" then
                values.foodBar = percent(data[i].percent)
            end
        end
    end)

    function HUD:StatusThread()
        if self.statusThreadRunning then return end
        self.statusThreadRunning = true
        CreateThread(function()
            while ESX.PlayerLoaded do
                local ped = ESX.PlayerData.ped
                local maxHealth = math.max(1, GetEntityMaxHealth(ped) - 100)
                values.healthBar = percent((GetEntityHealth(ped) - 100) / maxHealth * 100)
                values.armorBar = percent(GetPedArmour(ped))
                values.staminaBar = percent(GetPlayerSprintStaminaRemaining(ESX.playerId))
                values.underwater = IsPedSwimmingUnderWater(ped)
                values.oxygenBar = values.underwater and percent(GetPlayerUnderwaterTimeRemaining(ESX.playerId) * 10) or 100
                xLib.nui.send({ type = "STATUS_HUD", value = values })
                Wait(250)
            end
            self.statusThreadRunning = false
        end)
    end
end
