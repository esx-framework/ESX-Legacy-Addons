---Trick-or-Treat Configuration
---Defines all settings for the trick-or-treating event feature
---@class TrickOrTreatConfig
TrickOrTreatConfig = {
	---Enable/disable the trick-or-treat event feature
	enabled = true,

	---Frequency of trick-or-treat rounds in minutes
	roundFrequencyMinutes = 5,

	---Number of random houses selected per round
	doorsPerRound = 12,

	---Amount of candy collected per door per round
	candyPerDoor = 3,

	---Notification display settings
	notifications = {
		---Duration in ms to show round start notification
		roundStart = 10000,
		---Duration in ms to show house empty notification
		houseEmpty = 5000,
	},

	---Map blip/marker settings for active houses
	blips = {
		---Blip color for active houses (27 = orange)
		activeColor = 27,
		---Blip sprite for candy icon (280 = candy)
		sprite = 280,
		---Blip scale/size
		scale = 0.8,
	},

	---Reward probability distribution (chances must sum to 100)
	rewards = {
		---Common treat reward
		candy = {
			item = 'medikit',
			amount = 3,
			chance = 70, -- 70% chance
		},
		---Rare treat reward
		rareCandy = {
			item = 'diamond',
			amount = 1,
			chance = 15, -- 15% chance
		},
		---Trick/negative effect (no item, but effects)
		trick = {
			chance = 15, -- 15% chance
			effects = { 'jumpscare', 'small_damage' },
		},
	},

	---Player interaction settings
	interaction = {
		---Maximum distance to interact with house/NPC
		distance = 2.0,
		---Keybind for interaction (38 = E key)
		key = 38,
	},

	---House locations for trick-or-treating (xyz coordinates and heading)
	---These are real Los Santos residential locations from across the map
	houses = {
		-- Vinewood Hills (affluent area)
		{ coords = vec3(-174.35, 502.23, 137.42), heading = 45.0, pedModel = 'a_f_m_bevhills_01' },
		{ coords = vec3(-682.04, 592.09, 145.39), heading = 315.0, pedModel = 'a_m_m_business_01' },
		{ coords = vec3(-902.27, 694.09, 151.43), heading = 135.0, pedModel = 'a_f_m_business_02' },
		-- Rockford Hills (mansion area)
		{ coords = vec3(-1288.84, 439.82, 97.69), heading = 270.0, pedModel = 'a_m_y_business_01' },
		{ coords = vec3(-1405.81, 526.75, 123.83), heading = 90.0, pedModel = 'a_f_m_bevhills_02' },
		{ coords = vec3(-1578.23, 764.94, 189.57), heading = 0.0, pedModel = 'a_m_y_business_02' },
		-- West Vinewood (residential)
		{ coords = vec3(-1922.32, 166.09, 84.66), heading = 180.0, pedModel = 'a_f_y_business_01' },
		{ coords = vec3(-1965.46, 211.08, 86.80), heading = 45.0, pedModel = 'a_m_y_business_03' },
		-- Mirror Park (middle class)
		{ coords = vec3(1265.24, -647.03, 68.12), heading = 270.0, pedModel = 'a_f_m_eastsa_01' },
		{ coords = vec3(1010.47, -423.08, 65.35), heading = 135.0, pedModel = 'a_m_y_clubcust_01' },
		-- Del Perro Heights (beachside)
		{ coords = vec3(-1467.83, -538.98, 55.62), heading = 45.0, pedModel = 'a_f_y_business_02' },
		{ coords = vec3(-1529.51, -428.57, 35.60), heading = 315.0, pedModel = 'a_m_y_hipster_01' },
		-- Downtown (apartments)
		{ coords = vec3(-596.61, -282.36, 35.45), heading = 90.0, pedModel = 'a_f_y_hipster_01' },
		{ coords = vec3(-273.00, -957.37, 31.22), heading = 270.0, pedModel = 'a_m_y_hipster_02' },
		-- Grove Street (residential)
		{ coords = vec3(127.94, -1930.14, 21.38), heading = 180.0, pedModel = 'a_f_y_hipster_02' },
		{ coords = vec3(91.54, -1960.98, 20.75), heading = 0.0, pedModel = 'a_m_m_eastsa_01' },
		-- Sandy Shores (outer areas)
		{ coords = vec3(1661.15, 3819.82, 35.18), heading = 45.0, pedModel = 'a_f_y_hipster_03' },
		{ coords = vec3(1702.75, 4819.56, 42.06), heading = 315.0, pedModel = 'a_m_y_hipster_03' },
		-- Paleto Bay (rural)
		{ coords = vec3(-146.86, 6341.49, 31.49), heading = 135.0, pedModel = 'a_f_y_clubcust_02' },
		{ coords = vec3(-1291.01, -1439.87, 4.31), heading = 270.0, pedModel = 'a_m_y_clubcust_02' },
	},
}
