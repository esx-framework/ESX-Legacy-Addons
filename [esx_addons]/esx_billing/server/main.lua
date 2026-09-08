local BillingCooldowns = {}
local BillingDailyTotals = {}
local BillingLocks = {}
local PendingBillConfirmations = {}

local function normalizeAmount(amount, maxAmount)
	amount = tonumber(amount)

	if not amount then return nil end

	amount = math.floor(amount)
	maxAmount = tonumber(maxAmount) or Config.MaxBillAmount or 100000

	if amount < 1 or amount > maxAmount then
		return nil
	end

	return amount
end

local function sanitizeLabel(label)
	label = tostring(label or ''):gsub('[%c]', ' ')
	label = label:gsub('^%s+', ''):gsub('%s+$', '')

	local maxLength = tonumber(Config.MaxBillLabelLength) or 80
	if #label > maxLength then
		label = label:sub(1, maxLength)
	end

	if label == '' then
		label = 'Invoice'
	end

	return label
end

local function getSocietyJob(sharedAccountName)
	if type(sharedAccountName) ~= 'string' then return nil end

	return sharedAccountName:match('^society_([%w_]+)$')
end

local function isNearPlayer(source, target, distance)
	local nearby = xLib.player.isNearPlayer(source, target, distance or Config.BillingDistance or 10.0)
	return nearby
end

local function canIssueSocietyBill(xPlayer, sharedAccountName)
	local jobName = getSocietyJob(sharedAccountName)
	if not jobName then return false end

	local job = xPlayer.getJob()
	if not job or job.name ~= jobName then return false end

	local minimumGrades = Config.BillingMinimumGrades or {}
	local minimumGrade = tonumber(minimumGrades[jobName]) or tonumber(Config.MinimumBillingGrade) or 1
	local playerGrade = tonumber(job.grade) or 0

	return playerGrade >= minimumGrade
end

local function hasDailyQuota(senderIdentifier, amount)
	local maxDailyAmount = tonumber(Config.MaxDailyBillAmount) or 250000
	if maxDailyAmount <= 0 then return true end

	local key = ('%s:%s'):format(senderIdentifier, os.date('%Y-%m-%d'))
	local currentTotal = BillingDailyTotals[key] or 0

	return currentTotal + amount <= maxDailyAmount
end

local function addDailyAmount(senderIdentifier, amount)
	local maxDailyAmount = tonumber(Config.MaxDailyBillAmount) or 250000
	if maxDailyAmount <= 0 then return end

	local key = ('%s:%s'):format(senderIdentifier, os.date('%Y-%m-%d'))
	BillingDailyTotals[key] = (BillingDailyTotals[key] or 0) + amount
end

local function insertBill(targetIdentifier, senderIdentifier, targetType, target, label, amount)
	local insertedId = MySQL.insert.await(
		'INSERT INTO billing (identifier, sender, target_type, target, label, amount) VALUES (?, ?, ?, ?, ?, ?)',
		{ targetIdentifier, senderIdentifier, targetType, target, label, amount }
	)

	local xTarget = ESX.Player(targetIdentifier)
	if insertedId and xTarget then
		xTarget.showNotification(TranslateCap('received_invoice'))
	end

	return insertedId
end

local function billPlayerByIdentifier(targetIdentifier, senderIdentifier, sharedAccountName, label, amount)
	amount = normalizeAmount(amount)
	if not amount or type(targetIdentifier) ~= 'string' or type(senderIdentifier) ~= 'string' then return false end

	label = sanitizeLabel(label)

	if getSocietyJob(sharedAccountName) then
		local accountPromise = promise.new()
		TriggerEvent('esx_addonaccount:getSharedAccount', sharedAccountName, function(account)
			accountPromise:resolve(account)
		end)

		local account = Citizen.Await(accountPromise)
		if not account then
			print(("[^2ERROR^7] Attempted to send bill from invalid society - ^5%s^7"):format(sharedAccountName))
			return false
		end

		local insertedId = insertBill(targetIdentifier, senderIdentifier, 'society', sharedAccountName, label, amount)
		if insertedId then
			addDailyAmount(senderIdentifier, amount)
		end

		return insertedId or false
	end

	local insertedId = insertBill(targetIdentifier, senderIdentifier, 'player', senderIdentifier, label, amount)
	if insertedId then
		addDailyAmount(senderIdentifier, amount)
	end

	return insertedId or false
end

local function billPlayer(targetId, senderIdentifier, sharedAccountName, label, amount)
	local xTarget = ESX.Player(tonumber(targetId))

	if not xTarget then return false end

	return billPlayerByIdentifier(xTarget.getIdentifier(), senderIdentifier, sharedAccountName, label, amount)
end

RegisterNetEvent('esx_billing:sendBill', function(targetId, sharedAccountName, label, amount)
	local src = source
	local xPlayer = ESX.Player(src)
	local xTarget = ESX.Player(tonumber(targetId))

	amount = normalizeAmount(amount)
	label = sanitizeLabel(label)

	if not xPlayer or not xTarget or not amount or xTarget.src == src then return end
	if not canIssueSocietyBill(xPlayer, sharedAccountName) then
		return print(("[^2ERROR^7] Player ^5%s^7 attempted to send an unauthorized bill from ^5%s^7")
			:format(src, tostring(sharedAccountName)))
	end

	local now = GetGameTimer()
	local cooldown = tonumber(Config.BillingCooldown) or 3000
	if BillingCooldowns[src] and now - BillingCooldowns[src] < cooldown then return end
	BillingCooldowns[src] = now

	if not isNearPlayer(src, xTarget.src) then return end
	if not hasDailyQuota(xPlayer.getIdentifier(), amount) then return end

	local highBillAmount = tonumber(Config.HighBillConfirmationAmount) or 50000
	if amount >= highBillAmount then
		local token = ('%s:%s:%s:%s'):format(src, xTarget.src, now, math.random(100000, 999999))

		PendingBillConfirmations[token] = {
			expires = now + (tonumber(Config.HighBillConfirmationTimeout) or 30000),
			senderSource = src,
			targetSource = xTarget.src,
			targetIdentifier = xTarget.getIdentifier(),
			senderIdentifier = xPlayer.getIdentifier(),
			sharedAccountName = sharedAccountName,
			label = label,
			amount = amount
		}

		TriggerClientEvent('esx_billing:confirmHighBill', xTarget.src, token, label, amount, xPlayer.getName())
		return
	end

	billPlayerByIdentifier(xTarget.getIdentifier(), xPlayer.getIdentifier(), sharedAccountName, label, amount)
end)
exports("BillPlayer", billPlayer)

