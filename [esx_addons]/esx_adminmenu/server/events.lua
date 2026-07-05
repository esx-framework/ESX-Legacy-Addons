AddEventHandler('playerConnecting', function(name, _, deferrals)
    deferrals.defer()

    local src = source
    deferrals.update('Checking your identifiers...')

    Wait(1000)
    local identifier = Helpers.getPlayerLicenseIdentifier(src)
    deferrals.update('Checking ban status...')
    Wait(3000)
    local ban = Helpers.isBanned(identifier)
    Wait(1000)
    if ban then
        local message = Helpers.getTranslation('default_ban')

        if ban.reason then
            message = message .. "\n" .. Helpers.getTranslation('reason').. " " .. ban.reason
        end

        if ban.remaining_formatted then
            message = message .. "\n" .. Helpers.getTranslation('duration') .. " " .. ban.remaining_formatted
        end

        deferrals.done(message)
        return
    end

    deferrals.update(Helpers.getTranslation('finalizing_connection'))
    Wait(100)

    deferrals.done()
end)

AddEventHandler("playerDropped", function()
	Helpers.addRecentPlayer(source)
end)
