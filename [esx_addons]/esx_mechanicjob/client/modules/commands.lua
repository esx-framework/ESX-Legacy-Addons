-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local Mechanic = ESXMechanicJob
local State = Mechanic.State

RegisterCommand('mechanicMenu', function()
	if Mechanic.isMechanic() and not State.isDead then
		Mechanic.openMobileActionsMenu()
	end
end, false)

RegisterCommand('mechanicjob', function()
	local playerPed = PlayerPedId()

	if not Mechanic.isMechanic() or State.isDead then
		return
	end

	if State.npcOnJob then
		if GetGameTimer() - State.npcLastCancel > 5 * 60000 then
			Mechanic.stopNPCJob(true)
			State.npcLastCancel = GetGameTimer()
		else
			ESX.ShowNotification(TranslateCap('wait_five'), "error")
		end

		return
	end

	if IsPedInAnyVehicle(playerPed, false) and IsVehicleModel(GetVehiclePedIsIn(playerPed, false), `flatbed`) then
		Mechanic.startNPCJob()
	else
		ESX.ShowNotification(TranslateCap('must_in_flatbed'), "error")
	end
end, false)

RegisterKeyMapping('mechanicMenu', 'Open Mechanic Menu', 'keyboard', Config.Controls.mechanicMenu)
RegisterKeyMapping('mechanicjob', 'Toggle NPC Job', 'keyboard', Config.Controls.toggleNPCJob)

AddEventHandler('esx:onPlayerDeath', function()
	State.isDead = true
end)

AddEventHandler('esx:onPlayerSpawn', function()
	State.isDead = false
end)
