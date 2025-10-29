# esx_garage - NUI Migration Changes

## NUI Events (Lua → React)

### Event: `openGarage`

**Old:**
```lua
SendNUIMessage({
    showMenu = true,
    type = 'garage',
    vehiclesList = json.encode(vehiclesList),
    vehiclesImpoundedList = json.encode(vehiclesImpoundedList),
    poundName = v.ImpoundedName,
    poundSpawnPoint = poundSpawnPoint,
    spawnPoint = spawnPoint,
    locales = {
        action = TranslateCap('veh_exit'),
        veh_model = TranslateCap('veh_model'),
        veh_plate = TranslateCap('veh_plate'),
        veh_condition = TranslateCap('veh_condition'),
        veh_action = TranslateCap('veh_action'),
        impound_action = TranslateCap('impound_action')
    }
})
```

**New:**
```lua
SendNUIMessage({
    type = 'openGarage',
    payload = {
        garage = {
            id = string,              -- 'VespucciBoulevard'
            name = string,            -- 'VespucciBoulevard'
            type = string,            -- 'public'|'private'|'job'|'gang'|'impound'|'house'|'aircraft'|'boat'
            label = string,           -- Display name
            coords = {x, y, z, h},    -- Optional
            spawns = {{coords = {x, y, z, h}, occupied = false}}, -- Optional
            blip = {sprite, color, scale, display, shortRange},   -- Optional
            job = string,             -- Optional
            gang = string,            -- Optional
            maxVehicles = number      -- Optional
        },
        vehicles = {
            {
                id = string,              -- REQUIRED: Unique ID (plate or DB ID)
                plate = string,           -- REQUIRED
                model = string,           -- REQUIRED: Vehicle model
                name = string,            -- REQUIRED: Display name
                type = string,            -- REQUIRED: 'car'|'motorcycle'|'boat'|'aircraft'|'bicycle'|'truck'|'emergency'
                stored = boolean,         -- REQUIRED
                garage = string,          -- Optional: Garage ID
                impounded = boolean,      -- REQUIRED
                impoundFee = number,      -- Optional
                mileage = number,         -- REQUIRED
                fuel = number,            -- Optional: 0-100
                engine = number,          -- Optional: 0-100
                body = number,            -- Optional: 0-100
                image = string,           -- Optional: URL
                isFavorite = boolean,     -- Optional
                customName = string,      -- Optional: Max 50 chars
                lastUsed = number,        -- Optional: Timestamp
                props = table             -- Optional: ESX.Game.GetVehicleProperties()
            }
        }
    }
})
```

### Event: `closeGarage`

**Old:**
```lua
SendNUIMessage({hideAll = true})
```

**New:**
```lua
SendNUIMessage({
    type = 'closeGarage',
    payload = {}
})
```

### Event: `updateVehicles` (NEW)

```lua
SendNUIMessage({
    type = 'updateVehicles',
    payload = vehicles -- Array of vehicle objects (same structure as above)
})
```

### Event: `showNotification` (NEW - Optional)

```lua
SendNUIMessage({
    type = 'showNotification',
    payload = {
        message = string,
        type = 'success'|'error'|'info'|'warning' -- Default: 'info'
    }
})
```

---

## NUI Callbacks (React → Lua)

**All callbacks must return:**
```lua
{
    success = boolean,
    data = any,        -- Optional: Success data
    error = string     -- Optional: Error message if success = false
}
```

### Callback: `garage:retrieveVehicle`

**Old:** `spawnVehicle`
```lua
RegisterNUICallback('spawnVehicle', function(data, cb)
    -- data.spawnPoint, data.vehicleProps, data.exitVehicleCost
    cb('ok')
end)
```

**New:**
```lua
RegisterNUICallback('garage:retrieveVehicle', function(data, cb)
    -- data = {vehicleId = string}

    if success then
        cb({success = true, data = true})
    else
        cb({success = false, error = 'Spawn point blocked'})
    end
end)
```

### Callback: `garage:storeVehicle` (NEW)

```lua
RegisterNUICallback('garage:storeVehicle', function(data, cb)
    -- data = {vehicleId = string, garageId = string}

    cb({success = true, data = true})
end)
```

### Callback: `garage:renameVehicle` (NEW)

```lua
RegisterNUICallback('garage:renameVehicle', function(data, cb)
    -- data = {vehicleId = string, newName = string}

    cb({success = true, data = true})
end)
```

### Callback: `garage:toggleFavorite` (NEW)

