local ESX = exports['es_extended']:getSharedObject()

local function getXPlayer(src)
    return ESX.GetPlayerFromId and ESX.GetPlayerFromId(src) or (ESX.Player and ESX.Player(src)) or nil
end

local function getJob(xPlayer) return xPlayer and (xPlayer.job or xPlayer.getJob and xPlayer.getJob()) end
local function getIdentifier(xPlayer) return xPlayer and (xPlayer.identifier or xPlayer.getIdentifier and xPlayer.getIdentifier()) end
local function playerHasWeapon(xPlayer, name) return xPlayer.hasWeapon and xPlayer.hasWeapon(name) or false end

local function safeNumber(n, fallback)
    n = tonumber(n)
    if not n or n ~= n or n == math.huge or n == -math.huge then return tonumber(fallback) or 0 end
    return n
end

local function getPaymentAccount()
    if Config and Config.ArmoryAccount == 'bank' then return 'bank' end
    return 'money'
end

CreateThread(function()
    if Config and Config.EnableESXService and GetResourceState('esx_service') == 'started' then
        if safeNumber(Config.MaxInService, -1) ~= -1 then
            TriggerEvent('esx_service:activateService', 'police', safeNumber(Config.MaxInService, 10))
        end
    end

    if GetResourceState('esx_phone') == 'started' then
        TriggerEvent('esx_phone:registerNumber', 'police', TranslateCap('alert_police'), true, true)
    end

    if GetResourceState('esx_society') == 'started' then
        TriggerEvent('esx_society:registerSociety', 'police', TranslateCap('society_police'),
            'society_police', 'society_police', 'society_police', { type = 'public' })
    end
end)

local CONST_OK, CONST = pcall(require, 'shared/constants')
local PERMS_OK, PERMS = pcall(require, 'shared/permissions')

local JOB_NAME = (CONST_OK and CONST and CONST.JOB_NAME) or 'police'

local function isPolice(xPlayer)
    local job = getJob(xPlayer)
    return job and (job.name == JOB_NAME)
end

local function hasPerm(xPlayer, perm)
    if not isPolice(xPlayer) then return false end
    if not (PERMS_OK and PERMS and PERMS.jobs and PERMS.jobs[JOB_NAME]) then
        return true
    end
    local job = getJob(xPlayer)
    local g = job and job.grade or job and job.grade_name
    local info
    if type(g) == 'number' then
        info = PERMS.jobs[JOB_NAME].grades and PERMS.jobs[JOB_NAME].grades[g]
    else
        info = PERMS.jobs[JOB_NAME].grades_by_name and PERMS.jobs[JOB_NAME].grades_by_name[g]
    end
    return info and info[perm] == true
end

local function warnExploit(xPlayer, what)
    print(('[^3WARNING^7] Player ^5%s^7 attempted: %s'):format(xPlayer and xPlayer.source or 'unknown', tostring(what)))
end

