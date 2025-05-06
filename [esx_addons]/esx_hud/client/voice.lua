if not Config.Disable.Voice then
    HUD.Data.TalkingOnRadio = false
    if GetResourceState("pma-voice") == "started" then
        AddEventHandler("pma-voice:setTalkingMode", function(mode)
            SendNUIMessage({ type = "VOICE_RANGE", value = mode })
            HUD.Data.VoiceRange = mode
        end)

        AddEventHandler("pma-voice:radioActive", function(radioTalking)
            HUD.Data.isTalkingOnRadio = radioTalking
        end)

        AddEventHandler("onResourceStart", function(resourceName)
            if not resourceName == "pma-voice" then
                return
            end
            Wait(1000)
            SendNUIMessage({ type = "VOICE_RANGE", value = LocalPlayer.state.proximity.index })
        end)
    elseif GetResourceState("saltychat") == "started" then
        -- #TODO: Test salty chat, add restart handlers
        AddEventHandler("SaltyChat_VoiceRangeChanged", function(range, index, availableVoiceRanges)
            SendNUIMessage({ type = "VOICE_RANGE", value = index })
            HUD.Data.VoiceRange = index
        end)

        AddEventHandler("SaltyChat_RadioTrafficStateChanged", function(primaryReceive, primaryTransmit, secondaryReceive, secondaryTransmit)
            HUD.Data.isTalkingOnRadio = primaryTransmit or secondaryTransmit
        end)
    else
        TriggerServerEvent("esx_hud:ErrorHandle", "Setup your custom voice resource at: client/voice.lua")
    end
end
