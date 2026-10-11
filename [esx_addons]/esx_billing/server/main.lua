-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

ESXCatalog.awaitReady()

local billingLimiter = xLib.rateLimiter({
    capacity = 1,
    refill = 1,
    interval = math.max(1, tonumber(Config.BillingCooldown) or 3000),
    staleMs = 60000,
})
local BillingDailyTotals = {}
local BillingLocks = {}
local PayerLocks = {}
local readLimiter = xLib.rateLimiter({
    capacity = 2,
    refill = 1,
    interval = Config.BillsReadCooldown or 1000,
})
local paymentLimiter = xLib.rateLimiter({
    capacity = 2,
    refill = 1,
    interval = Config.BillPaymentCooldown or 500,
})
local PendingBillConfirmations = {}
local paymentJournalReady = false

MySQL.ready(function()
    local ok, err = pcall(function()
        MigrateBillingSchema()
        BillingRecovery.start()
    end)
    paymentJournalReady = ok

    if not paymentJournalReady then
        print(
            ('[esx_billing] Schema migration failed; payments disabled: %s'):format(tostring(err))
        )
    else
        print('[esx_billing] Database schema ready.')
    end
end)

local function normalizeAmount(amount, maxAmount)
    amount = tonumber(amount)

    if not amount or amount ~= amount or amount == math.huge or amount == -math.huge then
        return nil
    end

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
    if type(sharedAccountName) ~= 'string' then
        return nil
    end

    return sharedAccountName:match('^society_([%w_]+)$')
end

local function isNearPlayer(source, target, distance)
    local nearby =
        xLib.player.isNearPlayer(source, target, distance or Config.BillingDistance or 10.0)
    return nearby
end

local function canIssueSocietyBill(xPlayer, sharedAccountName)
    local jobName = getSocietyJob(sharedAccountName)
    if not jobName then
        return false
    end

    local job = xPlayer.getJob()
    if not job or job.name ~= jobName then
        return false
    end

    local minimumGrades = Config.BillingMinimumGrades or {}
    local minimumGrade = tonumber(minimumGrades[jobName])
        or tonumber(Config.MinimumBillingGrade)
        or 1
    local playerGrade = tonumber(job.grade) or 0

    return playerGrade >= minimumGrade
end

local function hasDailyQuota(senderIdentifier, amount)
    local maxDailyAmount = tonumber(Config.MaxDailyBillAmount) or 250000
    if maxDailyAmount <= 0 then
        return true
    end

    local key = ('%s:%s'):format(senderIdentifier, os.date('%Y-%m-%d'))
    local currentTotal = BillingDailyTotals[key] or 0

    return currentTotal + amount <= maxDailyAmount
end

local function addDailyAmount(senderIdentifier, amount)
    local maxDailyAmount = tonumber(Config.MaxDailyBillAmount) or 250000
    if maxDailyAmount <= 0 then
        return
    end

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

local function billPlayerByIdentifier(
    targetIdentifier,
    senderIdentifier,
    sharedAccountName,
    label,
    amount
)
    amount = normalizeAmount(amount)
    if not amount or type(targetIdentifier) ~= 'string' or type(senderIdentifier) ~= 'string' then
        return false
    end

    label = sanitizeLabel(label)

    if getSocietyJob(sharedAccountName) then
        local accountPromise = promise.new()
        TriggerEvent('esx_addonaccount:getSharedAccount', sharedAccountName, function(account)
            accountPromise:resolve(account)
        end)

        local account = Citizen.Await(accountPromise)
        if not account then
            print(
                ('[^2ERROR^7] Attempted to send bill from invalid society - ^5%s^7'):format(
                    sharedAccountName
                )
            )
            return false
        end

        local insertedId = insertBill(
            targetIdentifier,
            senderIdentifier,
            'society',
            sharedAccountName,
            label,
            amount
        )
        if insertedId then
            addDailyAmount(senderIdentifier, amount)
        end

        return insertedId or false
    end

    local insertedId =
        insertBill(targetIdentifier, senderIdentifier, 'player', senderIdentifier, label, amount)
    if insertedId then
        addDailyAmount(senderIdentifier, amount)
    end

    return insertedId or false
end

