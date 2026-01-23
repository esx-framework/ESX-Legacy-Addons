local playersProcessingCannabis = {}
local outofbound = true

local spawnedWeedPlants = {}
local maxWeedPlants = 10
local weedFieldCoords = Config.CircleZones.WeedField.coords

local playerPoints = {}

local function getPlayerPoints(identifier)
	return playerPoints[identifier] or 0
end

local function addPlayerPoints(identifier, points)
	playerPoints[identifier] = getPlayerPoints(identifier) + points
end

local function validateProcessCannabis(src)
	local eCoords = Config.CircleZones.WeedProcessing.coords
	local pCoords = GetEntityCoords(GetPlayerPed(src))
	local dist = #(pCoords - eCoords)
	if dist <= 5 then return true end
end

local function foundExploiter(src, reason)
	-- ADD YOUR BAN EVENT HERE UNTIL THEN IT WILL ONLY KICK THE PLAYER --
	DropPlayer(src, reason)
end

RegisterServerEvent("esx_drugs:sellDrug")
AddEventHandler("esx_drugs:sellDrug", function(itemName, amount)
	local xPlayer = ESX.Player(source)
	local price = Config.DrugDealerItems[itemName]
	local xItem = xPlayer.getInventoryItem(itemName)
	local identifier = xPlayer.getIdentifier()
	if type(amount) ~= "number" or type(itemName) ~= "string" then
		print(("esx_drugs: %s attempted to sell with invalid input type!"):format(identifier))
		foundExploiter(xPlayer.src, "SellDrugs Event Trigger")
		return
	end
	if not price then
		print(("esx_drugs: %s attempted to sell an invalid drug!"):format(identifier))
		return
	end
	if amount < 0 then
		print(("esx_drugs: %s attempted to sell an minus amount!"):format(identifier))
		return
	end
	if xItem == nil or xItem.count < amount then
		xPlayer.showNotification(TranslateCap("dealer_notenough"))
		return
	end
	price = ESX.Math.Round(price * amount)
	
	if Config.UsePointsSystem then
		local pointsEarned = Config.PointsPerSale[itemName] or 0
		pointsEarned = pointsEarned * amount
		addPlayerPoints(identifier, pointsEarned)
		xPlayer.showNotification(TranslateCap("dealer_sold_points", amount, xItem.label, pointsEarned))
	else
		if Config.GiveBlack then
			xPlayer.addAccountMoney("black_money", price, "Drugs Sold")
		else
			xPlayer.addMoney(price, "Drugs Sold")
		end
		xPlayer.showNotification(TranslateCap("dealer_sold", amount, xItem.label, ESX.Math.GroupDigits(price)))
	end
	
	xPlayer.removeInventoryItem(xItem.name, amount)
end)

ESX.RegisterServerCallback("esx_drugs:buyLicense", function(source, cb, licenseName)
	local xPlayer = ESX.Player(source)
	local license = Config.LicensePrices[licenseName]
	if license then
		if xPlayer.getMoney() >= license.price then
			xPlayer.removeMoney(license.price)
			TriggerEvent("esx_license:addLicense", source, licenseName, function()
				cb(true)
			end)
		else
			cb(false)
		end
	else
		print(("esx_drugs: %s attempted to buy an invalid license!"):format(xPlayer.getIdentifier()))
		cb(false)
	end
end)

ESX.RegisterServerCallback("esx_drugs:canPickUp", function(source, cb, item)
	local xPlayer = ESX.Player(source)
	local qty = math.random(5,10)
	cb(xPlayer.canCarryItem(item, qty), qty)
end)

RegisterServerEvent("esx_drugs:outofbound")
AddEventHandler("esx_drugs:outofbound", function()
	outofbound = true
end)

ESX.RegisterServerCallback("esx_drugs:cannabis_count", function(source, cb)
	local xPlayer = ESX.Player(source)
	local xCannabis = xPlayer.getInventoryItem("cannabis").count
	cb(xCannabis)
end)

RegisterServerEvent("esx_drugs:processCannabis")
AddEventHandler("esx_drugs:processCannabis", function()
    local src = source
    local identifier = GetPlayerIdentifiers(src)[1]

    if playersProcessingCannabis[src] then
        print(("[esx_drugs] %s attempted to exploit weed processing!"):format(identifier))
        return
    end

    if not validateProcessCannabis(src) then
        foundExploiter(src, "Event Trigger")
        return
    end

    local xPlayer = ESX.Player(src)
    if not xPlayer then return end

    local xCannabis = xPlayer.getInventoryItem("cannabis")

    if xCannabis.count < 3 then
        xPlayer.showNotification(TranslateCap("weed_processingenough"))
        return
    end

    playersProcessingCannabis[src] = ESX.SetTimeout(Config.Delays.WeedProcessing, function()

        if xPlayer.getInventoryItem("cannabis").count < 3 then
            xPlayer.showNotification(TranslateCap("weed_processingenough"))
            return
        end

        if not xPlayer.canSwapItem("cannabis", 3, "marijuana", 1) then
            xPlayer.showNotification(TranslateCap("weed_processingfull"))
            return
        end

        xPlayer.removeInventoryItem("cannabis", 3)
        xPlayer.addInventoryItem("marijuana", 1)
        xPlayer.showNotification(TranslateCap("weed_processed"))
		playersProcessingCannabis[src] = nil
		
    end)
end)