AddEventHandler('esx_billing:sendBillToIdentifier', function(targetIdentifier, sharedAccountName, label, amount)
	if not GetInvokingResource() then return end

	billPlayerByIdentifier(targetIdentifier, 'server', sharedAccountName, label, amount)
end)
exports("BillPlayerByIdentifier", billPlayerByIdentifier)

xLib.callback.registerCompat('esx_billing:respondHighBill', function(source, cb, token, accepted)
	local pendingBill = PendingBillConfirmations[token]

	if not pendingBill or pendingBill.targetSource ~= source or pendingBill.expires < GetGameTimer() then
		PendingBillConfirmations[token] = nil
		return cb(false)
	end

	PendingBillConfirmations[token] = nil
	if accepted ~= true then return cb(false) end
	if not isNearPlayer(pendingBill.senderSource, source) then return cb(false) end
	if not hasDailyQuota(pendingBill.senderIdentifier, pendingBill.amount) then return cb(false) end

	local insertedId = billPlayerByIdentifier(
		pendingBill.targetIdentifier,
		pendingBill.senderIdentifier,
		pendingBill.sharedAccountName,
		pendingBill.label,
		pendingBill.amount
	)

	cb(insertedId ~= false)
end)

xLib.callback.registerCompat('esx_billing:getBills', function(source, cb)
	local xPlayer = ESX.Player(source)
	if not xPlayer then return cb({}) end

	local result = MySQL.query.await('SELECT amount, id, label FROM billing WHERE identifier = ?', { xPlayer.getIdentifier() })
	cb(result)
end)

xLib.callback.registerCompat('esx_billing:getTargetBills', function(source, cb, target)
	local xPlayer = ESX.Player(source)
	local xTarget = ESX.Player(target)

	if not xPlayer or not xTarget or xPlayer.getJob().name ~= 'police' or not isNearPlayer(source, xTarget.src) then
		return cb({})
	end

	local result = MySQL.query.await('SELECT amount, id, label FROM billing WHERE identifier = ?', { xTarget.getIdentifier() })
	cb(result)
end)

xLib.callback.registerCompat('esx_billing:payBill', function(source, cb, billId)
	local xPlayer = ESX.Player(source)
	billId = tonumber(billId)

	if not xPlayer or not billId then return cb(false) end

	billId = math.floor(billId)
	if billId < 1 or BillingLocks[billId] then return cb(false) end

	BillingLocks[billId] = source

	local result = MySQL.single.await(
		'SELECT sender, target_type, target, amount FROM billing WHERE id = ? AND identifier = ?',
		{ billId, xPlayer.getIdentifier() }
	)

	if not result or tonumber(result.amount) == nil or tonumber(result.amount) <= 0 then
		BillingLocks[billId] = nil
		return cb(false)
	end

	local amount = math.floor(tonumber(result.amount))
	local paymentAccount = 'money'
	local bankAccount = xPlayer.getAccount('bank')

	if xPlayer.getMoney() < amount then
		paymentAccount = 'bank'
		if not bankAccount or bankAccount.money < amount then
			xPlayer.showNotification(TranslateCap('no_money'))
			BillingLocks[billId] = nil
			return cb(false)
		end
	end

	local function finishPayment(receiver)
		local rowsChanged = MySQL.update.await('DELETE FROM billing WHERE id = ? AND identifier = ?', { billId, xPlayer.getIdentifier() })
		if rowsChanged ~= 1 then
			BillingLocks[billId] = nil
			return cb(false)
		end

		xPlayer.removeAccountMoney(paymentAccount, amount, "Bill Paid")
		receiver()

		TriggerEvent("esx_billing:paidBill", source, billId)

		local groupedDigits = ESX.Math.GroupDigits(amount)
		xPlayer.showNotification(TranslateCap('paid_invoice', groupedDigits))

		BillingLocks[billId] = nil
		cb(true)
	end

	if result.target_type == 'player' then
		local xTarget = ESX.Player(result.sender)
		if not xTarget then
			xPlayer.showNotification(TranslateCap('player_not_online'))
			BillingLocks[billId] = nil
			return cb(false)
		end

		return finishPayment(function()
			xTarget.addAccountMoney(paymentAccount, amount, "Paid bill")
			xTarget.showNotification(TranslateCap('received_payment', ESX.Math.GroupDigits(amount)))
		end)
	end

	TriggerEvent('esx_addonaccount:getSharedAccount', result.target, function(account)
		if not account then
			BillingLocks[billId] = nil
			return cb(false)
		end

		finishPayment(function()
			account.addMoney(amount)

			local xTarget = ESX.Player(result.sender)
			if xTarget then
				xTarget.showNotification(TranslateCap('received_payment', ESX.Math.GroupDigits(amount)))
			end
		end)
	end)
end)
