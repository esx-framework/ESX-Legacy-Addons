Config = {}

-- Enables extra debug prints
Config.Debug = false

-- ESX permission groups allowed
Config.AllowedGroups = {
	admin = true,
}

Config.FeaturePermissions = {
	sensitiveInfo = {
		admin = true,
	},
	destructive = {
		admin = true,
	},
	troll = {
		admin = true,
	},
	selfTools = {
		admin = true,
	},
	playerVisibility = {
		admin = true,
	},
	vehicleTools = {
		admin = true,
	},
	vehicleSpawner = {
		admin = true,
	},
	vehiclePerformance = {
		admin = true,
	},
	infiniteAmmo = {
		admin = true,
	},
	helperCommands = {
		admin = true,
	},
	playerTeleport = {
		admin = true,
	},
	playerModeration = {
		admin = true,
	},
	spectate = {
		admin = true,
	},
	playerNotify = {
		admin = true,
	},
	banManagement = {
		admin = true,
	},
	money = {
		admin = true,
	},
	vehicleManagement = {
		admin = true,
	},
	vehicleDestructive = {
		admin = true,
	},
	serverManagement = {
		admin = true,
	},
	serverEnvironment = {
		admin = true,
	},
	serverPlayerModeration = {
		admin = true,
	},
	serverPlayerDestructive = {
		admin = true,
	},
	serverCleanup = {
		admin = true,
	},
	serverBroadcast = {
		admin = true,
	},
	serverEconomy = {
		admin = true,
	},
	radioLookup = {
		admin = true,
	},
	playerData = {
		admin = true,
	},
	acePermissions = {
		admin = true,
	},
	weapons = {
		admin = true,
	},
	routingBucket = {
		admin = true,
	},
	setModel = {
		admin = true,
	},
	openClothing = {
		admin = true,
	},
	vehicleOwnership = {
		admin = true,
	},
	-- Reading the admin action log is itself sensitive: it exposes who moderated
	-- whom. Gate it separately so it can be granted without full admin rights.
	logViewer = {
		admin = true,
	},
}

Config.Locale = "en"

Config.Keybinds = {
	AdminMenu = "F9",
	AdminDashboard = "F10",
}

Config.AdminMenu = {
	NoClipSpeed = 1.5,
	NamesDistance = 75.0,
	ModelLoadTimeout = 5000,
	ServerDataInterval = 60000,
	Blip = { sprite = 1, scale = 0.85, colour = 5 },
	Spectate = { height = 15.0, escCooldown = 5000, streamWait = 500 },
	Troll = { skyHeight = 120.0, randomRange = 500, randomHeight = 40.0, nauseaDuration = 5000 },
	WaypointScan = { max = 1000, step = 25 },
	ActionPermissions = {
		noclip = "selfTools",
		names = "playerVisibility",
		blips = "playerVisibility",
		godmode = "selfTools",
		invisible = "selfTools",
		infiniteAmmo = "infiniteAmmo",
		revive = "selfTools",
		heal = "selfTools",
		armor = "selfTools",
		waypoint = "selfTools",
		spawnVehicle = "vehicleSpawner",
		repairVehicle = "vehicleTools",
		cleanVehicle = "vehicleTools",
		flipVehicle = "vehicleTools",
		engineLevel = "vehiclePerformance",
		brakeLevel = "vehiclePerformance",
		transmissionLevel = "vehiclePerformance",
		suspensionLevel = "vehiclePerformance",
		armorLevel = "vehiclePerformance",
		turbo = "vehiclePerformance",
		xenon = "vehiclePerformance",
		neon = "vehiclePerformance",
		colorCycle = "vehiclePerformance",
		neonColorCycle = "vehiclePerformance",
		windowTint = "vehiclePerformance",
		wheelCategory = "vehiclePerformance",
		wheelDesign = "vehiclePerformance",
		bulletproofTires = "vehiclePerformance",
		customizeVehicle = "vehiclePerformance",
		maxPerformance = "vehiclePerformance",
		deleteVehicle = "vehicleDestructive",
		copyCoords = "helperCommands",
	},
}

