ESX = nil

-- Properly load ESX with callback
CreateThread(function()
    while not ESX do
        ESX = exports['es_extended']:getSharedObject()
        if not ESX then
            Wait(500) 
        end
    end
end)

---@param source number
---@return boolean
local function HasAdminPermission(source)
    if not ESX then
        return false
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    for _, group in ipairs(Config.AdminGroups) do
        if xPlayer.getGroup() == group then
            return true
        end
    end

    return false
end

---@param source number
---@return boolean
local function IsPlayerValid(source)
    return GetPlayerEndpoint(source) ~= nil
end

RegisterCommand('ghost', function(source, args)
    if not HasAdminPermission(source) then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            args = {'System', 'No permission'}
        })
        return
    end

    local targetId = tonumber(args[1]) or source

    if not IsPlayerValid(targetId) then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            args = {'System', 'Player not found'}
        })
        return
    end

    TriggerClientEvent(Events.SHOW_GHOST_CHOICE, targetId, true)

    local adminName = GetPlayerName(source) or 'Console'
    local targetName = GetPlayerName(targetId) or 'Unknown'

    print(string.format('[ESX Halloween] %s triggered ghost choice for %s (ID: %d)', adminName, targetName, targetId))
end, false)
