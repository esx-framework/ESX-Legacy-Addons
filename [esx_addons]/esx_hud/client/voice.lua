-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

if not Config.Disable.Voice then
    HUD.Data.TalkingOnRadio = false
    if GetResourceState("pma-voice") == "started" then
        AddEventHandler("pma-voice:setTalkingMode", function(mode)
            xLib.nui.send({ type = "VOICE_RANGE", value = mode })
            HUD.Data.VoiceRange = mode
        end)

        AddEventHandler("pma-voice:radioActive", function(radioTalking)
            HUD.Data.isTalkingOnRadio = radioTalking
        end)

        AddEventHandler("onResourceStart", function(resourceName)
            if resourceName ~= "pma-voice" then
                return
            end
            Wait(1000)
            local proximity = LocalPlayer.state.proximity
            HUD.Data.VoiceRange = proximity and proximity.index or 2
            xLib.nui.send({ type = "VOICE_RANGE", value = HUD.Data.VoiceRange })
        end)
    elseif GetResourceState("saltychat") == "started" then
        -- #TODO: Test salty chat, add restart handlers
        AddEventHandler("SaltyChat_VoiceRangeChanged", function(range, index, availableVoiceRanges)
            xLib.nui.send({ type = "VOICE_RANGE", value = index })
            HUD.Data.VoiceRange = index
        end)

        AddEventHandler("SaltyChat_RadioTrafficStateChanged", function(primaryReceive, primaryTransmit, secondaryReceive, secondaryTransmit)
            HUD.Data.isTalkingOnRadio = primaryTransmit or secondaryTransmit
        end)
    else
        TriggerServerEvent("esx_hud:ErrorHandle", "Setup your custom voice resource at: client/voice.lua")
    end
end
