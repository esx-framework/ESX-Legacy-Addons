-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

RegisterNetEvent('esx_rpchat:sendProximityMessage')
AddEventHandler('esx_rpchat:sendProximityMessage', function(playerIdOrTitle, titleOrMessage, messageOrColor, color)
	if not color then
		TriggerEvent('chat:addMessage', {args = {playerIdOrTitle, titleOrMessage}, color = messageOrColor})
		return
	end

	local playerId = playerIdOrTitle
	local title = titleOrMessage
	local message = messageOrColor
	local player = PlayerId()
	local target = GetPlayerFromServerId(playerId)

	if target == -1 then
		return
	end

	local playerPed = PlayerPedId()
	local targetPed = GetPlayerPed(target)
	local playerCoords = GetEntityCoords(playerPed)
	local targetCoords = GetEntityCoords(targetPed)

	if target == player or #(playerCoords - targetCoords) < (tonumber(Config.ProximityDistance) or 20.0) then
		TriggerEvent('chat:addMessage', {args = {title, message}, color = color})
	end
end)

CreateThread(function()
	TriggerEvent('chat:addSuggestion', '/twt',  TranslateCap('twt_help'),  {{name = TranslateCap('generic_argument_name'), help = TranslateCap('generic_argument_help')}})
	TriggerEvent('chat:addSuggestion', '/anontwt',  TranslateCap('twtanon_help'),  {{name = TranslateCap('generic_argument_name'), help = TranslateCap('generic_argument_help')}})
	TriggerEvent('chat:addSuggestion', '/me',   TranslateCap('me_help'),   {{name = TranslateCap('generic_argument_name'), help = TranslateCap('generic_argument_help')}})
	TriggerEvent('chat:addSuggestion', '/do',   TranslateCap('do_help'),   {{name = TranslateCap('generic_argument_name'), help = TranslateCap('generic_argument_help')}})
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		TriggerEvent('chat:removeSuggestion', '/twt')
		TriggerEvent('chat:removeSuggestion', '/me')
		TriggerEvent('chat:removeSuggestion', '/do')
	end
end)

