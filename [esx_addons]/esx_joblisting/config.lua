-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Config = {}

Config.DrawDistance = 15.0
Config.ZoneSize = {x = 2.7, y = 2.7, z = 0.5}
Config.MarkerColor = {r = 100, g = 200, b = 104}
Config.MarkerType = 27
Config.Debug = ESX.GetConfig().EnableDebug

Config.Locale = GetConvar('esx:locale', 'en')

Config.Zones = {
  vector3(-265.08, -964.1, 30.3)
}

Config.Blip = {
  Enabled = true, 
  Sprite = 407, 
  Display = 4, 
  Scale = 0.8, 
  Colour = 27, 
  ShortRange = true
}

-- Icon shown next to each job in the job centre.
-- Keys are job names, values are Lucide icon names (https://lucide.dev/icons).
-- Any job not listed here falls back to Config.DefaultJobIcon.
Config.JobIcons = {
  unemployed = 'User',
  police = 'Shield',
  ambulance = 'Ambulance',
  doctor = 'Stethoscope',
  mechanic = 'Wrench',
  taxi = 'Car',
  bus = 'Bus',
  trucker = 'Truck',
  delivery = 'Package',
  realestate = 'Home',
  lawyer = 'Scale',
  judge = 'Gavel',
  reporter = 'Newspaper',
  banker = 'Landmark',
  cardealer = 'CarFront',
  garbage = 'Trash2',
  gardener = 'Flower2',
  fisherman = 'Fish',
  miner = 'Pickaxe',
  lumberjack = 'Trees',
  butcher = 'Beef',
  baker = 'Croissant',
  chef = 'ChefHat',
  farmer = 'Tractor',
  fueler = 'Fuel',
  hunter = 'Crosshair',
  security = 'ShieldCheck',
  pilot = 'Plane',
  tailor = 'Scissors',
  cashier = 'Store',
  builder = 'HardHat'
}

Config.DefaultJobIcon = 'Briefcase'

-- Optional short description shown as the second line of each job row.
-- If a job has no description, the job's salary range is shown instead.
-- Example:
-- Config.JobDescriptions = {
--   police = 'Protect and serve the city',
--   mechanic = 'Repair and tune vehicles'
-- }
Config.JobDescriptions = {}
