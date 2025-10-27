---@type table
Config = {}

-- ════════════════════════════════════════════════════════════════
-- IMAGE CONFIGURATION
-- ════════════════════════════════════════════════════════════════

-- Automatic image path generation for items
-- If an item doesn't have an 'image' field, it will be auto-generated as:
-- {DefaultImagePath}/{itemName}.{DefaultImageFormat}
-- Set to nil or empty string to disable auto-generation
Config.DefaultImagePath = "nui://ox_inventory/web/images"
Config.DefaultImageFormat = "png" -- png, webp, jpg, etc.

-- ════════════════════════════════════════════════════════════════
-- TAX SYSTEM CONFIGURATION
-- ════════════════════════════════════════════════════════════════

-- Default tax rate (19% VAT)
Config.TaxRate = 0.19

-- Enable/Disable tax collection to society account
-- false = Tax is only displayed, not collected
-- true = Tax is collected and deposited to society account
Config.EnableTaxCollection = false

-- Society account for tax collection (requires esx_addonaccount)
-- Only used if Config.EnableTaxCollection = true
-- Make sure this society exists in your database
Config.TaxSocietyAccount = 'society_banker'

-- Enable/Disable job-based tax exemptions
-- false = Everyone pays full tax
-- true = Jobs in TaxExemptJobs list pay 0% tax
Config.EnableTaxExemptions = false

-- Jobs that are exempt from paying tax
-- Only used if Config.EnableTaxExemptions = true
-- These jobs see 0% tax rate with special message in UI
Config.TaxExemptJobs = {
	'police',      -- Law enforcement
	'ambulance',   -- Emergency medical services
}

-- ════════════════════════════════════════════════════════════════
-- INVENTORY SYSTEM
-- ════════════════════════════════════════════════════════════════

-- Inventory system ('esx' or 'ox_inventory')
Config.Inventory = 'esx'

-- Marker configuration
Config.DrawDistance = 7.5
Config.MarkerSize = {x = 1.1, y = 0.7, z = 1.1}
Config.MarkerType = 29
Config.MarkerColor = {r = 50, g = 200, b = 50, a = 200}

---@type table<string, ShopZone>
Config.Zones = {
	TwentyFourSeven = {
		Items = {
			{name = "bread", label = "Bread", price = 15, category = "food", image = "https://r2.fivemanage.com/R92pivz8ZlXwjJjTvi3Oq/bread.png"},
			{name = "water", label = "Water", price = 10, category = "drinks", image = "https://r2.fivemanage.com/R92pivz8ZlXwjJjTvi3Oq/water.png"},
			{name = "burger", label = "Burger", price = 25, category = "food", image = "https://r2.fivemanage.com/R92pivz8ZlXwjJjTvi3Oq/burger.png"},
			{name = "cola", label = "Cola", price = 12, category = "drinks", image = "https://r2.fivemanage.com/R92pivz8ZlXwjJjTvi3Oq/cola.png"},
			{name = "phone", label = "Phone", price = 250, category = "electronics", image = "https://r2.fivemanage.com/R92pivz8ZlXwjJjTvi3Oq/phone.png"},
			{name = "lockpick", label = "Lockpick", price = 150, category = "tools", image = "https://r2.fivemanage.com/R92pivz8ZlXwjJjTvi3Oq/lockpick.png"}
		},
		-- Categories with FontAwesome icons (Find more icons at: https://fontawesome.com/icons)
		-- Icon format: "fa-solid fa-icon-name" or "fa-regular fa-icon-name"
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
	},

	RobsLiquor = {
		Items = {
			{name = "burger", label = "Burger", price = 15, category = "food"},
			{name = "water", label = "Water", price = 10, category = "drinks", image = "https://r2.fivemanage.com/R92pivz8ZlXwjJjTvi3Oq/water.png"},
			{name = "meth", label = "Meth", price = 18, category = "alcohol"},
			{name = "wine", label = "Wine", price = 35, category = "alcohol"},
			{name = "vodka", label = "Vodka", price = 50, category = "alcohol"},
			{name = "whiskey", label = "Whiskey", price = 65, category = "alcohol"}
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
			vector3(127.8, -1284.7, 29.2), -- StripClub
			vector3(-1393.4, -606.6, 30.3), -- Tequila la
			vector3(-559.9, 287.0, 82.1) -- Bahamamas
		},
		Size = 0.8,
		Type = 59,
		Color = 25,
		ShowBlip = true,
		ShowMarker = true
	},

	LTDgasoline = {
		Items = {
			{name = "bread", label = "Bread", price = 15, category = "food", image = "https://r2.fivemanage.com/R92pivz8ZlXwjJjTvi3Oq/bread.png"},
			{name = "water", label = "Water", price = 10, category = "drinks", image = "https://r2.fivemanage.com/R92pivz8ZlXwjJjTvi3Oq/water.png"},
			{name = "sandwich", label = "Sandwich", price = 20, category = "food", image = "https://r2.fivemanage.com/R92pivz8ZlXwjJjTvi3Oq/sandwich.png"},
			{name = "coffee", label = "Coffee", price = 8, category = "drinks", image = "https://r2.fivemanage.com/R92pivz8ZlXwjJjTvi3Oq/coffee.png"},
			{name = "repairkit", label = "Repair Kit", price = 350, category = "tools", image = "https://r2.fivemanage.com/R92pivz8ZlXwjJjTvi3Oq/repairkit.png"},
			{name = "bandage", label = "Bandage", price = 45, category = "medical", image = "https://r2.fivemanage.com/R92pivz8ZlXwjJjTvi3Oq/bandage.png"}
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
}
