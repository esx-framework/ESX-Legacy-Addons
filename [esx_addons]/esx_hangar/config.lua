Config = {}
Config.Locale = GetConvar('esx:locale', 'en')

Config.DrawDistance = 100.0

Config.Markers = {
	EntryPoint = {
		Type = 1,
		Size = {
			x = 40.0,
			y = 40.0,
			z = 0.0000001,
		},
		Color = {
			r = 50,
			g = 200,
			b = 50,
		},
	},
	GetOutPoint = {
		Type = 21,
		Size = {
			x = 1.0,
			y = 1.0,
			z = 0.5,
		},
		Color = {
			r = 200,
			g = 51,
			b = 51,
		},
	},
}

Config.Garages = {
	Hangar1 = {
		EntryPoint = { x = -1270.9701, y = -3380.1306, z = 14.5435 },
		SpawnPoint = { x = -1270.9701, y = -3380.1306, z = 14.5435, heading = 330.6931 },
		Sprite = 359,
		Scale = 0.8,
		Colour = 3,
		ImpoundedName = "Airport",
	},
	HangarFront = {
		EntryPoint = { x = -946.2409, y = -2994.6399, z = 14.5469 },
		SpawnPoint = { x = -946.2409, y = -2994.6399, z = 14.5469, heading = 240.4872 },
		Sprite = 359,
		Scale = 0.8,
		Colour = 3,
		ImpoundedName = "Airport",
	},
	HeliPad = {
		EntryPoint = { x = -1146.1862, y = -2864.5640, z = 13.9460 },
		SpawnPoint = { x = -1146.1862, y = -2864.5640, z = 13.9460, heading = 326.5148 },
		Sprite = 359,
		Scale = 0.8,
		Colour = 3,
		ImpoundedName = "Airport",
	},
	Back1 = {
		EntryPoint = { x = 1705.5520, y = 3251.1433, z = 40.9043 },
		SpawnPoint = { x = 1705.5520, y = 3251.1433, z = 40.9043, heading = 105.0484 },
		Sprite = 359,
		Scale = 0.8,
		Colour = 3,
		ImpoundedName = "Airport",
	},
	Grapeseed = {
		EntryPoint = { x = 2133.9246, y = 4783.2559, z = 40.9703,  },
		SpawnPoint = { x = 2133.9246, y = 4783.2559, z = 40.9703, heading = 26.4360 },
		Sprite = 359,
		Scale = 0.8,
		Colour = 3,
		ImpoundedName = "Airport",
	},
	
}

Config.Impounds = {
	Airport = {
		GetOutPoint = { x = -1559.1467, y = -3113.0271, z = 14.5469 },
		SpawnPoint = { x = -1559.1467, y = -3113.0271, z = 14.5469, heading = 242.6686 },
		Sprite = 524,
		Scale = 0.8,
		Colour = 1,
		Cost = 1000,
	},
}

exports("getGarages", function()
	return Config.Garages
end)

exports("getImpounds", function()
	return Config.Impounds
end)
