---@class GarageBlip
---@field sprite integer -- https://docs.fivem.net/docs/game-references/blips/#blips
---@field scale number -- float
---@field color integer -- https://docs.fivem.net/docs/game-references/blips/#blip-colors

---@class GaragePed
---@field coords vector4
---@field model string | number -- Model Hash

---@class Garage
---@field id string
---@field label string
---@field entryPoint vector3
---@field spawnPoint vector4
---@field blip GarageBlip
---@field ped GaragePed
-- -@field impoundedName string

---@alias vehicle_type 'car'|'motorcycle'|'boat'|'aircraft'|'bicycle'|'truck'|'emergency'

---@class GarageVehicle
---@field id string -- plate
---@field plate string
---@field model string
---@field name string -- display_name
---@field type vehicle_type
---@field stored boolean
---@field garageId string
---@field impouned boolean
---@field impoundFee integer
---@field mileage integer
---@field fuel integer
---@field engine integer
---@field body integer
---@field isFavorite boolean
---@field customName string?
---@field lastUsed integer
---@field props ESXVehicleProperties

---@class GarageVehicleDB
---@field owner string
---@field plate string
---@field vehicle string
---@field type vehicle_type
---@field job string?
---@field stored integer
---@field parking string
---@field model string?
---@field favorite 0 | 1