RegisterNetEvent('esx_policejob:confiscatePlayerItem', function(target, itemType, itemName, amount)
    local src = source
    local sourceXPlayer = getXPlayer(src)
    local targetXPlayer = getXPlayer(target)
    if not sourceXPlayer or not targetXPlayer then return end
    if not hasPerm(sourceXPlayer, 'canSearch') then return warnExploit(sourceXPlayer, 'Confiscation') end

    amount = safeNumber(amount, 0)
    if itemType == 'item_standard' then
        local tItem = targetXPlayer.getInventoryItem(itemName)
        if amount > 0 and tItem and tItem.count >= amount then
            if sourceXPlayer.canCarryItem(itemName, amount) then
                targetXPlayer.removeInventoryItem(itemName, amount)
                sourceXPlayer.addInventoryItem(itemName, amount)
                sourceXPlayer.showNotification(TranslateCap('you_confiscated', amount, (sourceXPlayer.getInventoryItem(itemName).label or itemName), targetXPlayer.getName()))
                targetXPlayer.showNotification(TranslateCap('got_confiscated', amount, (tItem.label or itemName), sourceXPlayer.getName()))
            else
                sourceXPlayer.showNotification(TranslateCap('quantity_invalid'))
            end
        else
            sourceXPlayer.showNotification(TranslateCap('quantity_invalid'))
        end

    elseif itemType == 'item_account' then
        local acc = targetXPlayer.getAccount(itemName)
        if amount > 0 and acc and acc.money >= amount then
            targetXPlayer.removeAccountMoney(itemName, amount, "Confiscated")
            sourceXPlayer.addAccountMoney(itemName, amount, "Confiscated")
            sourceXPlayer.showNotification(TranslateCap('you_confiscated_account', amount, itemName, targetXPlayer.getName()))
            targetXPlayer.showNotification(TranslateCap('got_confiscated_account', amount, itemName, sourceXPlayer.getName()))
        else
            sourceXPlayer.showNotification(TranslateCap('quantity_invalid'))
        end

    elseif itemType == 'item_weapon' then
        local ammo = amount or 0
        if playerHasWeapon(targetXPlayer, itemName) then
            targetXPlayer.removeWeapon(itemName)
            sourceXPlayer.addWeapon(itemName, ammo)
            sourceXPlayer.showNotification(TranslateCap('you_confiscated_weapon', ESX.GetWeaponLabel(itemName), targetXPlayer.getName(), ammo))
            targetXPlayer.showNotification(TranslateCap('got_confiscated_weapon', ESX.GetWeaponLabel(itemName), ammo, sourceXPlayer.getName()))
        else
            sourceXPlayer.showNotification(TranslateCap('quantity_invalid'))
        end
    end
end)

RegisterNetEvent('esx_policejob:handcuff', function(target)
    local xPlayer = getXPlayer(source); if not xPlayer then return end
    if hasPerm(xPlayer, 'canCuff') then
        TriggerClientEvent('esx_policejob:handcuff', target)
    else
        warnExploit(xPlayer, 'Handcuffs')
    end
end)

RegisterNetEvent('esx_policejob:cuffsState', function(isCuffed)
    local src = source
    TriggerClientEvent('esx_policejob:cuffsSync', -1, src, isCuffed and true or false)
end)

RegisterNetEvent('esx_policejob:drag', function(target)
    local xPlayer = getXPlayer(source)
    if xPlayer and isPolice(xPlayer) then
        TriggerClientEvent('esx_policejob:drag', target, source)
    else
        warnExploit(xPlayer, 'Dragging')
    end
end)

RegisterNetEvent('esx_policejob:putInVehicle', function(target)
    local xPlayer = getXPlayer(source)
    if xPlayer and isPolice(xPlayer) then
        TriggerClientEvent('esx_policejob:putInVehicle', target)
    else
        warnExploit(xPlayer, 'PutInVehicle')
    end
end)

RegisterNetEvent('esx_policejob:OutVehicle', function(target)
    local xPlayer = getXPlayer(source)
    if xPlayer and isPolice(xPlayer) then
        TriggerClientEvent('esx_policejob:OutVehicle', target)
    else
        warnExploit(xPlayer, 'OutVehicle')
    end
end)

RegisterNetEvent('esx_policejob:getStockItem', function(itemName, count)
    local xPlayer = getXPlayer(source)
    if not xPlayer or not isPolice(xPlayer) then return end
    if GetResourceState('esx_addoninventory') ~= 'started' then return end

    TriggerEvent('esx_addoninventory:getSharedInventory', 'society_police', function(inventory)
        local inventoryItem = inventory.getItem(itemName)
        count = safeNumber(count, 0)
        if count > 0 and inventoryItem and inventoryItem.count >= count then
            if xPlayer.canCarryItem(itemName, count) then
                inventory.removeItem(itemName, count)
                xPlayer.addInventoryItem(itemName, count)
                xPlayer.showNotification(TranslateCap('have_withdrawn', count, inventoryItem.name))
            else
                xPlayer.showNotification(TranslateCap('quantity_invalid'))
            end
        else
            xPlayer.showNotification(TranslateCap('quantity_invalid'))
        end
    end)
end)

