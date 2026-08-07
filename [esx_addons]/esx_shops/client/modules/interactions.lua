local currentAction = nil
local currentActionMsg = nil
local currentActionData = {}

function OnMarkerEnter(zone)
	currentAction = 'shop_menu'
	currentActionMsg = _U('press_e_shop', zone)
	currentActionData = { zone = zone }
end

function OnMarkerExit(zone)
	currentAction = nil
	currentActionMsg = nil
	if IsUIOpen() then
		CloseShop()
	end
end

function GetCurrentActionMsg()
	return currentActionMsg
end

function GetCurrentActionData()
	return currentActionData
end

function GetCurrentAction()
	return currentAction
end

ESX.RegisterInteraction('shop_menu', function()
	local data = GetCurrentActionData()
	if data and data.zone then
		OpenShop(data.zone)
	end
end, function()
	return GetCurrentAction() == 'shop_menu'
end)