```lua
RegisterNUICallback('garage:toggleFavorite', function(data, cb)
    -- data = {vehicleId = string, isFavorite = boolean}

    cb({success = true, data = true})
end)
```

### Callback: `garage:giveKeys` (NEW)

```lua
RegisterNUICallback('garage:giveKeys', function(data, cb)
    -- data = {vehicleId = string, targetId = string}

    cb({success = true, data = true})
end)
```

### Callback: `garage:transferVehicle` (NEW)

```lua
RegisterNUICallback('garage:transferVehicle', function(data, cb)
    -- data = {vehicleId = string, targetId = string}

    cb({success = true, data = true})
end)
```

### Callback: `garage:closeUI`

**Old:** `escape`
```lua
RegisterNUICallback('escape', function(data, cb)
    cb('ok')
end)
```

**New:**
```lua
RegisterNUICallback('garage:closeUI', function(data, cb)
    SetNuiFocus(false, false)
    cb({success = true})
end)
```

---

## Database Schema Changes

```sql
ALTER TABLE owned_vehicles
ADD COLUMN custom_name VARCHAR(50) NULL,
ADD COLUMN is_favorite TINYINT(1) DEFAULT 0,
ADD COLUMN last_used INT(11) NULL,
ADD COLUMN mileage INT(11) DEFAULT 0;
```

---

## Helper Functions

### GetVehicleType
```lua
function GetVehicleType(model)
    local class = GetVehicleClassFromName(model)
    if class == 8 then return 'motorcycle'
    elseif class == 13 then return 'bicycle'
    elseif class == 14 then return 'boat'
    elseif class == 15 or class == 16 then return 'aircraft'
    elseif class == 18 then return 'emergency'
    elseif class == 20 then return 'truck'
    else return 'car' end
end
```

### CalculateHealth
```lua
function CalculateEngineHealth(health)
    return math.floor((health / 1000.0) * 100)
end

function CalculateBodyHealth(health)
    return math.floor((health / 1000.0) * 100)
end
```

---

## Complete Implementation Example

### Client: Open Garage
```lua
local function OpenGarage(garageName)
    local garage = Config.Garages[garageName]
    if not garage then return end

    ESX.TriggerServerCallback('esx_garage:getVehiclesInParking', function(vehicles)
        local vehicleList = {}

        for i = 1, #vehicles do
            local v = vehicles[i]
            local props = json.decode(v.vehicle)

            table.insert(vehicleList, {
                id = v.plate,
                plate = v.plate,
                model = props.model,
                name = GetDisplayNameFromVehicleModel(props.model),
                type = GetVehicleType(props.model),
                stored = v.stored == 1,
                garage = v.parking,
                impounded = v.stored == 2,
                impoundFee = v.stored == 2 and Config.Impounds[v.pound].Cost or nil,
                mileage = v.mileage or 0,
                fuel = props.fuelLevel or 100,
                engine = CalculateEngineHealth(props.engineHealth or 1000),
                body = CalculateBodyHealth(props.bodyHealth or 1000),
                isFavorite = v.is_favorite == 1,
                customName = v.custom_name,
                lastUsed = v.last_used,
                props = props
            })
        end

        SendNUIMessage({
            type = 'openGarage',
            payload = {
                garage = {
                    id = garageName,
                    name = garageName,
                    type = 'public',
                    label = TranslateCap('parking_blip_name'),
                    coords = {
                        x = garage.EntryPoint.x,
                        y = garage.EntryPoint.y,
                        z = garage.EntryPoint.z
                    },
                    spawns = {{
                        coords = {
                            x = garage.SpawnPoint.x,
                            y = garage.SpawnPoint.y,
                            z = garage.SpawnPoint.z,
                            h = garage.SpawnPoint.heading
                        },
                        occupied = false
                    }}
                },
                vehicles = vehicleList
            }
        })

        SetNuiFocus(true, true)
    end, garageName)
end
```