Config.VehicleSpawner = {
	DefaultModel = "sultan",
	DeleteCurrentVehicleOnSpawn = true,
	WarpIntoVehicle = true,
	DefaultColor = "black",
	ColorPresets = {
		{ id = "black", label = "Black", primary = 0, secondary = 0 },
		{ id = "white", label = "White", primary = 111, secondary = 111 },
		{ id = "silver", label = "Silver", primary = 4, secondary = 4 },
		{ id = "red", label = "Red", primary = 27, secondary = 27 },
		{ id = "orange", label = "Orange", primary = 38, secondary = 38 },
		{ id = "yellow", label = "Yellow", primary = 88, secondary = 88 },
		{ id = "green", label = "Green", primary = 55, secondary = 55 },
		{ id = "blue", label = "Blue", primary = 64, secondary = 64 },
		{ id = "purple", label = "Purple", primary = 145, secondary = 145 },
	},
	NeonPresets = {
		{ id = "white", label = "White", r = 255, g = 255, b = 255 },
		{ id = "orange", label = "Orange", r = 251, g = 155, b = 4 },
		{ id = "red", label = "Red", r = 255, g = 32, b = 32 },
		{ id = "green", label = "Green", r = 32, g = 255, b = 96 },
		{ id = "blue", label = "Blue", r = 32, g = 128, b = 255 },
		{ id = "purple", label = "Purple", r = 180, g = 72, b = 255 },
	},
	WindowTints = {
		{ id = 0, label = "None" },
		{ id = 1, label = "Pure Black" },
		{ id = 2, label = "Dark Smoke" },
		{ id = 3, label = "Light Smoke" },
		{ id = 4, label = "Stock" },
		{ id = 5, label = "Limo" },
		{ id = 6, label = "Green" },
	},
	WheelCategories = {
		{ id = "sport", label = "Sport", type = 0 },
		{ id = "muscle", label = "Muscle", type = 1 },
		{ id = "lowrider", label = "Lowrider", type = 2 },
		{ id = "suv", label = "SUV", type = 3 },
		{ id = "offroad", label = "Offroad", type = 4 },
		{ id = "tuner", label = "Tuner", type = 5 },
		{ id = "bike", label = "Bike", type = 6 },
		{ id = "highend", label = "High End", type = 7 },
		{ id = "street", label = "Street", type = 11 },
		{ id = "track", label = "Track", type = 12 },
	},
	WheelDesigns = {
		{ id = -1, label = "Stock" },
		{ id = 0, label = "1" },
		{ id = 1, label = "2" },
		{ id = 2, label = "3" },
		{ id = 3, label = "4" },
		{ id = 4, label = "5" },
		{ id = 5, label = "6" },
		{ id = 6, label = "7" },
		{ id = 7, label = "8" },
		{ id = 8, label = "9" },
		{ id = 9, label = "10" },
		{ id = 10, label = "11" },
		{ id = 11, label = "12" },
		{ id = 12, label = "13" },
		{ id = 13, label = "14" },
		{ id = 14, label = "15" },
		{ id = 15, label = "16" },
		{ id = 16, label = "17" },
		{ id = 17, label = "18" },
		{ id = 18, label = "19" },
		{ id = 19, label = "20" },
	},
}

Config.ServerManagement = {
	DefaultKickReason = "Kicked by admin",
	DefaultWeather = "CLEAR",
	DefaultHour = 12,
	DefaultMinute = 0,
	DefaultBlackout = false,
	DefaultPvp = true,
	WeatherTypes = {
		CLEAR = true,
		EXTRASUNNY = true,
		CLOUDS = true,
		OVERCAST = true,
		RAIN = true,
		THUNDER = true,
		FOGGY = true,
		XMAS = true,
	},
	ActionPermissions = {
		weather = "serverEnvironment",
		time = "serverEnvironment",
		blackout = "serverEnvironment",
		pvp = "serverEnvironment",
		freezeAll = "serverPlayerModeration",
		unfreezeAll = "serverPlayerModeration",
		bringAll = "serverPlayerModeration",
		reviveAll = "serverPlayerModeration",
		kickAll = "serverPlayerDestructive",
		killAll = "serverPlayerDestructive",
		deleteVehicles = "serverCleanup",
		deletePeds = "serverCleanup",
		deleteObjects = "serverCleanup",
		notifyAll = "serverBroadcast",
		giveMoneyAll = "serverEconomy",
	},
}

Config.PlayerActions = {
	ActionPermissions = {
		giveMoney = "money",
		takeMoney = "money",
		setHealth = "playerModeration",
		setArmor = "playerModeration",
		cleanInventory = "destructive",
		killPlayer = "playerModeration",
		revivePlayer = "playerModeration",
		freezePlayer = "playerModeration",
		setModel = "setModel",
		openClothing = "openClothing",
		giveAllWeapons = "weapons",
		setRoutingBucket = "routingBucket",
		setRadio = "playerData",
		setJob = "playerData",
		setName = "playerData",
		setThirst = "playerData",
		setHunger = "playerData",
		aceAdd = "acePermissions",
		aceRemove = "acePermissions",
		troll = "troll",
		deleteCharacter = "destructive",
	},
}

