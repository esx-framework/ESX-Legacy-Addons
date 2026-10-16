--- Validates all config values on resource start
--- Prints warnings for invalid values and applies safe defaults
---@return boolean True if config is valid (with corrections), false if critically broken
local function ValidateConfig()
    local isValid = true

    -- Validate Ghost.enabled
    if type(Config.Ghost.enabled) ~= 'boolean' then
        print('^3[ESX Halloween] Config warning: Ghost.enabled must be boolean, defaulting to true^7')
        Config.Ghost.enabled = true
    end

    -- Validate Ghost.spawnChance
    if type(Config.Ghost.spawnChance) ~= 'number' or Config.Ghost.spawnChance < 0 or Config.Ghost.spawnChance > 100 then
        print('^3[ESX Halloween] Config warning: Ghost.spawnChance must be 0-100, defaulting to 20^7')
        Config.Ghost.spawnChance = 20
    end

    -- Validate Ghost.maxDuration
    if type(Config.Ghost.maxDuration) ~= 'number' or Config.Ghost.maxDuration < 1000 then
        print('^3[ESX Halloween] Config warning: Ghost.maxDuration must be >= 1000ms, defaulting to 600000^7')
        Config.Ghost.maxDuration = 600000
    end

    -- Validate Ghost.visibility.range
    if type(Config.Ghost.visibility.range) ~= 'number' or Config.Ghost.visibility.range <= 0 then
        print('^3[ESX Halloween] Config warning: Ghost.visibility.range must be > 0, defaulting to 25.0^7')
        Config.Ghost.visibility.range = 25.0
    end

    -- Validate Ghost.visibility.alpha
    if type(Config.Ghost.visibility.alpha) ~= 'number' or Config.Ghost.visibility.alpha < 0 or Config.Ghost.visibility.alpha > 255 then
        print('^3[ESX Halloween] Config warning: Ghost.visibility.alpha must be 0-255, defaulting to 77^7')
        Config.Ghost.visibility.alpha = 77
    end

    -- Validate Ghost.movement.speedMultiplier
    if type(Config.Ghost.movement.speedMultiplier) ~= 'number' or Config.Ghost.movement.speedMultiplier < 0.1 or Config.Ghost.movement.speedMultiplier > 5.0 then
        print('^3[ESX Halloween] Config warning: Ghost.movement.speedMultiplier must be 0.1-5.0, defaulting to 1.5^7')
        Config.Ghost.movement.speedMultiplier = 1.5
    end

    -- Validate Ghost.abilities.scare.cooldown
    if type(Config.Ghost.abilities.scare.cooldown) ~= 'number' or Config.Ghost.abilities.scare.cooldown < 1000 then
        print('^3[ESX Halloween] Config warning: Ghost.abilities.scare.cooldown must be >= 1000ms, defaulting to 30000^7')
        Config.Ghost.abilities.scare.cooldown = 30000
    end

    -- Validate Ghost.abilities.scare.range
    if type(Config.Ghost.abilities.scare.range) ~= 'number' or Config.Ghost.abilities.scare.range <= 0 then
        print('^3[ESX Halloween] Config warning: Ghost.abilities.scare.range must be > 0, defaulting to 10.0^7')
        Config.Ghost.abilities.scare.range = 10.0
    end

    -- Validate Ghost.security.ghostRequestCooldown
    if type(Config.Ghost.security.ghostRequestCooldown) ~= 'number' or Config.Ghost.security.ghostRequestCooldown < 0 then
        print('^3[ESX Halloween] Config warning: Ghost.security.ghostRequestCooldown must be >= 0, defaulting to 60000^7')
        Config.Ghost.security.ghostRequestCooldown = 60000
    end

    -- Validate Ghost.security.maxConcurrentGhosts
    if type(Config.Ghost.security.maxConcurrentGhosts) ~= 'number' or Config.Ghost.security.maxConcurrentGhosts < 1 then
        print('^3[ESX Halloween] Config warning: Ghost.security.maxConcurrentGhosts must be >= 1, defaulting to 10^7')
        Config.Ghost.security.maxConcurrentGhosts = 10
    end

    -- Validate Ghost.security.deathCooldown
    if type(Config.Ghost.security.deathCooldown) ~= 'number' or Config.Ghost.security.deathCooldown < 0 then
        print('^3[ESX Halloween] Config warning: Ghost.security.deathCooldown must be >= 0, defaulting to 2000^7')
        Config.Ghost.security.deathCooldown = 2000
    end

    -- Validate Ghost.security.requestTimeout
    if type(Config.Ghost.security.requestTimeout) ~= 'number' or Config.Ghost.security.requestTimeout < 1000 then
        print('^3[ESX Halloween] Config warning: Ghost.security.requestTimeout must be >= 1000ms, defaulting to 5000^7')
        Config.Ghost.security.requestTimeout = 5000
    end

    -- Validate TrickOrTreat.enabled
    if type(Config.TrickOrTreat.enabled) ~= 'boolean' then
        print('^3[ESX Halloween] Config warning: TrickOrTreat.enabled must be boolean, defaulting to true^7')
        Config.TrickOrTreat.enabled = true
    end

    -- Validate TrickOrTreat.roundFrequencyMinutes
    if type(Config.TrickOrTreat.roundFrequencyMinutes) ~= 'number' or Config.TrickOrTreat.roundFrequencyMinutes < 1 then
        print('^3[ESX Halloween] Config warning: TrickOrTreat.roundFrequencyMinutes must be >= 1, defaulting to 5^7')
        Config.TrickOrTreat.roundFrequencyMinutes = 5
    end

    -- Validate TrickOrTreat.doorsPerRound
    if type(Config.TrickOrTreat.doorsPerRound) ~= 'number' or Config.TrickOrTreat.doorsPerRound < 1 then
        print('^3[ESX Halloween] Config warning: TrickOrTreat.doorsPerRound must be >= 1, defaulting to 12^7')
        Config.TrickOrTreat.doorsPerRound = 12
    end

    -- Validate TrickOrTreat.candyPerDoor
    if type(Config.TrickOrTreat.candyPerDoor) ~= 'number' or Config.TrickOrTreat.candyPerDoor < 1 then
        print('^3[ESX Halloween] Config warning: TrickOrTreat.candyPerDoor must be >= 1, defaulting to 3^7')
        Config.TrickOrTreat.candyPerDoor = 3
    end

    -- Validate TrickOrTreat.houses table exists
    if type(Config.TrickOrTreat.houses) ~= 'table' or #Config.TrickOrTreat.houses == 0 then
        print('^3[ESX Halloween] Config warning: TrickOrTreat.houses must be non-empty table, skipping feature^7')
        Config.TrickOrTreat.enabled = false
    end

    -- Validate reward chances sum to 100
    local rewardTotal = (Config.TrickOrTreat.rewards.candy.chance or 0) +
                       (Config.TrickOrTreat.rewards.rareCandy.chance or 0) +
                       (Config.TrickOrTreat.rewards.trick.chance or 0)
    if rewardTotal ~= 100 then
        print('^3[ESX Halloween] Config warning: TrickOrTreat reward chances must sum to 100 (currently ' .. rewardTotal .. ')^7')
    end

    print('^2[ESX Halloween] Config validation completed - All values are valid^7')
    return isValid
end

-- Run validation on resource start
CreateThread(function()
    ValidateConfig()
end)
