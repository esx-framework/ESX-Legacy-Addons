-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

function TriggerMedalDeathClip()
    local cfg = Config.Medal
    if not cfg or not cfg.enabled or cfg.publicKey == '' then return end

    SendNUIMessage({
        action = 'medalClip',
        publicKey = cfg.publicKey,
        payload = {
            eventId = ('esx-death-%s-%s'):format(GetPlayerServerId(PlayerId()), GetGameTimer()),
            eventName = cfg.eventName or 'Death',
            triggerActions = { 'SaveClip' },
            clipOptions = cfg.clipOptions
        }
    })
end