### Client: Retrieve Vehicle Callback
```lua
RegisterNUICallback('garage:retrieveVehicle', function(data, cb)
    local vehicleId = data.vehicleId

    if not vehicleId then
        cb({success = false, error = 'Invalid vehicle ID'})
        return
    end

    ESX.TriggerServerCallback('esx_garage:getVehicleById', function(vehicleData)
        if not vehicleData then
            cb({success = false, error = 'Vehicle not found'})
            return
        end

        local props = json.decode(vehicleData.vehicle)
        local garage = Config.Garages[vehicleData.parking]
        local spawnPoint = vector3(garage.SpawnPoint.x, garage.SpawnPoint.y, garage.SpawnPoint.z)

        if not ESX.Game.IsSpawnPointClear(spawnPoint, 2.5) then
            cb({success = false, error = 'Spawn point blocked'})
            return
        end

        ESX.OneSync.SpawnVehicle(props.model, spawnPoint, garage.SpawnPoint.heading, props, function(vehicle)
            local veh = NetworkGetEntityFromNetworkId(vehicle)
            Wait(300)
            TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)

            TriggerServerEvent('esx_garage:updateVehicleStored', vehicleId, false)
            cb({success = true, data = true})
        end)
    end, vehicleId)
end)
```

### Client: Rename Vehicle Callback
```lua
RegisterNUICallback('garage:renameVehicle', function(data, cb)
    local vehicleId = data.vehicleId
    local newName = data.newName

    if not vehicleId or not newName or #newName < 1 or #newName > 50 then
        cb({success = false, error = 'Invalid data'})
        return
    end

    TriggerServerEvent('esx_garage:renameVehicle', vehicleId, newName)
    cb({success = true, data = true})
end)
```

### Client: Toggle Favorite Callback
```lua
RegisterNUICallback('garage:toggleFavorite', function(data, cb)
    local vehicleId = data.vehicleId
    local isFavorite = data.isFavorite

    if not vehicleId or type(isFavorite) ~= 'boolean' then
        cb({success = false, error = 'Invalid data'})
        return
    end

    TriggerServerEvent('esx_garage:toggleFavorite', vehicleId, isFavorite)
    cb({success = true, data = true})
end)
```

### Server: Get Vehicle by ID
```lua
ESX.RegisterServerCallback('esx_garage:getVehicleById', function(source, cb, vehicleId)
    local xPlayer = ESX.GetPlayerFromId(source)

    MySQL.query('SELECT * FROM owned_vehicles WHERE plate = ? AND owner = ?', {
        vehicleId,
        xPlayer.identifier
    }, function(result)
        cb(result[1] or nil)
    end)
end)
```

### Server: Update Vehicle Stored
```lua
RegisterServerEvent('esx_garage:updateVehicleStored')
AddEventHandler('esx_garage:updateVehicleStored', function(vehicleId, stored)
    local xPlayer = ESX.GetPlayerFromId(source)

    MySQL.update('UPDATE owned_vehicles SET stored = ?, last_used = ? WHERE plate = ? AND owner = ?', {
        stored and 1 or 0,
        os.time(),
        vehicleId,
        xPlayer.identifier
    })
end)
```

### Server: Rename Vehicle
```lua
RegisterServerEvent('esx_garage:renameVehicle')
AddEventHandler('esx_garage:renameVehicle', function(vehicleId, newName)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not vehicleId or not newName or #newName < 1 or #newName > 50 then
        return
    end

    MySQL.update('UPDATE owned_vehicles SET custom_name = ? WHERE plate = ? AND owner = ?', {
        newName,
        vehicleId,
        xPlayer.identifier
    })
end)
```

### Server: Toggle Favorite
```lua
RegisterServerEvent('esx_garage:toggleFavorite')
AddEventHandler('esx_garage:toggleFavorite', function(vehicleId, isFavorite)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not vehicleId or type(isFavorite) ~= 'boolean' then
        return
    end

    MySQL.update('UPDATE owned_vehicles SET is_favorite = ? WHERE plate = ? AND owner = ?', {
        isFavorite and 1 or 0,
        vehicleId,
        xPlayer.identifier
    })
end)
```

---

## Quick Reference

### Event Names Changed
| Old | New |
|-----|-----|
| `showMenu = true` | `type = 'openGarage'` |
| `hideAll = true` | `type = 'closeGarage'` |

### Callback Names Changed
| Old | New |
|-----|-----|
| `spawnVehicle` | `garage:retrieveVehicle` |
| `escape` | `garage:closeUI` |
| `impound` | Removed |

### New Callbacks
- `garage:storeVehicle`
- `garage:renameVehicle`
- `garage:toggleFavorite`
- `garage:giveKeys`
- `garage:transferVehicle`

### New Events
- `updateVehicles`
- `showNotification`

### Data Format Changes
- No more `json.encode()` for NUI messages - send tables directly
- All callbacks require `{success, data, error}` response format
- Vehicle objects now require `id`, `type`, `mileage`, and health fields
- Locales removed from NUI messages (handled in React)
