<h1 align='center'>[ESX] Lscustoms</a></h1><p align='center'><b><a href='https://discord.esx-framework.org/'>Discord</a> - <a href='https://documentation.esx-framework.org/legacy/installation'>Documentation</a></b></h5>

## Requirements

- [esx_vehicleshop](https://github.com/esx-framework/esx_vehicleshop)

## Ownership Policy

LS Customs validates every cart server-side, but vehicle ownership is configurable:

```lua
Config.Workshop.Ownership = {
	RequireOwned = false,
	SaveOwnedVehicles = true,
	AllowMechanicCustomerVehicles = true
}
```

- `RequireOwned = false` lets players/mechanics tune spawned or non-owned vehicles.
  Those changes apply to the current vehicle entity, but are not written to
  `owned_vehicles` unless the plate exists there and the saver is allowed.
- `SaveOwnedVehicles = true` persists paid changes when the vehicle exists in
  `owned_vehicles`.
- `AllowMechanicCustomerVehicles = true` lets mechanics persist changes to customer
  vehicles without owning them.

Set `RequireOwned = true` only if your server wants LS Customs to reject spawned
vehicles and vehicles that are neither owned by the player nor handled by a mechanic.

## Legal

esx_lscustoms - The best LS Custom out there for FX

Copyright (C) 2015-2025 Jérémie N'gadi

This program Is free software: you can redistribute it And/Or modify it under the terms Of the GNU General Public License As published by the Free Software Foundation, either version 3 Of the License, Or (at your option) any later version.

This program Is distributed In the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty Of MERCHANTABILITY Or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License For more details.

You should have received a copy Of the GNU General Public License along with this program. If Not, see http://www.gnu.org/licenses/.