RegisterNetEvent('esx_policejob:putStockItems', function(itemName, count)
    local xPlayer = getXPlayer(source)
    if not xPlayer or not isPolice(xPlayer) then return end
    if GetResourceState('esx_addoninventory') ~= 'started' then return end

    local srcItem = xPlayer.getInventoryItem(itemName)
    TriggerEvent('esx_addoninventory:getSharedInventory', 'society_police', function(inventory)
        count = safeNumber(count, 0)
        if srcItem and srcItem.count >= count and count > 0 then
            xPlayer.removeInventoryItem(itemName, count)
            inventory.addItem(itemName, count)
            xPlayer.showNotification(TranslateCap('have_deposited', count, srcItem.label or itemName))
        else
            xPlayer.showNotification(TranslateCap('quantity_invalid'))
        end
    end)
end)

ESX.RegisterServerCallback('esx_policejob:getOtherPlayerData', function(source, cb, target, notify)
    local xTarget = getXPlayer(target)
    if not xTarget then return cb(nil) end

    if notify and GetResourceState('esx_status') == 'started' then
        xTarget.showNotification(TranslateCap('being_searched'))
    end

    local job = getJob(xTarget)
    local data = {
        name      = xTarget.getName and xTarget.getName() or GetPlayerName(target),
        job       = job and (job.label or job.name) or 'Unknown',
        grade     = job and (job.grade_label or job.grade_name or job.grade) or '',
        inventory = xTarget.getInventory and xTarget.getInventory() or {},
        accounts  = xTarget.getAccounts and xTarget.getAccounts() or {},
        weapons   = xTarget.getLoadout and xTarget.getLoadout() or {}
    }

    local function finish()
        if Config.EnableLicenses and GetResourceState('esx_license') == 'started' then
            TriggerEvent('esx_license:getLicenses', target, function(licenses)
                data.licenses = licenses
                cb(data)
            end)
        else
            cb(data)
        end
    end

    if Config.EnableESXIdentity then
        data.dob    = xTarget.get and xTarget.get('dateofbirth') or nil
        data.height = xTarget.get and xTarget.get('height') or nil
        local sex = xTarget.get and xTarget.get('sex') or nil
        data.sex = (sex == 'm' or sex == 0) and 'male' or 'female'
    end

    if GetResourceState('esx_status') == 'started' then
        TriggerEvent('esx_status:getStatus', target, 'drunk', function(status)
            if status then data.drunk = ESX.Math.Round(status.percent) end
            finish()
        end)
    else
        finish()
    end
end)

local fineCache = {}
ESX.RegisterServerCallback('esx_policejob:getFineList', function(source, cb, category)
    category = safeNumber(category, 0)
    if fineCache[category] then return cb(fineCache[category]) end
    if not MySQL or not MySQL.query then
        fineCache[category] = {}
        return cb({})
    end
    MySQL.query('SELECT id,label,amount FROM fine_types WHERE category = ?', { category }, function(rows)
        fineCache[category] = rows or {}
        cb(fineCache[category])
    end)
end)

ESX.RegisterServerCallback('esx_policejob:getVehicleInfos', function(source, cb, plate)
    plate = tostring(plate or ''):upper()
    local info = { plate = plate, owner = false }
    if not MySQL or not MySQL.query then return cb(info) end

    if Config.EnableESXIdentity then
        MySQL.single('SELECT users.firstname, users.lastname FROM owned_vehicles JOIN users ON owned_vehicles.owner = users.identifier WHERE plate = ?', { plate }, function(result)
            if result then info.owner = ('%s %s'):format(result.firstname, result.lastname) end
            cb(info)
        end)
    else
        MySQL.single('SELECT owner FROM owned_vehicles WHERE plate = ?', { plate }, function(result)
            if result and result.owner then
                local xOwner = ESX.GetPlayerFromIdentifier and ESX.GetPlayerFromIdentifier(result.owner) or nil
                info.owner = (xOwner and (xOwner.getName and xOwner.getName())) or false
            end
            cb(info)
        end)
    end
end)

