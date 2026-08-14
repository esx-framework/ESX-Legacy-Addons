---Gets ESX theme colors from convars
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
