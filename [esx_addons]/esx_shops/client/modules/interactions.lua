-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local currentAction = nil
local currentActionMsg = nil
local currentActionData = {}

---Handles entering shop marker (sets up interaction)
---@param zone string Shop zone name
function OnMarkerEnter(zone)
	currentAction = 'shop_menu'
	currentActionMsg = _U('press_e_shop', zone)
	currentActionData = { zone = zone }
end

---Handles exiting shop marker (clears interaction)
---@param zone string Shop zone name
function OnMarkerExit(zone)
	currentAction = nil
	currentActionMsg = nil
	if IsUIOpen() then
		CloseShop()
	end
end

---Gets current action message (for TextUI display)
---@return string|nil
function GetCurrentActionMsg()
	return currentActionMsg
end

---Gets current action data
---@return table
function GetCurrentActionData()
	return currentActionData
end

---Gets current action
---@return string|nil
function GetCurrentAction()
	return currentAction
end

-- Register ESX interaction
xLib.interactions.register('shop_menu', function()
	local data = GetCurrentActionData()
	if data and data.zone then
		OpenShop(data.zone)
	end
end, function()
	return GetCurrentAction() == 'shop_menu'
end)