ESX.RegisterServerCallback('esx_policejob:getArmoryWeapons', function(source, cb)
    if GetResourceState('esx_datastore') ~= 'started' then return cb({}) end
    TriggerEvent('esx_datastore:getSharedDataStore', 'society_police', function(store)
        local weapons = store.get('weapons')
        if weapons == nil then weapons = {} end
        cb(weapons)
    end)
end)

ESX.RegisterServerCallback('esx_policejob:addArmoryWeapon', function(source, cb, weaponName, removeWeapon)
    if GetResourceState('esx_datastore') ~= 'started' then return cb() end
    local xPlayer = getXPlayer(source)
    if removeWeapon then xPlayer.removeWeapon(weaponName) end
    TriggerEvent('esx_datastore:getSharedDataStore', 'society_police', function(store)
        local weapons = store.get('weapons') or {}
        local found = false
        for i=1,#weapons do
            if weapons[i].name == weaponName then
                weapons[i].count = (weapons[i].count or 0) + 1
                found = true
                break
            end
        end
        if not found then weapons[#weapons+1] = { name = weaponName, count = 1 } end
        store.set('weapons', weapons)
        cb()
    end)
end)

ESX.RegisterServerCallback('esx_policejob:removeArmoryWeapon', function(source, cb, weaponName)
    if GetResourceState('esx_datastore') ~= 'started' then
        local x = getXPlayer(source); if x then x.addWeapon(weaponName, 250) end
        return cb()
    end
    local xPlayer = getXPlayer(source)
    xPlayer.addWeapon(weaponName, 500)
    TriggerEvent('esx_datastore:getSharedDataStore', 'society_police', function(store)
        local weapons = store.get('weapons') or {}
        local found = false
        for i=1,#weapons do
            if weapons[i].name == weaponName then
                weapons[i].count = math.max(0, (weapons[i].count or 0) - 1)
                found = true
                break
            end
        end
        if not found then weapons[#weapons+1] = { name = weaponName, count = 0 } end
        store.set('weapons', weapons)
        cb()
    end)
end)

ESX.RegisterServerCallback('esx_policejob:buyWeapon', function(source, cb, weaponName, buyType, componentNum)
    local xPlayer = getXPlayer(source)
    if not xPlayer then cb(false) return end

    local job = getJob(xPlayer)
    if not job or job.name ~= JOB_NAME then cb(false) return end

    local gradeName = job.grade_name or job.grade
    local authList = Config.AuthorizedWeapons and Config.AuthorizedWeapons[gradeName] or nil
    if not authList then cb(false) return end

    local selected
    for _,v in ipairs(authList) do
        if v.weapon == weaponName then selected = v break end
    end
    if not selected then
        warnExploit(xPlayer, ('Buy invalid weapon %s'):format(weaponName))
        cb(false); return
    end

    local price = 0
    local account = getPaymentAccount()

    if buyType == 1 then
        price = safeNumber(selected.price or 0, 0)
        if price < 0 then price = 0 end

        if price > 0 then
            local acc = xPlayer.getAccount(account)
            local balance = acc and acc.money or 0
            if balance < price then cb(false) return end
            xPlayer.removeAccountMoney(account, price, "Weapon Bought")
        end

        if not playerHasWeapon(xPlayer, weaponName) then
            xPlayer.addWeapon(weaponName, 100)
        end
        cb(true)
        return

    elseif buyType == 2 then
        local compPrice = selected.components and selected.components[componentNum] or 0
        price = safeNumber(compPrice, 0)
        if price < 0 then price = 0 end

        local _, weaponDef = ESX.GetWeapon(weaponName)
        local component = (weaponDef and weaponDef.components and weaponDef.components[componentNum]) or nil
        if not component then
            warnExploit(xPlayer, ('Buy invalid component #%s for %s'):format(tostring(componentNum), weaponName))
            cb(false) return
        end

        if price > 0 then
            local acc = xPlayer.getAccount(account)
            local balance = acc and acc.money or 0
            if balance < price then cb(false) return end
            xPlayer.removeAccountMoney(account, price, "Weapon Component Bought")
        end

        if xPlayer.addWeaponComponent then
            xPlayer.addWeaponComponent(weaponName, component.name)
        else
            TriggerClientEvent('esx:addWeaponComponent', source, weaponName, component.name)
        end

        cb(true)
        return
    end

    cb(false)
end)

local function getPriceFromHash(vehicleHash, jobGrade, typeName)
    local list = (Config.AuthorizedVehicles[typeName] and Config.AuthorizedVehicles[typeName][jobGrade]) or {}
    for i=1, #list do
        if GetHashKey(list[i].model) == vehicleHash then
            return safeNumber(list[i].price, 0)
        end
    end
    return 0
end

ESX.RegisterServerCallback('esx_policejob:buyJobVehicle', function(source, cb, vehicleProps, typeName)
    local xPlayer = getXPlayer(source); if not xPlayer then cb(false) return end
    local job = getJob(xPlayer); if not job then cb(false) return end
    local price = getPriceFromHash(vehicleProps.model, job.grade_name or job.grade, typeName)

    if price <= 0 then
        warnExploit(xPlayer, ('Buy invalid vehicle %s'):format(tostring(vehicleProps.model)))
        cb(false); return
    end

    local account = getPaymentAccount()
    local acc = xPlayer.getAccount(account)
    local balance = acc and acc.money or 0
    if balance < price then cb(false) return end

    xPlayer.removeAccountMoney(account, price, "Job Vehicle Bought")

    if MySQL and MySQL.insert then
        MySQL.insert('INSERT INTO owned_vehicles (owner, vehicle, plate, type, job, `stored`) VALUES (?, ?, ?, ?, ?, ?)',
            { getIdentifier(xPlayer), json.encode(vehicleProps), vehicleProps.plate, typeName, job.name, true },
            function() cb(true) end
        )
    else
        cb(true)
    end
end)

ESX.RegisterServerCallback('esx_policejob:storeNearbyVehicle', function(source, cb, plates)
    local xPlayer = getXPlayer(source); if not xPlayer then cb(false) return end
    local job = getJob(xPlayer); if not job then cb(false) return end
    if not MySQL or not MySQL.scalar or not MySQL.update then cb(false) return end

    local plate = MySQL.scalar.await('SELECT plate FROM owned_vehicles WHERE owner = ? AND plate IN (?) AND job = ?',
        { getIdentifier(xPlayer), plates, job.name })

    if plate then
        MySQL.update('UPDATE owned_vehicles SET `stored` = true WHERE owner = ? AND plate = ? AND job = ?',
            { getIdentifier(xPlayer), plate, job.name },
            function(rowsChanged)
                if rowsChanged == 0 then cb(false) else cb(plate) end
            end
        )
    else
        cb(false)
    end
end)

ESX.RegisterServerCallback('esx_policejob:getStockItems', function(source, cb)
    if GetResourceState('esx_addoninventory') ~= 'started' then return cb({}) end
    TriggerEvent('esx_addoninventory:getSharedInventory', 'society_police', function(inventory)
        cb(inventory.items or {})
    end)
end)

ESX.RegisterServerCallback('esx_policejob:getPlayerInventory', function(source, cb)
    local xPlayer = getXPlayer(source)
    if not xPlayer then return cb({ items = {} }) end
    local items = xPlayer.getInventory and xPlayer.getInventory(false) or {}
    cb({ items = items })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if GetResourceState('esx_phone') == 'started' then
            TriggerEvent('esx_phone:removeNumber', 'police')
        end
    end
end)