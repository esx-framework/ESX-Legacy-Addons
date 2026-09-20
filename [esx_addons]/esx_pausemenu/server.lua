-- SPDX-License-Identifier: GPL-3.0-only

local dataLimiter = xLib.rateLimiter({
    capacity = 2,
    refill = 1,
    interval = 750
})

local function stripFormatting(value)
    value = tostring(value or "")
    return value:gsub("%^%d", "")
end

local function getAccountMoney(xPlayer, accountName)
    local account = xPlayer.getAccount and xPlayer.getAccount(accountName)
    return account and tonumber(account.money) or 0
end

ESX.RegisterServerCallback("esx_pausemenu:getData", function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer then
        cb(nil)
        return
    end

    if not dataLimiter:consume(source) then
        cb(nil)
        return
    end

    local job = xPlayer.getJob and xPlayer.getJob() or xPlayer.job or {}
    local jobName = job.name or "unknown"
    local jobLabel = job.label or Config.Text.unknownJob

    if jobName == "unemployed" then
        jobLabel = Config.Text.unemployed
    end

    local playTime = 0
    if xPlayer.getPlayTime then
        playTime = tonumber(xPlayer.getPlayTime()) or 0
    end

    local projectName = GetConvar("sv_projectName", "")
    local serverName = projectName ~= "" and projectName or GetConvar("sv_hostname", Config.Brand.title)

    cb({
        id = source,
        name = stripFormatting(GetPlayerName(source) or xPlayer.name or (xPlayer.getName and xPlayer.getName()) or "Player"),
        role = jobLabel,
        bank = getAccountMoney(xPlayer, "bank"),
        cash = getAccountMoney(xPlayer, "money"),
        job = jobLabel,
        jobName = jobName,
        playTime = playTime,
        players = #GetPlayers(),
        maxPlayers = GetConvarInt("sv_maxclients", 48),
        serverName = stripFormatting(serverName)
    })
end)

RegisterNetEvent("esx_pausemenu:leaveServer", function()
    local src = source

    if src < 1 then
        return
    end

    DropPlayer(src, Config.Text.leaveReason)
end)
