--- Retrieves ESX UI theme colors from server convars
--- Used to sync ESX Halloween UI with server's ESX color scheme
--- Falls back to default orange (#fb9b04) if convars not set
---@return ThemeColors Table with primary, secondary, background, accent, logoUrl fields
local function GetESXThemeColors()
    return {
        primary = GetConvar('esx:ui:primaryColor', '#fb9b04'),
        secondary = GetConvar('esx:ui:secondaryColor', '#1a1a1a'),
        background = GetConvar('esx:ui:backgroundColor', '#000000'),
        accent = GetConvar('esx:ui:accentColor', '#fb9b04'),
        logoUrl = GetConvar('esx:ui:logoUrl', '')
    }
end

CreateThread(function()
    Wait(1000)

    local colors = GetESXThemeColors()

    SendNUIMessage({
        type = 'setThemeColors',
        colors = colors
    })
end)
