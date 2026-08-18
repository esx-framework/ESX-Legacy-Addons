---@alias GarageType 'public' | 'job' | 'gang' | 'impound'
---@alias vehicle_type 'car' | 'motorcycle' | 'boat' | 'aircraft' | 'bicycle' | 'truck' | 'emergency'

---@class GarageBlip
---@field sprite integer
---@field scale number
---@field color integer

---@class GaragePed
---@field model string | integer
---@field coords vector4

---@class GarageAccess
---@field jobs? table<string, integer> Job name mapped to the minimum grade allowed.
---@field authorize? fun(source: integer, garage: Garage): boolean Custom server-side check, e.g. VIP or gang.

---@class Garage
---@field id string
---@field label string
---@field type GarageType
---@field entryPoint vector3
---@field storePoint? vector3
---@field spawns vector4[]
---@field blip? GarageBlip
---@field ped? GaragePed
---@field access? GarageAccess
---@field logo? string Image url or nui path shown in the menu header.
---@field color? string Hex accent color applied to the menu.
---@field pound? string Linked impound lot id.
---@field maxVehicles? integer

---@class Impound
---@field id string
---@field label string
---@field getOutPoint vector3
---@field spawns vector4[]
---@field blip? GarageBlip
---@field ped? GaragePed
---@field cost integer

---@class GarageSettings
---@field interactionDistance number
---@field restrictToGarage boolean
---@field defaultImpoundFee integer
---@field vehicleKeys boolean

---@class OwnedVehicleRow
---@field plate string
---@field vehicle string
---@field type vehicle_type
---@field stored integer
---@field parking string?
---@field pound string?
---@field custom_name string?
---@field is_favorite integer
---@field last_used integer?
---@field mileage integer

---@class GarageVehicle
---@field id string
---@field plate string
---@field model string
---@field name string
---@field type vehicle_type
---@field stored boolean
---@field garage string?
---@field impounded boolean
---@field impoundFee integer?
---@field mileage integer
---@field fuel number?
---@field engine number?
---@field body number?
---@field isFavorite boolean
---@field customName string?
---@field lastUsed integer?
---@field props table