local function billPlayer(targetId, senderIdentifier, sharedAccountName, label, amount)
    local xTarget = ESX.Player(tonumber(targetId))

    if not xTarget then
        return false
    end

    return billPlayerByIdentifier(
        xTarget.getIdentifier(),
        senderIdentifier,
        sharedAccountName,
        label,
        amount
    )
end

RegisterNetEvent('esx_billing:sendBill', function(targetId, sharedAccountName, label, amount)
    local src = source
    local xPlayer = ESX.Player(src)
    local xTarget = ESX.Player(tonumber(targetId))

    amount = normalizeAmount(amount)
    label = sanitizeLabel(label)

    if not xPlayer or not xTarget or not amount or xTarget.src == src then
        return
    end
    if not canIssueSocietyBill(xPlayer, sharedAccountName) then
        return print(
            ('[^2ERROR^7] Player ^5%s^7 attempted to send an unauthorized bill from ^5%s^7'):format(
                src,
                tostring(sharedAccountName)
            )
        )
    end

    local now = GetGameTimer()
    if not billingLimiter:consume(src) then
        return
    end

    if not isNearPlayer(src, xTarget.src) then
        return
    end
    if not hasDailyQuota(xPlayer.getIdentifier(), amount) then
        return
    end

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
            amount = amount,
        }

        TriggerClientEvent(
            'esx_billing:confirmHighBill',
            xTarget.src,
            token,
            label,
            amount,
            xPlayer.getName()
        )
        return
    end

    billPlayerByIdentifier(
        xTarget.getIdentifier(),
        xPlayer.getIdentifier(),
        sharedAccountName,
        label,
        amount
    )
end)
exports('BillPlayer', billPlayer)

AddEventHandler(
    'esx_billing:sendBillToIdentifier',
    function(targetIdentifier, sharedAccountName, label, amount)
        if not GetInvokingResource() then
            return
        end

        billPlayerByIdentifier(targetIdentifier, 'server', sharedAccountName, label, amount)
    end
)
exports('BillPlayerByIdentifier', billPlayerByIdentifier)

xLib.callback.registerCompat('esx_billing:respondHighBill', function(source, cb, token, accepted)
    local pendingBill = PendingBillConfirmations[token]

    if
        not pendingBill
        or pendingBill.targetSource ~= source
        or pendingBill.expires < GetGameTimer()
    then
        PendingBillConfirmations[token] = nil
        return cb(false)
    end

    PendingBillConfirmations[token] = nil
    if accepted ~= true then
        return cb(false)
    end
    if not isNearPlayer(pendingBill.senderSource, source) then
        return cb(false)
    end
    if not hasDailyQuota(pendingBill.senderIdentifier, pendingBill.amount) then
        return cb(false)
    end

    local insertedId = billPlayerByIdentifier(
        pendingBill.targetIdentifier,
        pendingBill.senderIdentifier,
        pendingBill.sharedAccountName,
        pendingBill.label,
        pendingBill.amount
    )

    cb(insertedId ~= false)
end)

