AddEventHandler("playerConnecting", function(name, _, deferrals)
    deferrals.defer()

    local src = source
    Wait(0)
    deferrals.update(Helpers.getTranslation("finalizing_connection"))

    local ok, ban = pcall(function()
        local identifier = Helpers.getPlayerLicenseIdentifier(src)
        return identifier and Helpers.isBanned(identifier) or nil
    end)

    if not ok then
        -- Fail-open: a ban-cache/DB hiccup must resolve the deferral, never hang the join.
        print(("[esx-adminmenu] Ban check failed for %s: %s"):format(tostring(GetPlayerName(src) or src), tostring(ban)))
        deferrals.done()
        return
    end

    if ban then
        local message = Helpers.getTranslation("default_ban")

        if ban.reason then
            message = message .. "\n" .. Helpers.getTranslation("reason") .. " " .. ban.reason
        end

        if ban.remaining_formatted then
            message = message .. "\n" .. Helpers.getTranslation("duration") .. " " .. ban.remaining_formatted
        end

        deferrals.done(message)
        return
    end

    deferrals.done()
end)

AddEventHandler("playerDropped", function()
	Helpers.addRecentPlayer(source)
end)