Config.AdminLimits = {
	MaxReasonLength = 180,
	MaxNotificationLength = 240,
	MaxNotificationDuration = 30000,
	MaxBanDurationMinutes = 2628000, -- 5 years
	MaxMoneyAmount = 10000000,
	MaxRoutingBucket = 2147483647,
	MaxRadioChannel = 10000,
	MaxVehiclePropsBytes = 16384,
	OfflineSearchResults = 25,
	VehiclePageSize = 100,
	BanPageSize = 100,
	RecentPlayersCap = 100,
	PlateGenAttempts = 50,
	AllowedMoneyAccounts = {
		money = true,
		bank = true,
		black_money = true,
	},
	AllowedNotificationTypes = {
		info = true,
		success = true,
		error = true,
	},
}

Config.Ban = {
	-- Identifier types captured at ban time and matched on connect. A banned
	-- player is blocked if ANY connecting identifier matches ANY of these.
	-- ip is off by default (shared IPs / CGNAT cause false positives).
	Identifiers = {
		license = true,
		license2 = true,
		discord = true,
		steam = true,
		xbl = true,
		live = true,
		fivem = true,
		ip = false,
	},
}

Config.Plate = {
	Letters = 3,
	Numbers = 3,
	UseSpace = true,
}

Config.Clothing = {
	Events = {
		"esx_skin:openSaveableMenu",
	},
}

Config.Revive = {
	Events = {
		"esx_ambulancejob:revive",
	},
	UseNativeFallback = true,
	NativeFallbackDelay = 250,
}

Config.AdminWeapons = {
	{ name = "WEAPON_PISTOL", ammo = 250 },
	{ name = "WEAPON_COMBATPISTOL", ammo = 250 },
	{ name = "WEAPON_APPISTOL", ammo = 250 },
	{ name = "WEAPON_PUMPSHOTGUN", ammo = 120 },
	{ name = "WEAPON_CARBINERIFLE", ammo = 500 },
	{ name = "WEAPON_SMG", ammo = 500 },
	{ name = "WEAPON_SNIPERRIFLE", ammo = 80 },
	{ name = "WEAPON_STUNGUN", ammo = 1 },
	{ name = "WEAPON_NIGHTSTICK", ammo = 1 },
}

Config.TrollActions = {
	burn = true,
	explode = true,
	sky = true,
	randomTeleport = true,
	nausea = true,
}

-- Admin action log. Only actions are recorded, never reads: the menu polls
-- vehicle and player lists constantly and would otherwise drown the log.
Config.Logs = {
	Enabled = true,

	-- Rows older than this are deleted by the hourly maintenance pass.
	-- Set to 0 to keep everything (the table then grows without bound).
	RetentionDays = 30,

	-- Entries are queued in memory and written in batches, so an admin action
	-- never waits on the database.
	FlushInterval = 5000,
	-- Hard cap on the in-memory queue. If the database is unreachable the
	-- oldest entries are dropped rather than growing until the server dies.
	MaxQueue = 500,
	-- Rows per INSERT. Keeps the statement (and its lock) short.
	BatchSize = 100,

	-- Payloads above this are replaced by a truncation marker. Vehicle props
	-- alone can be several kilobytes.
	MaxPayloadBytes = 2048,

	-- Any client can invoke a server callback, so a non-admin can spam denied
	-- attempts. Beyond this many entries per minute a source is muted for the
	-- rest of the window, which keeps a flood from evicting real entries.
	MaxPerMinutePerActor = 120,

	-- Spammy toggles: recorded actions that carry no moderation value.
	Ignore = {
		noclip = true,
		godmode = true,
		invisible = true,
		names = true,
		blips = true,
		copyCoords = true,
	},

	Webhook = {
		-- Discord webhook URL. Leave empty to disable.
		-- WARNING: do not commit a real URL, anyone who reads it can post to
		-- your channel. Fill this in on your own server only.
		Url = "",

		-- Only these actions are forwarded. Sending everything gets the
		-- webhook rate-limited by Discord almost immediately.
		Actions = {
			ban = true,
			unban = true,
			kick = true,
			deleteCharacter = true,
			cleanInventory = true,
			giveMoney = true,
			takeMoney = true,
			giveMoneyAll = true,
			kickAll = true,
			killAll = true,
			aceAdd = true,
			aceRemove = true,
		},
	},
}
