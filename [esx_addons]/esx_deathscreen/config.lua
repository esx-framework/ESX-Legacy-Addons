Config = {}

Config.Locale = GetConvar('esx:locale', 'en')

-- Prevents desync on dead players by skipping ragdoll.
-- Players are revived instantly and play an animation instead.
-- Note: Natives like "IsPedFatallyInjured" will no longer work reliably.
-- Use Player(src).state.isDead for death checks.
Config.DeathAnim = {
    enabled = true,
    dict = "misslamar1dead_body",
    name = "dead_idle",
	fadeIn = 10.0,
	fadeOut = 10.0,
	flags = 1|2|8,
	playbackRate = 1.0
}

Config.AmbulanceJobEnabled = true

Config.zoom = {
	min = 1, 
	max = 6, 
	step = 0.5
}

Config.RemoveWeaponsAfterRPDeath  = true
Config.RemoveCashAfterRPDeath     = true
Config.RemoveItemsAfterRPDeath    = true

Config.EarlyRespawnTimer          = 60000 * 1  -- time til respawn is available
Config.BleedoutTimer              = 60000 * 10 -- time til the player bleeds out

-- Let the player pay for respawning early, only if he can afford it.
Config.EarlyRespawnFine           = false
Config.EarlyRespawnFineAmount     = 5000

Config.RespawnPoints = {
	{coords = vector3(341.0, -1397.3, 32.5), heading = 48.5}, -- Central Los Santos
	{coords = vector3(1836.03, 3670.99, 34.28), heading = 296.06} -- Sandy Shores
}

