---@type GhostConfig
Config = {
    Ghost = {
        enabled = true,
        spawnChance = 20,
        pedModel = 'u_m_y_zombie_01',
        maxDuration = 600000, -- 10 minutes in milliseconds
        exitKeybind = 'X',

        visibility = {
            range = 25.0, -- Distance in meters
            alpha = 77 -- ~30% opacity (0-255)
        },

        movement = {
            speedMultiplier = 1.5 -- 1.5x normal speed
        },

        abilities = {
            scare = {
                enabled = true,
                cooldown = 30000, -- 30 seconds in milliseconds
                range = 10.0, -- Distance in meters
                keybind = 'E',
                effects = {
                    screenShake = true,
                    sound = true,
                    soundVolume = 0.8,
                    duration = 3000 -- 3 seconds in milliseconds
                }
            }
        },

        -- Security & anti-abuse settings
        security = {
            ghostRequestCooldown = 60000, -- 60 seconds between ghost mode requests
            maxConcurrentGhosts = 10, -- Maximum number of ghosts at once
            deathCooldown = 2000, -- 2 seconds after death before showing ghost choice
            requestTimeout = 5000 -- 5 seconds timeout for ghost mode request response
        }
    },

    -- Trick-or-Treat event configuration (loaded via shared_scripts)
    TrickOrTreat = TrickOrTreatConfig or {},

    -- Admin permissions for /ghost command
    AdminGroups = {
        'admin',
        'superadmin'
    },

    -- Hospital respawn points (used when exiting ghost mode after death)
    RespawnPoints = {
        {coords = vector3(341.0, -1397.3, 32.5), heading = 48.5}, -- Central Los Santos
        {coords = vector3(1836.03, 3670.99, 34.28), heading = 296.06} -- Sandy Shores
    }
}
