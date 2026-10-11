-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Config = {}

Config.DrawDistance = 15.0
Config.ZoneSize = { x = 2.7, y = 2.7, z = 0.5 }
Config.MarkerColor = { r = 100, g = 200, b = 104 }
Config.MarkerType = 27
Config.Debug = ESX.GetConfig().EnableDebug

Config.Locale = GetConvar('esx:locale', 'en')
Config.JobDetails = {
    miner = {
        subtitle = 'Mining & resources',
        image = 'assets/miner.png',
        rating = 4,
        location = {
            x = 2954.2,
            y = 2787.8
        },
        description = 'Being a miner is tough work, but it pays well. Your shift starts at the quarry office, then moves through real work stages: extracting rock from active veins, washing raw ore, processing usable material, and delivering sealed sacks to buyers.\n\nThis job rewards steady physical work. You will move across the quarry and industrial drop points instead of standing on one marker.\n\nHard work underground - clean profit above.',
        tasks = {
            {
                title = 'Extract mineral rock',
                description = 'Break rocks from active quarry veins.',
                current = 0,
                target = 40
            },
            {
                title = 'Process raw ore',
                description = 'Wash and separate usable material.',
                current = 0,
                target = 20
            },
            {
                title = 'Deliver processed sacks',
                description = 'Take sealed sacks to the buyer.',
                current = 0,
                target = 10
            }
        }
    },
    delivery = {
        subtitle = 'Warehouse & parcels',
        rating = 3,
        location = {
            x = -424.23,
            y = -2789.84
        },
        description = 'Delivery work begins at the warehouse. Load the van, follow the GPS route, carry parcels to assigned doors, and return the signed manifest when the route is complete.\n\nGood drivers earn more by keeping the route moving and staying close to their company vehicle. The job is simple to understand, but it feels like a real shift because every stop has a purpose.',
        tasks = {
            {
                title = 'Load delivery van',
                description = 'Scan and load parcels at the warehouse.',
                current = 0,
                target = 10
            },
            {
                title = 'Complete doorstep deliveries',
                description = 'Carry parcels to assigned addresses.',
                current = 0,
                target = 10
            },
            {
                title = 'Return delivery manifest',
                description = 'Close the route back at the warehouse.',
                current = 0,
                target = 5
            }
        }
    },
    garbage = {
        subtitle = 'City sanitation',
        rating = 3,
        location = {
            x = 485.14,
            y = -1306.16
        },
        description = 'Sanitation workers keep the city clean. Start at the depot, take out a garbage truck, collect public trash bags from marked blocks, compact the truck load, and dump it at the landfill.\n\nThis is built around movement, vehicle responsibility, and repeated physical actions, so it feels more like a city route than a simple farming point.',
        tasks = {
            {
                title = 'Collect public trash bags',
                description = 'Pull bags from assigned collection points.',
                current = 0,
                target = 20
            },
            {
                title = 'Compact truck load',
                description = 'Secure the load before leaving the block.',
                current = 0,
                target = 10
            },
            {
                title = 'Dump at landfill',
                description = 'Empty the truck at the city landfill.',
                current = 0,
                target = 5
            }
        }
    }
}

Config.UnemployedJob = 'unemployed'

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