xLib.callback.registerCompat('esx_billing:getBills', function(source, cb, afterId)
    local xPlayer = ESX.Player(source)

    if not xPlayer or not readLimiter:consume(source) then
        return cb({})
    end

    afterId = tonumber(afterId) or 0

    if afterId ~= afterId or afterId < 0 or afterId > 2147483647 or afterId % 1 ~= 0 then
        return cb({})
    end

    local pageSize = math.max(1, math.min(100, tonumber(Config.BillsPageSize) or 50))

    local result = MySQL.query.await(
        'SELECT amount, id, label FROM billing WHERE identifier = ? AND id > ? ORDER BY id LIMIT ?',
        { xPlayer.getIdentifier(), afterId, pageSize + 1 }
    ) or {}
    local hasNext = #result > pageSize

    if hasNext then
        result[#result] = nil
    end

    cb(result, hasNext)
end)

xLib.callback.registerCompat('esx_billing:getTargetBills', function(source, cb, target, afterId)
    local xPlayer = ESX.Player(source)
    local xTarget = ESX.Player(target)

    if
        not xPlayer
        or not xTarget
        or not readLimiter:consume(source)
        or xPlayer.getJob().name ~= 'police'
        or not isNearPlayer(source, xTarget.src)
    then
        return cb({})
    end

    afterId = tonumber(afterId) or 0

    if afterId ~= afterId or afterId < 0 or afterId > 2147483647 or afterId % 1 ~= 0 then
        return cb({})
    end

    local pageSize = math.max(1, math.min(100, tonumber(Config.BillsPageSize) or 50))

    local result = MySQL.query.await(
        'SELECT amount, id, label FROM billing WHERE identifier = ? AND id > ? ORDER BY id LIMIT ?',
        { xTarget.getIdentifier(), afterId, pageSize + 1 }
    ) or {}
    local hasNext = #result > pageSize

    if hasNext then
        result[#result] = nil
    end

    cb(result, hasNext)
end)

xLib.callback.registerCompat('esx_billing:payBill', function(source, cb, billId)
    local xPlayer = ESX.GetPlayerFromId(source)
    billId = tonumber(billId)

    if
        not paymentJournalReady
        or not xPlayer
        or not xPlayer.spawned
        or not billId
        or billId ~= billId
        or billId < 1
        or billId > 2147483647
        or billId % 1 ~= 0
        or not paymentLimiter:consume(source)
    then
        return cb(false)
    end

    local identifier = xPlayer.getIdentifier()

    if BillingLocks[billId] or PayerLocks[identifier] then
        return cb(false)
    end

    BillingLocks[billId] = true
    PayerLocks[identifier] = true

    if xPlayer.beginAccountOperation() ~= true then
        BillingLocks[billId] = nil
        PayerLocks[identifier] = nil
        return cb(false)
    end

    local reserved
    local claimed
    local receiverPlayer
    local receiverHeld = false
    local account
    local amount
    local paymentAccount
    local operationId
    local recoveryTracked = false
    local released = false

    local function releaseOperation()
        if released then
            return
        end

        released = true
        BillingRecovery.unhold(identifier)

        if receiverHeld then
            receiverPlayer.endAccountOperation()
        end

        xPlayer.endAccountOperation()
        BillingLocks[billId] = nil
        PayerLocks[identifier] = nil
    end

    BillingRecovery.hold(identifier, releaseOperation)

    local ok, paid = pcall(function()
        local result = MySQL.single.await(
            'SELECT sender, target_type, target, amount FROM billing WHERE id = ? AND identifier = ?',
            { billId, identifier }
        )

        if
            not result
            or ESX.GetPlayerFromId(source) ~= xPlayer
            or not BillingRecovery.isHeld(identifier)
        then
            return false
        end

        amount = normalizeAmount(result.amount)

        if not amount then
            return false
        end

        paymentAccount = xPlayer.getMoney() >= amount and 'money' or 'bank'

        if result.target_type == 'player' then
            receiverPlayer = ESX.GetPlayerFromIdentifier(result.sender)

            if not receiverPlayer or not receiverPlayer.spawned then
                return false
            end

            if receiverPlayer.beginAccountOperation() ~= true then
                return false
            end

            receiverHeld = true
        elseif result.target_type == 'society' then
            TriggerEvent('esx_addonaccount:getSharedAccount', result.target, function(found)
                account = found
            end)

            if not account then
                return false
            end
        else
            return false
        end

        if xPlayer.removeAccountMoney(paymentAccount, amount, 'Bill reservation') ~= true then
            return false
        end

        reserved = true
        operationId = xLib.string.randomHex(32)

        local committed = MySQL.transaction.await({
            {
                query = [[INSERT INTO billing_payments (bill_id, operation_id, identifier, sender, target_type, target, label, amount, payment_account, state)
                SELECT id, ?, identifier, sender, target_type, target, label, amount, ?, 'claimed' FROM billing
                WHERE id = ? AND identifier = ? AND amount = ? AND sender = ? AND target_type = ? AND target <=> ?]],
                values = {
                    operationId,
                    paymentAccount,
                    billId,
                    identifier,
                    result.amount,
                    result.sender,
                    result.target_type,
                    result.target,
                },
            },
            {
                query = [[DELETE FROM billing WHERE id = ? AND identifier = ? AND EXISTS
                (SELECT 1 FROM billing_payments WHERE bill_id = ? AND operation_id = ?)]],
                values = {
                    billId,
                    identifier,
                    billId,
                    operationId,
                },
            },
        })

        if not committed then
            return false
        end

        local receipt = MySQL.single.await(
            'SELECT operation_id FROM billing_payments WHERE bill_id = ? AND operation_id = ?',
            { billId, operationId }
        )

        if not receipt then
            return false
        end

        claimed = true

        if not BillingRecovery.isHeld(identifier) then
            error('Payment interrupted after claim; inspect its durable receipt')
        end

        local credited = receiverPlayer
                and receiverPlayer.addAccountMoney(paymentAccount, amount, 'Paid bill')
            or (not receiverPlayer and account.addMoney(amount))

        if credited ~= true then
            local reverted = MySQL.transaction.await({
                {
                    query = [[INSERT INTO billing (id, identifier, sender, target_type, target, label, amount)
                    SELECT bill_id, identifier, sender, target_type, target, label, amount FROM billing_payments
                    WHERE bill_id = ? AND operation_id = ? AND state = 'claimed']],
                    values = { billId, operationId },
                },
                {
                    query = "DELETE FROM billing_payments WHERE bill_id = ? AND operation_id = ? AND state = 'claimed'",
                    values = { billId, operationId },
                },
            })

            if reverted then
                claimed = false
            else
                error('Credit rejected and compensation failed; claimed receipt retained')
            end

            return false
        end

        reserved = false

        local function savePlayer(player)
            if ESX.GetPlayerFromId(player.source) ~= player then
                return false
            end

            local saved = promise.new()

            exports.es_extended:SavePlayer(player.source, function(success)
                saved:resolve(success)
            end)

            return Citizen.Await(saved)
        end

        BillingRecovery.track(operationId, {
            release = releaseOperation,
            persist = function()
                local receipt = MySQL.single.await(
                    'SELECT state FROM billing_payments WHERE bill_id = ? AND operation_id = ?',
                    { billId, operationId }
                )

                assert(receipt, 'Payment receipt is missing; manual reconciliation required')

                if receipt.state == 'applied' then
                    return true
                end

                assert(receipt.state == 'claimed', 'Unexpected payment receipt state')

                local saved = savePlayer(xPlayer)

                if receiverPlayer then
                    saved = savePlayer(receiverPlayer) and saved
                end

                if account then
                    local persisted = promise.new()

                    account.save(function(success)
                        persisted:resolve(success)
                    end)

                    saved = Citizen.Await(persisted) and saved
                end

                if not saved then
                    return false
                end

                local marked = MySQL.update.await(
                    "UPDATE billing_payments SET state = 'applied', applied_at = CURRENT_TIMESTAMP WHERE bill_id = ? AND operation_id = ? AND state = 'claimed'",
                    { billId, operationId }
                )

                if marked == 1 then
                    return true
                end

                receipt = MySQL.single.await(
                    'SELECT state FROM billing_payments WHERE bill_id = ? AND operation_id = ?',
                    { billId, operationId }
                )

                return receipt and receipt.state == 'applied' or false
            end,
            confirm = function()
                TriggerEvent('esx_billing:paidBill', source, billId)

                if ESX.GetPlayerFromId(source) == xPlayer then
                    xPlayer.showNotification(
                        TranslateCap('paid_invoice', ESX.Math.GroupDigits(amount))
                    )
                end
            end,
        })

        recoveryTracked = true

        return BillingRecovery.retry(operationId)
    end)

    if not ok and operationId and not claimed then
        local checked, receipt = pcall(
            MySQL.single.await,
            'SELECT operation_id FROM billing_payments WHERE bill_id = ? AND operation_id = ?',
            { billId, operationId }
        )
        claimed = not checked or receipt ~= nil
    end

    if
        reserved
        and not claimed
        and xPlayer.addAccountMoney(paymentAccount, amount, 'Bill reservation refund') ~= true
    then
        print(
            ('[esx_billing] CRITICAL: rejected refund for payment %s/%s'):format(
                billId,
                tostring(operationId)
            )
        )
    end

    if not ok then
        print(
            ('[esx_billing] Payment %s/%s requires attention: %s'):format(
                billId,
                tostring(operationId),
                tostring(paid)
            )
        )
    end

    if not recoveryTracked then
        releaseOperation()
    end

    cb(ok and paid == true)
end)
