---@type table
Config = Config or {}

-- Enable debug prints in console (set to true for troubleshooting)
Config.Debug = false

-- ════════════════════════════════════════════════════════════════
-- CORE CONFIGURATION
-- ════════════════════════════════════════════════════════════════

-- Inventory system ('esx' or 'ox_inventory')
Config.Inventory = 'ox_inventory'

-- ════════════════════════════════════════════════════════════════
-- IMAGE CONFIGURATION
-- ════════════════════════════════════════════════════════════════

-- Automatic image path generation for items
-- If an item doesn't have an 'image' field, it will auto-generate as:
-- {DefaultImagePath}/{itemName}.{DefaultImageFormat}
-- Set to nil or empty string to disable auto-generation
Config.DefaultImagePath = "nui://esx_shops/web/images"
Config.DefaultImageFormat = "png" -- png, webp, jpg, etc.

-- ════════════════════════════════════════════════════════════════
-- TAX SYSTEM CONFIGURATION
-- ════════════════════════════════════════════════════════════════

-- Default tax rate (19% VAT)
Config.TaxRate = 0.19

-- Enable/Disable tax collection to society account
-- false = Tax is only displayed, not collected
-- true = Tax is collected and deposited to society account
Config.EnableTaxCollection = true

-- Society account for tax collection (requires esx_addonaccount)
-- Only used if Config.EnableTaxCollection = true
-- Make sure this society exists in your database
Config.TaxSocietyAccount = 'society_banker'

-- Enable/Disable job-based tax exemptions
-- false = Everyone pays full tax
-- true = Jobs in TaxExemptJobs list pay 0% tax
Config.EnableTaxExemptions = true

-- Jobs that are exempt from paying tax
-- Only used if Config.EnableTaxExemptions = true
-- These jobs see 0% tax rate with special message in UI
Config.TaxExemptJobs = {
	'police',      -- Law enforcement
	'ambulance',   -- Emergency medical services
}

-- ════════════════════════════════════════════════════════════════
-- MARKER CONFIGURATION
-- ════════════════════════════════════════════════════════════════

Config.DrawDistance = 7.5
Config.MarkerSize = {x = 1.1, y = 0.7, z = 1.1}
Config.MarkerType = 29
Config.MarkerColor = {r = 50, g = 200, b = 50, a = 200}

-- ════════════════════════════════════════════════════════════════
-- PERFORMANCE CONFIGURATION
-- ════════════════════════════════════════════════════════════════

-- Movement threshold for recalculating nearby shops (meters)
Config.MovementThreshold = 5.0

-- Sleep times for marker thread (ms)
Config.SleepNear = 0        -- Within 50m
Config.SleepMedium = 500    -- 50-100m away
Config.SleepFar = 1500      -- Far away

-- ════════════════════════════════════════════════════════════════
-- SECURITY CONFIGURATION
-- ════════════════════════════════════════════════════════════════

-- Rate limiting: cooldown between purchases (ms)
Config.PurchaseCooldownMs = 500

-- Auto-expire rate limit entries (ms)
Config.CooldownExpiryMs = 10000

-- Maximum quantity per item per transaction
Config.MaxQuantityPerItem = 999

-- Price validation tolerance
Config.PriceTolerance = 0.001
