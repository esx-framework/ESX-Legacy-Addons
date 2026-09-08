function TriggerMedalDeathClip()
    local cfg = Config.Medal
    if not cfg or not cfg.enabled or cfg.publicKey == '' then return end

    xLib.nui.send({
        action = 'medalClip',
        publicKey = cfg.publicKey,
        payload = {
            eventId = ('esx-ambulance-death-%s-%s'):format(GetPlayerServerId(PlayerId()), GetGameTimer()),
            eventName = cfg.eventName or 'Death',
            triggerActions = { 'SaveClip' },
            clipOptions = cfg.clipOptions
        }
    })
end
