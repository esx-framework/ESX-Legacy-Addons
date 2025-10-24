---@meta

---@class ShopItem
---@field name string Item spawn name (e.g., "bread", "water")
---@field label string Display label shown in UI
---@field price number Gross price including tax (e.g., 100)
---@field category string|nil Category identifier (e.g., "food", "drinks")
---@field image string|nil Image URL for UI display - If not provided, auto-generated from Config.DefaultImagePath/{name}.{Config.DefaultImageFormat}
---@field limit number|nil Maximum purchase quantity per transaction

---@class ShopCategory
---@field id string Unique category identifier
---@field label string Display name shown in UI
---@field icon string|nil FontAwesome icon class (e.g., "fa-solid fa-burger") - Find icons at https://fontawesome.com/icons

---@class ShopZone
---@field Items ShopItem[] Available items in this shop
---@field Categories ShopCategory[]|nil Optional category definitions
---@field Pos vector3[] Shop locations on map
---@field Size number Blip size
---@field Type number Blip sprite type
---@field Color number Blip color
---@field ShowBlip boolean Whether to show blip on map
---@field ShowMarker boolean Whether to show 3D marker at location

---@class ShopData
---@field shopName string Shop name
---@field items ShopItem[] Available items
---@field categories ShopCategory[]|nil Item categories
---@field taxRate number Dynamic tax rate for player (0.0 - 0.19)
---@field taxMessage string|nil Optional tax message (e.g., "Thanks for your service!")

---@class PurchaseItemData
---@field name string Item name
---@field quantity number Quantity to purchase
---@field price number Price per item (gross)

---@class PurchaseRequest
---@field items PurchaseItemData[] Items to purchase
---@field total number Total gross price
---@field paymentMethod "cash"|"bank" Payment method

---@class ThemeConvars
---@field primaryColor string Primary brand color (hex)
---@field secondaryColor string Secondary color (hex)
---@field backgroundColor string Background color (hex)
---@field accentColor string Accent/highlight color (hex)
---@field logoUrl string Logo image URL
