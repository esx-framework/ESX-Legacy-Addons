---@param source number
---@return boolean
local function HasAdminPermission(source)
    local xPlayer = ESX.Player(source)
    if not xPlayer then return false end

    local playerGroup = xPlayer.getGroup()

    for i = 1, #Config.AdminGroups do
        if playerGroup == Config.AdminGroups[i] then
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
