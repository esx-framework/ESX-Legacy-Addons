if not Config.Disable.Status then
    local GetPlayerUnderwaterTimeRemaining = GetPlayerUnderwaterTimeRemaining
    local GetPlayerSprintStaminaRemaining = GetPlayerSprintStaminaRemaining
    local IsPedSwimmingUnderWater = IsPedSwimmingUnderWater
    local GetEntityHealth = GetEntityHealth
    local GetEntityMaxHealth = GetEntityMaxHealth
    local GetPedArmour = GetPedArmour
    local values = {}

    AddEventHandler("esx_status:onTick", function(data)
        local hunger, thirst
        for i = 1, #data do
            if data[i].name == "thirst" then
                thirst = math.floor(data[i].percent)
            end
            if data[i].name == "hunger" then
                hunger = math.floor(data[i].percent)
            end
        end

        values.healthBar = math.floor((GetEntityHealth(ESX.PlayerData.ped) - 100) / 100 * 100)
        values.armorBar = GetPedArmour(ESX.PlayerData.ped)
        values.drinkBar = thirst
        values.foodBar = hunger
    end)

    function HUD:StatusThread()
        values = {}
        CreateThread(function()
            while ESX.PlayerLoaded do
                local oxygen, stamina = 0, 0

                stamina = math.floor(100 - GetPlayerSprintStaminaRemaining(ESX.playerId))
                if stamina == 0 then
                    stamina = 1
                end
                if stamina == 100 then
                    stamina = 0
                end

                if IsPedSwimmingUnderWater(ESX.PlayerData.ped) then
                    oxygen = math.floor(GetPlayerUnderwaterTimeRemaining(ESX.playerId) * 10)
                end

                values.oxygenBar = oxygen or 0
                values.staminaBar = stamina
                SendNUIMessage({ type = "STATUS_HUD", value = values })
                Wait(250)
            end
        end)
    end
end
