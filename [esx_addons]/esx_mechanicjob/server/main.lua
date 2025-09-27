
local PlayersHarvesting, PlayersCrafting = {}, {}

if Config.MaxInService ~= -1 then
	TriggerEvent('esx_service:activateService', 'mechanic', Config.MaxInService)
end

TriggerEvent('esx_society:registerSociety', 'mechanic', 'mechanic', 'society_mechanic', 'society_mechanic', 'society_mechanic', {type = 'private'})

local function Harvest(source, itemType)
	SetTimeout(4000, function()
		if PlayersHarvesting[source] and PlayersHarvesting[source].itemType == itemType then
			local xPlayer = ESX.Player(source)
			local itemQuantity = xPlayer.getInventoryItem(itemType).count

			if itemQuantity >= 5 then
				TriggerClientEvent('esx:showNotification', source, TranslateCap('you_do_not_room'))
				PlayersHarvesting[source] = nil
			else
				TriggerClientEvent('esx:showNotification', source, TranslateCap('recovery_' .. itemType))
				xPlayer.addInventoryItem(itemType, 1)
				Harvest(source, itemType)
			end
		end
	end)
end

RegisterServerEvent('esx_mechanicjob:startHarvest')
AddEventHandler('esx_mechanicjob:startHarvest', function(itemType)
	local source = source
	local xPlayer = ESX.Player(source)
	if xPlayer.getJob().name == 'mechanic' and not PlayersHarvesting[source] then
		PlayersHarvesting[source] = { itemType = itemType }
		Harvest(source, itemType)
	end
end)

RegisterServerEvent('esx_mechanicjob:stopHarvest')
AddEventHandler('esx_mechanicjob:stopHarvest', function()
	local source = source
	PlayersHarvesting[source] = nil
end)

local function Craft(source, itemType)
	SetTimeout(4000, function()
		if PlayersCrafting[source] and PlayersCrafting[source].itemType == itemType then
			local xPlayer = ESX.Player(source)
			
			local ingredients = {
				['blowpipe'] = 'gazbottle',
				['fixkit'] = 'fixtool',
				['carokit'] = 'carotool'
			}
			local ingredient = ingredients[itemType]
			local ingredientQuantity = xPlayer.getInventoryItem(ingredient).count
			
			if ingredientQuantity <= 0 then
				TriggerClientEvent('esx:showNotification', source, TranslateCap('not_enough_' .. ingredient))
				PlayersCrafting[source] = nil
			else
				TriggerClientEvent('esx:showNotification', source, TranslateCap('assembling_' .. itemType))
				xPlayer.removeInventoryItem(ingredient, 1)
				xPlayer.addInventoryItem(itemType, 1)
				Craft(source, itemType)
			end
		end
	end)
end

RegisterServerEvent('esx_mechanicjob:startCraft')
AddEventHandler('esx_mechanicjob:startCraft', function(itemType)
	local source = source
	local xPlayer = ESX.Player(source)
	if xPlayer.getJob().name == 'mechanic' and not PlayersCrafting[source] then
		PlayersCrafting[source] = { itemType = itemType }
		Craft(source, itemType)
	end
end)

RegisterServerEvent('esx_mechanicjob:stopCraft')
AddEventHandler('esx_mechanicjob:stopCraft', function()
	local source = source
	PlayersCrafting[source] = nil
end)

RegisterServerEvent('esx_mechanicjob:onNPCJobMissionCompleted')
AddEventHandler('esx_mechanicjob:onNPCJobMissionCompleted', function()
	local source = source
	local xPlayer = ESX.Player(source)
	local total   = math.random(Config.NPCJobEarnings.min, Config.NPCJobEarnings.max);

	if xPlayer.getJob().grade >= 3 then
		total = total * 2
	end

	TriggerEvent('esx_addonaccount:getSharedAccount', 'society_mechanic', function(account)
		account.addMoney(total)
	end)

	TriggerClientEvent("esx:showNotification", source, TranslateCap('your_comp_earned').. total)
end)

ESX.RegisterUsableItem('blowpipe', function(source)
	local source = source
	local xPlayer  = ESX.Player(source)

	xPlayer.removeInventoryItem('blowpipe', 1)

	TriggerClientEvent('esx_mechanicjob:onHijack', source)
	TriggerClientEvent('esx:showNotification', source, TranslateCap('you_used_blowtorch'))
end)

ESX.RegisterUsableItem('fixkit', function(source)
	local source = source
	local xPlayer  = ESX.Player(source)

	xPlayer.removeInventoryItem('fixkit', 1)

	TriggerClientEvent('esx_mechanicjob:onFixkit', source)
	TriggerClientEvent('esx:showNotification', source, TranslateCap('you_used_repair_kit'))
end)

ESX.RegisterUsableItem('carokit', function(source)
	local source = source
	local xPlayer  = ESX.Player(source)

	xPlayer.removeInventoryItem('carokit', 1)

	TriggerClientEvent('esx_mechanicjob:onCarokit', source)
	TriggerClientEvent('esx:showNotification', source, TranslateCap('you_used_body_kit'))
end)

RegisterServerEvent('esx_mechanicjob:getStockItem')
AddEventHandler('esx_mechanicjob:getStockItem', function(itemName, count)
	local xPlayer = ESX.Player(source)

	TriggerEvent('esx_addoninventory:getSharedInventory', 'society_mechanic', function(inventory)
		local item = inventory.getItem(itemName)

		if count > 0 and item.count >= count then

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

ESX.RegisterServerCallback('esx_mechanicjob:getStockItems', function(source, cb)
	TriggerEvent('esx_addoninventory:getSharedInventory', 'society_mechanic', function(inventory)
		cb(inventory.items)
	end)
end)

RegisterServerEvent('esx_mechanicjob:putStockItems')
AddEventHandler('esx_mechanicjob:putStockItems', function(itemName, count)
	local xPlayer = ESX.Player(source)

	TriggerEvent('esx_addoninventory:getSharedInventory', 'society_mechanic', function(inventory)
		local item = inventory.getItem(itemName)
		local playerItemCount = xPlayer.getInventoryItem(itemName).count

		if item.count >= 0 and count <= playerItemCount then
			xPlayer.removeInventoryItem(itemName, count)
			inventory.addItem(itemName, count)
		else
			xPlayer.showNotification(TranslateCap('invalid_quantity'))
		end

		xPlayer.showNotification(TranslateCap('have_deposited', count, item.label))
	end)
end)

ESX.RegisterServerCallback('esx_mechanicjob:getPlayerInventory', function(source, cb)
	local xPlayer    = ESX.Player(source)
	local items      = xPlayer.getInventory(false)

	cb({items = items})
end)