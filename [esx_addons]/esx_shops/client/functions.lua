-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

---Gets ESX theme colors from convars
---@return table Theme colors
function GetESXThemeColors()
	return xLib.colors.getESXTheme({
		primaryColor = '#AD0643',
		secondaryColor = '#1a1a1a',
		backgroundColor = '#0a0a0a',
		accentColor = '#ffffff'
	})
end
