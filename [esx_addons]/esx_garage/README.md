<h1 align='center'>[ESX] Garage</a></h1><p align='center'><b><a href='https://discord.esx-framework.org/'>Discord</a> - <a href='https://documentation.esx-framework.org/legacy/installation'>Documentation</a></b></h5>

Store Your vehicles in style! ESX garage has an amazing New UI to help you be stylish while parking your broken, rusty Nissan Micra!

# Data model & maintenance

Vehicle state lives on the standard `owned_vehicles` table, aligned with the es_extended vehicle class:

- `stored` (boolean): `1` = parked in a garage or sitting in an impound, `0` = out in the world.
- `parking` (string): id of the garage the vehicle is stored in (null when out or impounded).
- `pound` (string): id of the impound lot when impounded (null otherwise).
- `custom_name`, `is_favorite`, `last_used`, `mileage`: per-vehicle metadata.

A vehicle whose row says `stored = 0` while no entity is left in the world (server restart, crash) is out of sync. It is recovered from an **impound** only, against that lot's fee: garages never hand it back. Recovery deletes every live entity carrying the plate before respawning, so it cannot duplicate the vehicle.

`Config.Settings.restrictToGarage` ties a stored vehicle to the garage named by `parking`. A `parking` that is `NULL` (every vehicle predating this resource, since the migration does not backfill it) or that names a garage which no longer exists is treated as **available at any garage**, so upgrading or removing a garage can never strand a vehicle. Listing and retrieval share that exact rule, so what the menu shows is always what the server will hand over.

The resource auto-migrates on start (`server/modules/migration.lua`): it adds any missing column and converts legacy tri-state `stored = 2` rows to `stored = 1` + `pound` set to the first configured impound lot (the legacy schema does not record which lot). `esx_garage.sql` mirrors this for fresh installs. No manual step is required on existing servers.

# Legal

esx_Garage - store vehicles in style!

Copyright (C) ESX-Framework

This program Is free software: you can redistribute it And/Or modify it under the terms Of the GNU General Public License As published by the Free Software Foundation, either version 3 Of the License, Or (at your option) any later version.

This program Is distributed In the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty Of MERCHANTABILITY Or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License For more details.

You should have received a copy Of the GNU General Public License along with this program. If Not, see http://www.gnu.org/licenses/.
