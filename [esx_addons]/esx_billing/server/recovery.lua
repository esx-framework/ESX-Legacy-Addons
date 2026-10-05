-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

BillingRecovery = {}

local pending = {}
local held = {}
local ready = false
local RETRY_INTERVAL = 5000

function BillingRecovery.hold(identifier, cleanup)
    assert(not held[identifier], 'Payment operation already held')
    held[identifier] = cleanup
end

function BillingRecovery.unhold(identifier)
    held[identifier] = nil
end

function BillingRecovery.isHeld(identifier)
    return held[identifier] ~= nil
end

local function release(context)
    local ok, err = pcall(context.release)

    if not ok then
        print(('[esx_billing] Recovery cleanup failed: %s'):format(tostring(err)))
    end
end

function BillingRecovery.track(operationId, context)
    assert(not pending[operationId], 'Payment recovery context already exists')

    context.busy = false

    context.nextAttempt = GetGameTimer()
    pending[operationId] = context
end

function BillingRecovery.retry(operationId)
    local context = pending[operationId]

    if not context or context.busy then
        return false
    end

    context.busy = true

    local ok, saved = pcall(context.persist)

    context.busy = false

    if pending[operationId] ~= context then
        return false
    end

    if ok and saved == true then
        pending[operationId] = nil
        release(context)

        local notified, err = pcall(context.confirm)

        if not notified then
            print(('[esx_billing] Payment notification failed: %s'):format(tostring(err)))
        end

        return true
    end

    context.nextAttempt = GetGameTimer() + RETRY_INTERVAL

    print(
        ('[esx_billing] Payment %s awaiting persistence; retry scheduled: %s'):format(
            operationId,
            ok and 'save not confirmed' or tostring(saved)
        )
    )

    return false
end

function BillingRecovery.start()
    local receipts = MySQL.query.await(
        "SELECT bill_id, operation_id FROM billing_payments WHERE state = 'claimed' ORDER BY created_at, bill_id LIMIT 20"
    )

    assert(receipts, 'Unable to inspect pending payment receipts')

    ready = true

    if #receipts > 0 then
        print(
            '[esx_billing] Unresolved receipts found. Use billingpayments list/show and the reconciliation guide.'
        )
    end
end

CreateThread(function()
    while true do
        Wait(RETRY_INTERVAL)

        local now = GetGameTimer()

        for operationId, context in pairs(pending) do
            if not context.busy and now >= context.nextAttempt then
                context.nextAttempt = now + RETRY_INTERVAL

                local paymentId = operationId

                CreateThread(function()
                    BillingRecovery.retry(paymentId)
                end)
            end
        end
    end
end)

RegisterCommand('billingpayments', function(source, args)
    if source ~= 0 then
        return
    end

    if not ready then
        print('[esx_billing] Payment journal is unavailable.')
        return
    end

    local action = args[1] or 'list'
    local operationId = args[2]

    if
        action ~= 'list'
        and (type(operationId) ~= 'string' or #operationId > 64 or not operationId:match('^[%x]+$'))
    then
        print(
            '[esx_billing] Usage: billingpayments list | show <operation_id> | retry <operation_id>'
        )
        return
    end

    local ok, err = pcall(function()
        if action == 'retry' then
            local recovered = BillingRecovery.retry(operationId)

            print(
                ('[esx_billing] Retry %s: %s'):format(
                    operationId,
                    recovered and 'confirmed'
                        or 'pending, busy or no live context; inspect the receipt'
                )
            )
        elseif action == 'show' then
            local receipt = MySQL.single.await(
                'SELECT * FROM billing_payments WHERE operation_id = ?',
                { operationId }
            )

            print(json.encode(receipt or {}))
        elseif action == 'list' then
            local receipts = MySQL.query.await(
                "SELECT bill_id, operation_id, identifier, sender, target_type, target, amount, payment_account, created_at FROM billing_payments WHERE state = 'claimed' ORDER BY created_at, bill_id LIMIT 20"
            )

            print(json.encode(assert(receipts, 'Unable to list payment receipts')))
        else
            print(
                '[esx_billing] Usage: billingpayments list | show <operation_id> | retry <operation_id>'
            )
        end
    end)

    if not ok then
        print(('[esx_billing] Journal inspection failed: %s'):format(tostring(err)))
    end
end, true)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    for operationId, context in pairs(pending) do
        release(context)
        pending[operationId] = nil

        print(
            ('[esx_billing] Payment %s interrupted; inspect its durable receipt after restart.'):format(
                operationId
            )
        )
    end

    for identifier, cleanup in pairs(held) do
        local ok, err = pcall(cleanup)

        held[identifier] = nil

        if not ok then
            print(('[esx_billing] Interrupted operation cleanup failed: %s'):format(tostring(err)))
        end
    end
end)
