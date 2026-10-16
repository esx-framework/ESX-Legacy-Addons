--- Sanitizes string input to prevent XSS/HTML injection
--- Replaces HTML special characters with safe equivalents
---@param input string Raw input string
---@return string sanitized Sanitized string safe for display
local function SanitizeString(input)
    if type(input) ~= "string" then
        return tostring(input)
    end

    local sanitized = input
    sanitized = string.gsub(sanitized, "<", "&lt;")
    sanitized = string.gsub(sanitized, ">", "&gt;")
    sanitized = string.gsub(sanitized, '"', "&quot;")
    sanitized = string.gsub(sanitized, "'", "&#39;")
    sanitized = string.gsub(sanitized, "&", "&amp;")

    -- Limit length to prevent spam
    if #sanitized > 500 then
        sanitized = string.sub(sanitized, 1, 500) .. "..."
    end

    return sanitized
end

--- Displays a notification to the player via NUI
--- Validates input data and sends formatted notification to web UI
--- Large notifications only support bottom-center position
--- Sanitizes header and description to prevent XSS attacks
---@param data NotificationData Notification configuration object
---@return nil
---@example
--- exports['esx_halloween']:showNotification({
---     size = 'small',
---     position = 'top-right',
---     header = 'Achievement',
---     description = 'You found a secret!',
---     duration = 3000
--- })
local function ShowNotification(data)
    if type(data) ~= "table" then
        print("^1[ESX Halloween] Error: ShowNotification requires a table parameter^7")
        return
    end

    if not data.size or not data.position or not data.header or not data.description then
        print("^1[ESX Halloween] Error: Missing required notification fields^7")
        return
    end

    -- Localize to avoid constant table indexing
    local size = data.size
    local position = data.position

    -- Validate size
    if size ~= "small" and size ~= "large" then
        print("^3[ESX Halloween] Warning: Invalid size '" .. tostring(size) .. "', defaulting to 'small'^7")
        size = "small"
    end

    -- Validate position
    local validPositions = { ["top-left"] = true, ["top-right"] = true, ["top-center"] = true, ["bottom-center"] = true }
    if not validPositions[position] then
        print("^3[ESX Halloween] Warning: Invalid position '" .. tostring(position) .. "', defaulting to 'top-right'^7")
        position = "top-right"
    end

    if size == "large" and position ~= "bottom-center" then
        print("^3[ESX Halloween] Warning: Large notifications only support bottom-center position^7")
        position = "bottom-center"
    end

    -- Sanitize strings
    local header = SanitizeString(data.header)
    local description = SanitizeString(data.description)

    -- Validate duration
    local duration = tonumber(data.duration) or 5000
    if duration < 1000 or duration > 30000 then
        duration = 5000
    end

    SendNUIMessage({
        type = 'showNotification',
        size = size,
        position = position,
        header = header,
        description = description,
        duration = duration
    })
end

exports('showNotification', ShowNotification)
