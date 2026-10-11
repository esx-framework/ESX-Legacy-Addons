-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local MechanicJob = ESXMechanicJob

RegisterServerEvent('esx_mechanicjob:getStockItem')
AddEventHandler('esx_mechanicjob:getStockItem', function(itemName, count)
	local source = source
	if MechanicJob.rejectRateLimited(source, 'esx_mechanicjob:getStockItem', 500) then
		return
	end

	local xPlayer = MechanicJob.getMechanicPlayer(source)
	count = MechanicJob.normalizeItemCount(count)

	if not xPlayer or type(itemName) ~= 'string' or not count then
		return
	end

	TriggerEvent('esx_addoninventory:getSharedInventory', 'society_mechanic', function(inventory)
		if not inventory then
			return
		end

		xPlayer = MechanicJob.getMechanicPlayer(source)
		if not xPlayer then
			return
		end

		local item = inventory.getItem(itemName)
		if not item then
			xPlayer.showNotification(TranslateCap('invalid_quantity'))
			return
		end

		if (item.count or 0) >= count then
			if xPlayer.canCarryItem(itemName, count) then
				inventory.removeItem(itemName, count)
				xPlayer.addInventoryItem(itemName, count)
				xPlayer.showNotification(TranslateCap('have_withdrawn', count, item.label))
			else
				xPlayer.showNotification(TranslateCap('player_cannot_hold'))
			end
		else
			xPlayer.showNotification(TranslateCap('invalid_quantity'))
		end
	end)
end)

xLib.callback.registerCompat('esx_mechanicjob:getStockItems', function(source, cb)
	if MechanicJob.rejectRateLimited(source, 'esx_mechanicjob:getStockItems', 500) then
		cb({})
		return
	end

	if not MechanicJob.getMechanicPlayer(source) then
		cb({})
		return
	end

	TriggerEvent('esx_addoninventory:getSharedInventory', 'society_mechanic', function(inventory)
		if not inventory then
			cb({})
			return
		end

		cb(inventory.items)
	end)
end)

RegisterServerEvent('esx_mechanicjob:putStockItems')
AddEventHandler('esx_mechanicjob:putStockItems', function(itemName, count)
	local source = source
	if MechanicJob.rejectRateLimited(source, 'esx_mechanicjob:putStockItems', 500) then
		return
	end

	local xPlayer = MechanicJob.getMechanicPlayer(source)
	count = MechanicJob.normalizeItemCount(count)

	if not xPlayer or type(itemName) ~= 'string' or not count then
		return
	end

	TriggerEvent('esx_addoninventory:getSharedInventory', 'society_mechanic', function(inventory)
		if not inventory then
			return
		end

		xPlayer = MechanicJob.getMechanicPlayer(source)
		if not xPlayer then
			return
		end

		local item = inventory.getItem(itemName)
		if not item then
			xPlayer.showNotification(TranslateCap('invalid_quantity'))
			return
		end

		local playerItem = xPlayer.getInventoryItem(itemName)
		local playerItemCount = playerItem and playerItem.count or 0

		if count <= playerItemCount then
			xPlayer.removeInventoryItem(itemName, count)
			inventory.addItem(itemName, count)
			xPlayer.showNotification(TranslateCap('have_deposited', count, item.label))
		else
			xPlayer.showNotification(TranslateCap('invalid_quantity'))
		end
	end)
end)

xLib.callback.registerCompat('esx_mechanicjob:getPlayerInventory', function(source, cb)
	if MechanicJob.rejectRateLimited(source, 'esx_mechanicjob:getPlayerInventory', 500) then
		cb({items = {}})
		return
	end

	local xPlayer = MechanicJob.getMechanicPlayer(source)
	if not xPlayer then
		cb({items = {}})
		return
	end

	local items = xPlayer.getInventory(false) or {}

	cb({items = items})
end)
