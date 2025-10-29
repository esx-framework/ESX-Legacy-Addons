Config = {}
Config.Locale = GetConvar('esx:locale', 'en')

---@type Garage[]
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

		-- impoundedName = 'LosSantos',
	},
}

---@enum GarageState
Config.GarageState = {
	NOT_STORED = 0,
	STORED = 1,
	IMPOUNDED = 2,
}

Config.ImpoundFee = 400

-- Config.Impounds = {
-- 	LosSantos = {
-- 		GetOutPoint = {
-- 			x = 400.7,
-- 			y = -1630.5,
-- 			z = 29.3,
-- 		},
-- 		SpawnPoint = {
-- 			x = 401.9,
-- 			y = -1647.4,
-- 			z = 29.2,
-- 			heading = 323.3,
-- 		},
-- 		Sprite = 524,
-- 		Scale = 0.8,
-- 		Colour = 1,
-- 		Cost = 3000,
-- 	},
-- 	PaletoBay = {
-- 		GetOutPoint = {
-- 			x = -211.4,
-- 			y = 6206.5,
-- 			z = 31.4,
-- 		},
-- 		SpawnPoint = {
-- 			x = -204.6,
-- 			y = 6221.6,
-- 			z = 30.5,
-- 			heading = 227.2,
-- 		},
-- 		Sprite = 524,
-- 		Scale = 0.8,
-- 		Colour = 1,
-- 		Cost = 3000,
-- 	},
-- 	SandyShores = {
-- 		GetOutPoint = {
-- 			x = 1728.2,
-- 			y = 3709.3,
-- 			z = 33.2,
-- 		},
-- 		SpawnPoint = {
-- 			x = 1722.7,
-- 			y = 3713.6,
-- 			z = 33.2,
-- 			heading = 19.9,
-- 		},
-- 		Sprite = 524,
-- 		Scale = 0.8,
-- 		Colour = 1,
-- 		Cost = 3000,
-- 	},
-- }

exports('getGarages', function()
	return Config.Garages
end)

-- exports('getImpounds', function()
-- 	return Config.Impounds
-- end)
