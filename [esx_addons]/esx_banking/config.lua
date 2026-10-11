-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Config = {
	Debug = false,
	DrawMarker = 10,
	Locale = GetConvar('esx:locale', 'en'),
	EnablePeds = true,
	ShowMarker = false,
	InteractionDistance = 1.5,
	AtmInteractionDistance = 2.0,
	ClientAtmFallback = false,
	ClientAtmFallbackDistance = 1.75,
	RequireAtmPin = true,
	SessionDuration = 90,
	TransactionCooldown = 1250,
	PinAttemptCooldown = 1500,
	MaxTransactionAmount = 100000000,
	HistoryLimit = 20,
	HistoryDays = 30,
	LogRetentionDays = 60,
	LogValueMaxLength = 80,
	AtmModels = {`prop_fleeca_atm`, `prop_atm_01`, `prop_atm_02`, `prop_atm_03`},
	AtmLocations = {
		vector3(-386.733, 6045.953, 31.501),
		vector3(-284.037, 6224.385, 31.187),
		vector3(-135.165, 6365.738, 31.101),
		vector3(-110.753, 6467.703, 31.784),
		vector3(-94.969, 6455.301, 31.784),
		vector3(155.430, 6641.991, 31.784),
		vector3(174.672, 6637.218, 31.784),
		vector3(1703.138, 6426.783, 32.730),
		vector3(1735.114, 6411.035, 35.164),
		vector3(1702.842, 4933.593, 42.051),
		vector3(1967.333, 3744.293, 32.272),
		vector3(1821.917, 3683.483, 34.244),
		vector3(1174.532, 2705.278, 38.027),
		vector3(540.042, 2671.007, 42.177),
		vector3(2564.399, 2585.100, 38.016),
		vector3(2558.683, 349.601, 108.050),
		vector3(2558.051, 389.481, 108.660),
		vector3(1077.692, -775.796, 58.218),
		vector3(1139.018, -469.886, 66.789),
		vector3(1168.975, -457.241, 66.641),
		vector3(1153.884, -326.540, 69.245),
		vector3(381.282, 323.251, 103.270),
		vector3(236.463, 217.471, 106.840),
		vector3(265.004, 212.171, 106.780),
		vector3(285.202, 143.569, 104.970),
		vector3(157.769, 233.545, 106.450),
		vector3(-164.568, 233.506, 94.919),
		vector3(-1827.040, 785.515, 138.020),
		vector3(-1409.390, -99.260, 52.473),
		vector3(-1205.350, -325.579, 37.870),
		vector3(-1215.640, -332.231, 37.881),
		vector3(-2072.410, -316.959, 13.345),
		vector3(-2975.720, 379.773, 14.992),
		vector3(-2962.600, 482.191, 15.762),
		vector3(-2955.700, 488.721, 15.486),
		vector3(-3044.220, 595.242, 7.595),
		vector3(-3144.130, 1127.415, 20.868),
		vector3(-3241.100, 996.688, 12.500),
		vector3(-3241.110, 1009.152, 12.877),
		vector3(-1305.400, -706.240, 25.352),
		vector3(-538.225, -854.423, 29.234),
		vector3(-711.156, -818.958, 23.768),
		vector3(-717.614, -915.880, 19.268),
		vector3(-526.566, -1222.900, 18.434),
		vector3(-256.831, -719.646, 33.444),
		vector3(-203.548, -861.588, 30.205),
		vector3(112.410, -776.162, 31.427),
		vector3(112.929, -818.710, 31.386),
		vector3(119.900, -883.826, 31.191),
		vector3(-846.304, -340.402, 38.687),
		vector3(-56.193, -1752.530, 29.452),
		vector3(-261.692, -2012.640, 30.121),
		vector3(-273.001, -2025.600, 30.197),
		vector3(314.187, -278.621, 54.170),
		vector3(-351.534, -49.529, 49.042),
		vector3(24.589, -946.056, 29.357),
		vector3(-254.112, -692.483, 33.616),
		vector3(-1570.197, -546.651, 34.955),
		vector3(-1415.909, -211.825, 46.500),
		vector3(-1430.112, -211.014, 46.500),
		vector3(33.232, -1347.849, 29.497),
		vector3(129.216, -1292.347, 29.269),
		vector3(287.645, -1282.646, 29.659),
		vector3(289.012, -1256.545, 29.440),
		vector3(295.839, -895.640, 29.217),
		vector3(1686.753, 4815.809, 42.008),
		vector3(-302.408, -829.945, 32.417),
		vector3(5.134, -919.949, 29.557),
		vector3(147.67, -1035.72, 29.33),
		vector3(145.98, -1035.20, 29.33)

	},
	Banks = {
		{
			Position = vector4(149.91, -1040.74, 29.374, 160),
			Blip = {
				Enabled = true,
				Color = 69,
				Label = 'Bank',
				Sprite = 108,
				Scale = 0.7
			}
		},
		{
			Position = vector4(-1212.63, -330.78, 37.59, 210),
			Blip = {
				Enabled = true,
				Color = 69,
				Label = 'Bank',
				Sprite = 108,
				Scale = 0.7
			}
		},
		{
			Position = vector4(-2962.47, 482.93, 15.5, 270),
			Blip = {
				Enabled = true,
				Color = 69,
				Label = 'Bank',
				Sprite = 108,
				Scale = 0.7
			}
		},
		{
			Position = vector4(-113.01, 6470.24, 31.43, 315),
			Blip = {
				Enabled = true,
				Color = 69,
				Label = 'Bank',
				Sprite = 108,
				Scale = 0.7
			}
		},
		{
			Position = vector4(314.16, -279.09, 53.97, 160),
			Blip = {
				Enabled = true,
				Color = 69,
				Label = 'Bank',
				Sprite = 108,
				Scale = 0.7
			}
		},
		{
			Position = vector4(-350.99, -49.99, 48.84, 160),
			Blip = {
				Enabled = true,
				Color = 69,
				Label = 'Bank',
				Sprite = 108,
				Scale = 0.7
			}
		},
		{
			Position = vector4(1175.02, 2706.87, 37.89, 0),
			Blip = {
				Enabled = true,
				Color = 69,
				Label = 'Bank',
				Sprite = 108,
				Scale = 0.7
			}
		},
		{
			Position = vector4(246.63, 223.62, 106.0, 160),
			Blip = {
				Enabled = true,
				Color = 69,
				Label = 'Bank',
				Sprite = 108,
				Scale = 0.7
			}
		},
	},
	Peds = {
		{
			Position = vector4(149.5513, -1042.1570, 29.3680, 341.6520),
			Model = `U_M_M_BankMan`,
			Scenario = 'WORLD_HUMAN_CLIPBOARD'
		},
		{
			Position = vector4(-1211.8585, -331.9854, 37.7809, 28.5983),
			Model = `U_M_M_BankMan`,
			Scenario = 'WORLD_HUMAN_CLIPBOARD'
		},
		{
			Position = vector4(-2961.0720, 483.1107, 15.6970, 88.1986),
			Model = `U_M_M_BankMan`,
			Scenario = 'WORLD_HUMAN_CLIPBOARD'
		},
		{
			Position = vector4(-112.2223, 6471.1128, 31.6267, 132.7517),
			Model = `U_M_M_BankMan`,
			Scenario = 'WORLD_HUMAN_CLIPBOARD'
		},
		{
			Position = vector4(313.8176, -280.5338, 54.1647, 339.1609),
			Model = `U_M_M_BankMan`,
			Scenario = 'WORLD_HUMAN_CLIPBOARD'
		},
		{
			Position = vector4(-351.3247, -51.3466, 49.0365, 339.3305),
			Model = `U_M_M_BankMan`,
			Scenario = 'WORLD_HUMAN_CLIPBOARD'
		},
		{
			Position = vector4(1174.9718, 2708.2034, 38.0879, 178.2974),
			Model = `U_M_M_BankMan`,
			Scenario = 'WORLD_HUMAN_CLIPBOARD'
		},
		{
			Position = vector4(247.0348, 225.1851, 106.2875, 158.7528),
			Model = `U_M_M_BankMan`,
			Scenario = 'WORLD_HUMAN_CLIPBOARD'
		}
	}
}
