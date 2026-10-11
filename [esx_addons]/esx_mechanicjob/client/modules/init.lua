-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

ESXMechanicJob = ESXMechanicJob or {}

local Mechanic = ESXMechanicJob

Mechanic.State = {
	hasAlreadyEnteredMarker = false,
	lastZone = nil,
	currentAction = nil,
	currentActionMsg = '',
	currentActionData = {},
	currentlyTowedVehicle = nil,
	blips = {},
	npcOnJob = false,
	npcTargetTowable = nil,
	npcTargetTowableNetId = nil,
	npcTargetTowableZone = nil,
	npcHasSpawnedTowable = false,
	npcLastCancel = GetGameTimer() - 5 * 60000,
	npcHasBeenNextToTowable = false,
	npcTargetDeleterZone = false,
	npcJobCompletionPending = false,
	lastEntity = nil,
	isDead = false,
	isBusy = false
}

Mechanic.TrackedObjects = {
	'prop_roadcone02a',
	'prop_toolchest_01'
}

function Mechanic.isMechanic()
	return ESX.PlayerData
		and ESX.PlayerData.job
		and ESX.PlayerData.job.name == 'mechanic'
end

function Mechanic.setCurrentAction(action, message, data)
	local state = Mechanic.State
	state.currentAction = action
	state.currentActionMsg = message or ''
	state.currentActionData = data or {}
end

function Mechanic.clearCurrentAction()
	Mechanic.setCurrentAction(nil, '', {})
end

function Mechanic.showCurrentAction()
	local message = Mechanic.State.currentActionMsg

	if message and message ~= '' then
		ESX.TextUI(message)
	end
end

function Mechanic.closeInteractionUI()
	ESX.CloseContext()
	ESX.HideUI()
end
