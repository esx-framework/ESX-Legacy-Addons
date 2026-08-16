---@type table<string, ShopZone>
Config.Zones = Config.Zones or {}

-- ════════════════════════════════════════════════════════════════
-- SHOP DEFINITIONS
-- ════════════════════════════════════════════════════════════════

-- Categories with FontAwesome icons (Find more at: https://fontawesome.com/icons)
-- Icon format: "fa-solid fa-icon-name" or "fa-regular fa-icon-name"

Config.Zones.TwentyFourSeven = {
	Items = {
		{name = "burger", label = "Burger", price = 15, category = "food"},
		{name = "water", label = "Water", price = 10, category = "drinks"},
		{name = "pizza_ham", label = "Pizza Ham", price = 25, category = "food"},
		{name = "sprunk", label = "Sprunk", price = 12, category = "drinks"},
		{name = "phone", label = "Phone", price = 250, category = "electronics"},
		{name = "lockpick", label = "Lockpick", price = 150, category = "tools"}
	},
	Categories = {
		{id = "food", label = "Food", icon = "fa-solid fa-burger"},
		{id = "drinks", label = "Drinks", icon = "fa-solid fa-bottle-water"},
		{id = "electronics", label = "Electronics", icon = "fa-solid fa-mobile"},
		{id = "tools", label = "Tools", icon = "fa-solid fa-wrench"}
	},
	Pos = {
		vector3(373.8, 325.8, 103.5),
		vector3(2557.4, 382.2, 108.6),
		vector3(-3038.9, 585.9, 7.9),
		vector3(-3241.9, 1001.4, 12.8),
		vector3(547.4, 2671.7, 42.1),
		vector3(1961.4, 3740.6, 32.3),
		vector3(2678.9, 3280.6, 55.2),
		vector3(1729.2, 6414.1, 35.0)
	},
	Size = 0.8,
	Type = 59,
	Color = 25,
	ShowBlip = true,
	ShowMarker = true
}

Config.Zones.RobsLiquor = {
	Items = {
		{name = "burger", label = "Burger", price = 15, category = "food"},
		{name = "water", label = "Water", price = 10, category = "drinks"},
		{name = "meth", label = "Meth", price = 18, category = "alcohol"},
		{name = "wine", label = "Wine", price = 35, category = "alcohol"},
		{name = "beer", label = "Beer", price = 50, category = "alcohol"},
		{name = "blackberry_ale", label = "Blackberry Ale", price = 65, category = "alcohol"}
	},
	Categories = {
		{id = "food", label = "Food", icon = "fa-solid fa-burger"},
		{id = "drinks", label = "Drinks", icon = "fa-solid fa-bottle-water"},
		{id = "alcohol", label = "Alcohol", icon = "fa-solid fa-champagne-glasses"}
	},
	Pos = {
		vector3(1135.8, -982.2, 46.4),
		vector3(-1222.9, -906.9, 12.3),
		vector3(-1487.5, -379.1, 40.1),
		vector3(-2968.2, 390.9, 15.0),
		vector3(1166.0, 2708.9, 38.1),
		vector3(1392.5, 3604.6, 34.9),
		vector3(127.8, -1284.7, 29.2),   -- StripClub
		vector3(-1393.4, -606.6, 30.3),  -- Tequila la
		vector3(-559.9, 287.0, 82.1)     -- Bahamamas
	},
	Size = 0.8,
	Type = 59,
	Color = 25,
	ShowBlip = true,
	ShowMarker = true
}

Config.Zones.LTDgasoline = {
	Items = {
		{name = "taco_chicken", label = "Chicken Taco", price = 15, category = "food"},
		{name = "water", label = "Water", price = 10, category = "drinks"},
		{name = "sandwich", label = "Sandwich", price = 20, category = "food"},
		{name = "coffee", label = "Coffee", price = 8, category = "drinks"},
		{name = "repairkit", label = "Repair Kit", price = 350, category = "tools"},
		{name = "bandage", label = "Bandage", price = 45, category = "medical"}
	},
	Categories = {
		{id = "food", label = "Food", icon = "fa-solid fa-burger"},
		{id = "drinks", label = "Drinks", icon = "fa-solid fa-bottle-water"},
		{id = "tools", label = "Tools", icon = "fa-solid fa-wrench"},
		{id = "medical", label = "Medical", icon = "fa-solid fa-kit-medical"}
	},
	Pos = {
		vector3(-48.5, -1757.5, 29.4),
		vector3(1163.3, -323.8, 69.2),
		vector3(-707.5, -914.2, 19.2),
		vector3(-1820.5, 792.5, 138.1),
		vector3(1698.3, 4924.4, 42.0)
	},
	Size = 0.8,
	Type = 59,
	Color = 25,
	ShowBlip = true,
	ShowMarker = true
}
