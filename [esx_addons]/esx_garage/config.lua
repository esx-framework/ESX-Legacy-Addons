Config = {}
Config.Locale = GetConvar('esx:locale', 'en')

---@type GarageConfig[]
Config.Garages = {
	{
		id = 'vespucci_boulevard',
		label = 'Vespucci Boulevard',
		entryPoint = vec3(-285.2, -886.5, 31.0),
		spawnPoint = vec4(-309.3, -897.0, 31.0, 351.8),
		blip = {
			sprite = 357,
			scale = 0.8,
			color = 3,
		},
		ped = {
			coords = vec4(-282.8655, -888.8463, 31.0806, 72.7597),
			model = `s_m_m_gentransport`
		},
	},
}

---@enum GarageState
Config.GarageState = {
	NOT_STORED = 0,
	STORED = 1,
	IMPOUNDED = 2,
}

Config.ImpoundFee = 400
Config.FindVehicleFee = 300