function CancelProcessing(playerId)
	if playersProcessingCannabis[playerId] then
		ESX.ClearTimeout(playersProcessingCannabis[playerId])
		playersProcessingCannabis[playerId] = nil
	end
end

RegisterServerEvent("esx_drugs:cancelProcessing")
AddEventHandler("esx_drugs:cancelProcessing", function()
	CancelProcessing(source)
end)

local function generateWeedCoord()
	local weedCoordX, weedCoordY
	local modX = math.random(-90, 90)
	local modY = math.random(-90, 90)
	weedCoordX = weedFieldCoords.x + modX
	weedCoordY = weedFieldCoords.y + modY
	return vector3(weedCoordX, weedCoordY, weedFieldCoords.z)
end

local function validateWeedCoord(plantCoord)
	for plantId, plantData in pairs(spawnedWeedPlants) do
		if plantData.active and #(plantCoord - plantData.coords) < 5 then
			return false
		end
	end
	if #(plantCoord - weedFieldCoords) > 50 then
		return false
	end
	return true
end

local function spawnWeedPlant()
    local attempts = 0
    local maxAttempts = 50
    while attempts < maxAttempts do
        local coords = generateWeedCoord()
        if validateWeedCoord(coords) then
            local plantId = tostring(os.time()) .. "_" .. math.random(1000, 9999)
            local modelHash = GetHashKey("prop_weed_02")
            local weedObject = CreateObjectNoOffset(modelHash, coords.x, coords.y, coords.z - 1, true, true, true)
            if weedObject then
                FreezeEntityPosition(weedObject, true)
                Entity(weedObject).state.plantId = plantId
                Entity(weedObject).state.active = true
                spawnedWeedPlants[plantId] = {
                    id = plantId,
                    coords = coords,
                    networkId = weedObject,
                    active = true
                }
                return true
            end
        end
        attempts = attempts + 1
    end
    return false
end

local function removeWeedPlant(plantId)
	if spawnedWeedPlants[plantId] then
		local obj = spawnedWeedPlants[plantId].networkId
		if obj and DoesEntityExist(obj) then
			DeleteEntity(obj)
		end
		spawnedWeedPlants[plantId] = nil
		return true
	end
	return false
end

CreateThread(function()
    Wait(5000)
    for _, plantData in pairs(spawnedWeedPlants) do
        if plantData.networkId and DoesEntityExist(plantData.networkId) then
            DeleteEntity(plantData.networkId)
        end
    end
    spawnedWeedPlants = {}
    local spawnedCount = 0
    for i = 1, maxWeedPlants do
        if spawnWeedPlant() then
            spawnedCount = spawnedCount + 1
        end
        Wait(100)
    end
end)

RegisterServerEvent("esx_drugs:pickupWeedPlant")
AddEventHandler("esx_drugs:pickupWeedPlant", function(plantId, qty)
	local src = source
	local xPlayer = ESX.Player(src)
	if spawnedWeedPlants[plantId] and spawnedWeedPlants[plantId].active then
		if xPlayer.canCarryItem("cannabis", qty) then
			spawnedWeedPlants[plantId].active = false
			if spawnedWeedPlants[plantId].networkId and DoesEntityExist(spawnedWeedPlants[plantId].networkId) then
				Entity(spawnedWeedPlants[plantId].networkId).state.active = false
			end
			xPlayer.addInventoryItem("cannabis", qty)
			xPlayer.showNotification(TranslateCap("weed_pickedup"))
			removeWeedPlant(plantId)
			SetTimeout(10000, function()
				spawnWeedPlant()
			end)
		else
			xPlayer.showNotification(TranslateCap("weed_inventoryfull"))
		end
	end
end)

AddEventHandler("esx:playerDropped", function(playerId, reason)
	CancelProcessing(playerId)
end)

RegisterServerEvent("esx:onPlayerDeath")
AddEventHandler("esx:onPlayerDeath", function(data)
	CancelProcessing(source)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for _, plantData in pairs(spawnedWeedPlants) do
            if plantData.networkId and DoesEntityExist(plantData.networkId) then
                DeleteEntity(plantData.networkId)
            end
        end
        spawnedWeedPlants = {}
    end
end)

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        CreateThread(function()
            Wait(2000)
            for _, plantData in pairs(spawnedWeedPlants) do
                if plantData.networkId and DoesEntityExist(plantData.networkId) then
                    DeleteEntity(plantData.networkId)
                end
            end
            spawnedWeedPlants = {}
            local spawnedCount = 0
            for i = 1, maxWeedPlants do
                if spawnWeedPlant() then
                    spawnedCount = spawnedCount + 1
                end
                Wait(100)
            end
        end)
    end
end)