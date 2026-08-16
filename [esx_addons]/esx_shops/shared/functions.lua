---Prints a message only when Config.Debug is enabled
---@param ... any
function DebugPrint(...)
	if Config.Debug then
		print(...)
	end
end

---Processes items and auto-generates image paths if needed
---@param items table[] Raw items from config
---@return table[] processedItems Items with auto-generated images
function ProcessItemImages(items)
	-- Return early if no auto-generation configured
	if not Config.DefaultImagePath or Config.DefaultImagePath == '' then
		return items
	end

	local processedItems = {}
	local itemCount = #items

	for i = 1, itemCount do
		local item = items[i]
		local processedItem = {
			name = item.name,
			label = item.label,
			price = item.price,
			category = item.category,
			limit = item.limit
		}

		-- Auto-generate image path if not provided
		if item.image then
			processedItem.image = item.image
		else
			processedItem.image = ('%s/%s.%s'):format(
				Config.DefaultImagePath,
				item.name,
				Config.DefaultImageFormat
			)
		end

		processedItems[i] = processedItem
	end

	return processedItems
end

---Gets ESX theme colors from convars (client-only)
---@return table Theme colors
function GetESXThemeColors()
	return {
		primaryColor = GetConvar('esx:ui:primaryColor', '#AD0643'),
		secondaryColor = GetConvar('esx:ui:secondaryColor', '#1a1a1a'),
		backgroundColor = GetConvar('esx:ui:backgroundColor', '#0a0a0a'),
		accentColor = GetConvar('esx:ui:accentColor', '#ffffff'),
		logoUrl = GetConvar('esx:ui:logoUrl', '')
	}
end

---Checks if a table contains a value
---@param tbl table
---@param value any
---@return boolean
function TableContains(tbl, value)
	for _, v in ipairs(tbl) do
		if v == value then
			return true
		end
	end
	return false
end
